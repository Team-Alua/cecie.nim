import bitops
import strutils
import "orbis/savedata"
import "orbis/errors" 
import "orbis/userservice"
import "orbis/procinfo"
import "orbis/path"
import "libjbc"

import os
import asyncnet
import asyncdispatch

proc inf = 
  while true:
    discard
echo "Hi"
if ORBIS_OK != userservice.init():
  echo "Failed to initialize user service"
  inf()

if ORBIS_OK != savedata.init():
  echo "Failed to initialize sceSaveData"
  inf()

proc doMount(client: AsyncSocket) {.async.} = 
  var userId: int32
  if ORBIS_OK != getUserId(userId):
    await client.send("\nFailed to get initial user")
    return
  await client.send("\nMounting...")
  await client.send("\nUserId: " & $userId)

  var saveData: SaveData  
  saveData.userId = userId
  saveData.titleId = APP_TITLE_ID
  saveData.dirName = "2"
  const fingerprint = repeat('0', 64)
  saveData.fingerprint = fingerprint
  saveData.blocks = 114
  saveData.mountMode(SaveDataMountMode.DESTRUCT_OFF,
                     SaveDataMountMode.CREATE2,
                     SaveDataMountMode.RDWR) 

  await client.send("\n" & $saveData)
  var mounter : SaveDataMounter

  mounter.data = saveData
  let mr: SaveDataMounterResult = mounter.mount()

  if ORBIS_OK != mr.code:
    await client.send("\nsceSaveDataMount() = " & mr.code.toHex(8))
    return
  else:
    await client.send("\nMounted successfully")
  
  await client.send("\nMount path:" & mr.mountPath)

  sudo:
    for path in walkDirRec(fromSandboxToAbsPath(mr.mountPath)):
      echo path

  
  var umr = mounter.unmount()
  
  if ORBIS_OK != umr:
    await client.send("\nFailed to unmount" & umr.toHex(8))
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
