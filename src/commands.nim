import asyncnet
import asyncdispatch
import posix
import os
import "./requests"
import "./syscalls"
import "./savedata"
import libjbc



proc dumpSave(cmd: ClientRequest, mountId: string) {.async.} =
  var s: Stat
  if stat(cmd.targetFolder.cstring, s) != 0 or not s.st_mode.S_ISDIR:
    exitnow(-99)
  let saveDirectory = "/data"
  let mntFolder = "/data/" & mountId
  # Run as root
  var cred = get_cred()
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
      for kind, file in walkDir(currFolder,relative=true, skipSpecial=true):
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

template respondWith(client: AsyncSocket, code: int) =
  await client.send("{\"status\": " & $code & "}")

type RequestHandler = proc (cmd: ClientRequest, mountId: string) {.async.}
var cmds : array[ClientRequestType, RequestHandler]
cmds[rtDumpSave] = dumpSave

var slot: int
proc handleForkCmds(client: AsyncSocket, cmd: ClientRequest) {.async.} =
  inc slot
  if slot >= 16:
    dec slot
    respondWith(client, -1099)
    return
  let pid = sys_fork()
  if pid == -1:
    respondWith(client, errno)
    return
  elif pid > 0:
    var status: cint
    var cPid = Pid(pid)
    while true: 
      let wPid = waitpid(cPid, status, WNOHANG)
      if cPid == wPid:
        break
      await sleepAsync(250)
    dec slot
    respondWith(client, status)
    return
  var handler = cmds[cmd.RequestType]
  if not handler.isNil:
    await handler(cmd, "mnt" & $slot)
  else:
    respondWith(client, -1097)
  exitnow(0)

proc handleCmd*(client: AsyncSocket, cmd: ClientRequest) {.async.} =
  if cmd.RequestType == rtKeySet:
    await client.send("{\"keyset\":" & $getMaxKeySet() & "}")
  elif cmd.RequestType == rtInvalid:
    respondWith(client, -1098)
  else:
    await handleForkCmds(client, cmd)

