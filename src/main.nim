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

addHandler(newKernelLogger())

var old_cred = get_cred()
old_cred.sonyCred = old_cred.sonyCred or uint64(0x40_00_00_00_00_00_00_00)
var cred = get_cred()
## Allow process to make sockets async
cred.sonyCred = cred.sonyCred or uint64(0x40_00_00_00_00_00_00_00)
cred.sceProcType = uint64(0x3801000000000013)
discard set_cred(cred)

type ClientRequestType = enum
  rtKeySet,
  rtCreateSave,
  rtDumpSave,
  rtUpdateSave,
  rtInvalid


type ClientRequest = object
  case RequestType: ClientRequestType
  of rtKeySet:
    discard
  of rtCreateSave, rtUpdateSave:
    sourceFolder: string
    targetSaveName: string
  of rtDumpSave:
    sourceSaveName: string
    targetFolder: string
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

discard sudo_mount("/dev/", "rootdev")
var s : Stat
discard stat("/rootdev/pfsctldev", s)
discard sys_mknod("/dev/pfsctldev", Mode(S_IFCHR or 0o777), s.st_dev)
discard stat("/rootdev/lvdctl", s)
discard sys_mknod("/dev/lvdctl", Mode(S_IFCHR or 0o777), s.st_dev)
discard sudo_unmount("rootdev")
#echo "Sample save creation returns ", createSave("/data", "1", 96)
#discard mkdir("/data/test2", 0o777)
#var handle = mountSave("/data", "data0002", "/data/test2")
#if handle >= 0:
#  echo "Unmount ", umountSave("/data/test2", handle, false)
discard set_cred(old_cred)

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

var mountedCnt: uint
var mountTotal: uint64 = 0
#template forkCmdTemplate() {.dirty.} =
#  # Can only mount 16 at a time according to docs
#  if mountedCnt >= 16:
#    await client.send("{\"result\": -100}")
#    return
#  inc mountedCnt
#  inc mountTotal
#  let mountId = "mnt" & $mountTotal
#  let pid = sys_fork()
#  if pid == -1:
#    echo "Failed to fork: ", errno
#    return
#  elif pid > 0:
#    var status: cint
#    while true: 
#      let cPid = Pid(pid)
#      let wPid = waitpid(cPid, status, WNOHANG)
#      if cPid == wPid:
#        break
#      await sleepAsync(250)
#    await client.send("{\"result\": " & $status  & "}")
#    dec mountedCnt
#    return

proc dumpSave(client: AsyncSocket, cmd: ClientRequest) {.async.} =
  # Check if directory is accessible
  var s: Stat
  if stat(cmd.targetFolder.cstring, s) != 0 or not s.st_mode.S_ISDIR:
    await client.send("{\"result\": -99}")
    return

  # Can only mount 16 at a time according to docs
  if mountedCnt >= 16:
    await client.send("{\"result\": -100}")
    return
  inc mountedCnt
  inc mountTotal
  let mountId = "mnt" & $mountTotal
  let pid = sys_fork()
  if pid == -1:
    echo "Failed to fork: ", errno
    return
  elif pid > 0:
    var status: cint
    while true: 
      let cPid = Pid(pid)
      let wPid = waitpid(cPid, status, WNOHANG)
      if cPid == wPid:
        break
      await sleepAsync(250)
    await client.send("{\"result\": " & $status  & "}")
    dec mountedCnt
    return
  let saveDirectory = "/data"
  let mntFolder = "/data/" & mountId
  # Run as root
  var cred = get_cred()
  ## Allow process to make sockets async
  cred.sonyCred = cred.sonyCred or uint64(0x40_00_00_00_00_00_00_00)
  cred.sceProcType = uint64(0x3801000000000013)
  discard set_cred(cred)
  discard setuid(0)

  discard unlink(mntFolder.cstring)
  discard mkdir(mntFolder.cstring, 0o777)
  # Then dump everything
  let handle = mountSave(saveDirectory, cmd.sourceSaveName, mntFolder)
  if handle >= 0:
    var folders = @[""]
    while folders.len > 0:
      let relativeFolder = folders.pop()
      let currFolder = mntFolder / relativeFolder
      for kind, file in walkDir(currFolder,relative=true):
        if kind == pcDir:
          let targetPath = joinPath(cmd.targetFolder, file)
          folders.add file
          discard mkdir(targetPath.cstring, 0o777)
        elif kind == pcFile:
          let targetFile = joinPath(cmd.targetFolder, relativeFolder / file)
          # Create it just in case
          let fd = open(targetFile.cstring, O_RDONLY, 0o777)
          discard close(fd)
          let sourceFile = joinPath(currFolder, file)
          copyFile(sourceFile, targetFile)
    discard umountSave(mntFolder, handle, false)
  discard unlink(mntFolder.cstring)
  exitnow(0)
proc handleClient(clientContext : tuple[address: string, client: AsyncSocket]) {.async.} = 
  # Wait for message
  # let address = clientContext.address
  let client = clientContext.client
  var data = await client.recvLine()
  defer: client.close()
  if data.len == 0:
    return
  let req = parseRequest(data)
  if req.RequestType == rtKeySet:
    await client.send("{\"keyset\": " & $getMaxKeySet() & "}")
  elif req.RequestType == rtDumpSave:
    await client.send("I will be dumping save")
    await dumpSave(client, req)
    echo "Dump completed"
  elif req.RequestType == rtCreateSave:
    await client.send("I will be creating save")
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

