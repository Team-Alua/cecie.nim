import bitops
import strutils
import "orbis/SaveData"
import "orbis/_types/save_data"
import "orbis/UserService"
import "orbis/_types/user"
import "orbis/_types/errors"
import os
import asyncnet
import asyncdispatch



proc inf = 
  while true:
    discard
echo "Hi!"
var initParams : OrbisUserServiceInitializeParams
initParams.priority = 700
if ORBIS_OK != sceUserServiceInitialize(addr(initParams)):
  echo "Failed to initialize user service"
  inf()

proc doMount(client: AsyncSocket) {.async.} = 

  if ORBIS_OK != sceSaveDataInitialize3(0):
    await client.send("\nFailed to initialize sceSaveData")
    return  
  var userId: int32
  
  if ORBIS_OK != sceUserServiceGetInitialUser(addr(userId)):
    await client.send("\nFailed to get initial user")
    return
 
  await client.send("\nMounting...")
  await client.send("\nUserId: " & $userId)
  var mount : OrbisSaveDataMount
  mount.userId = userId
  
  mount.dirName = alignLeft("2", 32, '\x00').cstring
  mount.titleId = alignLeft("DEVP00001", 16, '\x00').cstring

  const fingerprint = repeat('0', 64) & repeat('\x00', 80 - 64)
  mount.fingerprint = fingerprint.cstring
  mount.blocks = 114.uint64
  mount.mountMode = bitor(ORBIS_SAVE_DATA_MOUNT_MODE_DESTRUCT_OFF,
                       ORBIS_SAVE_DATA_MOUNT_MODE_CREATE2,
                       ORBIS_SAVE_DATA_MOUNT_MODE_RDWR)
  
  var mountResult: OrbisSaveDataMountResult
  var errCode = sceSaveDataMount(addr(mount), addr(mountResult))
  
  if ORBIS_OK != errCode:
    await client.send("\nsceSaveDataMount() = " & errCode.toHex(8))
    return
  else:
    await client.send("\nMounted successfully")
  
  var mp : OrbisSaveDataMountPoint
  await client.send("\nMount path:")
  var pathName: string

  for i in mountResult.mountPathName:
    if i == '\x00':
      break
    pathName.add(i)
  pathName = joinPath(pathName, "")
  for path in walkDirRec(pathName, checkDir=true, skipSpecial=true):
    await client.send("\n" & path)

  mp.data = mountResult.mountPathName
  
  let result2 = sceSaveDataUmount(addr(mp))
  
  if ORBIS_OK != result2:
    await client.send("\nFailed to unmount" & result2.toHex(8))
  else:
    await client.send("\nunmount success")

proc main {.async.} =

  var server = newAsyncSocket()
  server.bindAddr(Port(1234))
  server.listen()

  while true:
    let client = await server.accept()

    await client.send("Doing mount")
    await doMount(client) 
    client.close()

asyncCheck main()
runForever()
