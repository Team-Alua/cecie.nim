import asyncdispatch 
import os
import strutils
import asyncnet
import json
import logging
import "logger"
import "orbis/savedata_advanced"
import "syscalls"
import "./savedata"
import "./utils"
import libjbc
{.passl: "-lc -lkernel".}
import posix

addHandler(newKernelLogger())

var cred = get_cred()
## Allow process to make sockets async
cred.sonyCred = cred.sonyCred or uint64(0x40_00_00_00_00_00_00_00)
cred.sceProcType = uint64(0x3801000000000013)
discard set_cred(cred)

type ClientRequestType = enum
  rtKeySet,
  rtDumpSave,
  rtCreateSave,
  rtInvalid


type ClientRequest = object
  case RequestType: ClientRequestType
  of rtKeySet:
    discard
  of rtDumpSave, rtCreateSave:
    ftpPort: string
    rootFolder: string
  of rtInvalid:
    discard
  
proc parseRequest(data: string): ClientRequest = 
  try:
    let jsonData = parseJson(data)
    result = to(jsonData, ClientRequest)
  except JsonParsingError, KeyError:
    result = ClientRequest(RequestType: rtInvalid)

var maxKeyset : cshort = 0

if not loadPrivLibs():
  log(lvlError, "Failed to load private lib")
  InfiniteLoop()
else:
  log(lvlInfo, "Loaded private lib!")

import posix
# echo sudo_unmount("dev")

discard setuid(0)


echo "mount: ", sudo_mount("/dev/", "rootdev")
var s : Stat
discard stat("/rootdev/pfsctldev", s)
discard sys_mknod("/dev/pfsctldev", Mode(S_IFCHR or 0o777), s.st_dev)
discard stat("/rootdev/lvdctl", s)
discard sys_mknod("/dev/lvdctl", Mode(S_IFCHR or 0o777), s.st_dev)
echo "mount: ", sudo_unmount("rootdev")
# echo "Sample save creation returns ", createSave("/data", "1", 96)
discard mkdir("/data/test2", 0o777)
var handle = mountSave("/data", "data0002", "/data/test2")
echo "Mounting ", handle
if handle >= 0:
  sleep(10000)
  echo "Unmount ", umountSave("/data/test2", handle, false)

proc getMaxKeySet(): cshort = 
  if maxKeyset > 0:
    return maxKeyset
  var sampleSealedKey : array[96, byte]
  var response : cint
  response = generateSealedKey(sampleSealedKey)
  if response != 0:
    return 0
  maxKeyset = cshort(sampleSealedKey[9] shl 8 + sampleSealedKey[8])
  return maxKeyset

proc handleClient(clientContext : tuple[address: string, client: AsyncSocket]) {.async.} = 
  # Wait for message
  let address = clientContext.address
  let client = clientContext.client
  var data = await client.recvLine()
  defer: client.close()
  if data.len == 0:
    return
  let req = parseRequest(data)
  if req.RequestType == rtKeySet:
    await client.send("{\"keyset\": " & $getMaxKeySet() & "}")
  elif req.RequestType == rtDumpSave:
    await client.send("I will be dumping save from ftp://" & address & ":" & req.ftpPort & req.rootFolder)
  elif req.RequestType == rtCreateSave:
    await client.send("I will be creating save from ftp://" & address & ":" & req.ftpPort & req.rootFolder)
  elif req.RequestType == rtInvalid:
    await client.send("invalid")
  client.close()
  # After forking
  # we need to do a non blocking waitpid
  # because if all 16 mount points are taken
  # we want to immediately return an error if 
  # a user tries to create or dump a save

proc requestListener() {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(1234))
  server.listen()
  while true:
    let clientContext = await server.acceptAddr()
    asyncCheck handleClient(clientContext)

asyncCheck requestListener()

while true:
  poll(1)

