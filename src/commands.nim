import asyncnet
import asyncdispatch
import posix
import os
import "./requests"
import "./syscalls"
import "./savedata"
import libjbc

template respondWith(client: AsyncSocket, code: int) =
  await client.send("{\"status\": " & $code & "}")


proc dumpSave(cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.} =
  var s: Stat
  if stat(cmd.targetFolder.cstring, s) != 0 or not s.st_mode.S_ISDIR:
    respondWith(client, -99)
    return
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
    let targetFolder = cmd.targetFolder
    var folders = @[""]
    while folders.len > 0:
      let relativeFolder = folders.pop()
      let currFolder = mntFolder / relativeFolder
      let currTargetFolder = targetFolder / relativeFolder
      for kind, file in walkDir(currFolder,relative=true, skipSpecial=true):
        if kind == pcDir:
          let targetPath = joinPath(currTargetFolder, file)
          folders.add relativeFolder / file
          discard mkdir(targetPath.cstring, 0o777)
        elif kind == pcFile:
          let targetFile = joinPath(currTargetFolder, file)
          # Create it just in case
          let fd = open(targetFile.cstring, O_RDONLY, 0o777)
          discard close(fd)
          let sourceFile = joinPath(currFolder, file)
          try:
            copyFile(sourceFile, targetFile)
          except OSError:
            respondWith(client, -96)
            exitnow(-1)
    discard umountSave(mntFolder, handle, false)
  discard unlink(mntFolder.cstring)
  exitnow(0)

proc updateSave(cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.} =
  var s: Stat
  if stat(cmd.sourceFolder.cstring, s) != 0 or not s.st_mode.S_ISDIR:
    respondWith(client, -99)
    return 

  if stat(cmd.targetSaveName.cstring, s) != 0 or s.st_mode.S_ISDIR:
    respondWith(client, -98)
    return 

  if stat((cmd.targetSaveName & ".bin").cstring, s) != 0 or s.st_mode.S_ISDIR:
    respondWith(client, -97)
    return

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
  let handle = mountSave(saveDirectory, cmd.targetSaveName, mntFolder)
  if handle >= 0:
    var folders = @[""]
    var sourceFolder = cmd.sourceFolder
    var targetFolder = mntFolder
    while folders.len > 0:
      let relativeFolder = folders.pop()
      let currFolder = sourceFolder / relativeFolder
      let currTargetFolder = targetFolder / relativeFolder
      if relativeFolder == "sce_sys":
        discard setuid(0)
      else:
        discard setuid(1)
      for kind, file in walkDir(currFolder,relative=true, skipSpecial=true):
        if kind == pcDir:
          let targetPath = joinPath(currTargetFolder, file)
          folders.add relativeFolder / file
          discard mkdir(targetPath.cstring, 0o777)
        elif kind == pcFile:
          let targetFile = joinPath(currTargetFolder, file)
          # Create it just in case
          let fd = open(targetFile.cstring, O_RDONLY, 0o777)
          discard close(fd)
          let sourceFile = joinPath(currFolder, file)
          try:
            copyFile(sourceFile, targetFile)
          except OSError:
            respondWith(client, -96)
            exitnow(-1)
    discard setuid(0)
    discard umountSave(mntFolder, handle, false)
  discard unlink(mntFolder.cstring)
  exitnow(0)

type RequestHandler = proc (cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.}
var cmds : array[ClientRequestType, RequestHandler]
cmds[rtDumpSave] = dumpSave
cmds[rtUpdateSave] = updateSave

var slot: int
var slotTotal: int
proc handleForkCmds(client: AsyncSocket, cmd: ClientRequest) {.async.} =
  inc slot
  # No matter who mounts
  # it will be a unique mount number
  inc slotTotal
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
    if status == 0:
      respondWith(client, status)
    return
  var handler = cmds[cmd.RequestType]
  if not handler.isNil:
    await handler(cmd, client, "mnt" & $slotTotal)
  else:
    respondWith(client, -1097)
  exitnow(-1)
proc handleCmd*(client: AsyncSocket, cmd: ClientRequest) {.async.} =
  if cmd.RequestType == rtKeySet:
    await client.send("{\"keyset\":" & $getMaxKeySet() & "}")
  elif cmd.RequestType == rtInvalid:
    respondWith(client, -1098)
    exitnow(-1)
  else:
    await handleForkCmds(client, cmd)

