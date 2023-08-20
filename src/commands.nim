import strutils
import asyncnet
import asyncdispatch
import posix
import os
import "./requests"
import "./syscalls"
import "./savedata"
import "./config"
import libjbc
import marshal
import json

type ServerResponseType = enum
  srOk,
  srInvalid,
  srKeySet,
  srJson

type ServerResponse = object
  case ResponseType*: ServerResponseType
  of srOk:
    discard
  of srKeySet:
    keyset*: cshort
  of srInvalid:
    code*: string
  of srJson:
    json*: string

type SaveListEntry = object
  kind: PathComponent
  path: string
  mode: Mode


template respondWithOk(client: untyped) = 
  await client.send($$ServerResponse(ResponseType: srOk) & "\r\L")

template respondWithError(client,errorCode: untyped) = 
  await client.send($$ServerResponse(ResponseType: srInvalid, code: errorCode) & "\r\L")

template respondWithKeySet(client,fwKeyset: untyped) =
  await client.send($$ServerResponse(ResponseType: srKeySet, keyset: fwKeyset) & "\r\L")

template respondWithJson(client,jsonNode: untyped) =
  await client.send($$ServerResponse(ResponseType: srJson, json: $jsonNode) & "\r\L")


proc shouldSkipFile(relativePath: string, kind: PathComponent, fileWhitelist: seq[string]): bool =
  var skipFile = false

  if kind == pcFile:
    skipFile = not fileWhitelist.contains(relativePath)
  elif kind == pcDir:
    skipFile = true
    for entry in fileWhitelist:
      if entry.startsWith(relativePath):
        skipFile = false
        break
  else:
    # Always skip non regular files
    # and directories
    skipFile = true
  return skipFile

proc setupCredentials() = 
  # Run as root
  var cred = get_cred()
  cred.sonyCred = cred.sonyCred or uint64(0x40_00_00_00_00_00_00_00)
  cred.sceProcType = uint64(0x3800000000000010)
  discard set_cred(cred)
  discard setuid(0)

proc checkSave(saveDirectory: string, saveName: string) : int = 
  var s: Stat
  let saveImagePath = joinPath(saveDirectory, saveName)
  if stat(saveImagePath.cstring, s) != 0 or s.st_mode.S_ISDIR:
    return -1

  const saveBlocks = 1 shl 15
  if s.st_size mod saveBlocks != 0:
    return -2
  
  const minImageSize = 96 * saveBlocks
  const maxImageSize = (1 shl 15) * saveBlocks
  if s.st_size > maxImageSize or s.st_size < minImageSize:
    return -3

  let saveKeyPath = joinPath(saveDirectory, saveName & ".bin")
  if stat(saveKeyPath.cstring, s) != 0 or s.st_mode.S_ISDIR:
    return -4

  if s.st_size != 96:
    return -5
  return 0

proc reportSaveError(saveStatus: int, client:AsyncSocket) {.async.} =
  if saveStatus == -1:
    respondWithError(client, "E:SAVE_IMAGE_INVALID")
  elif saveStatus == -2 or saveStatus == -3:
    respondWithError(client, "E:SAVE_IMAGE_SIZE_INVALID")
  elif saveStatus == -4:
    respondWithError(client, "E:SAVE_KEY_INVALID")
  elif saveStatus == -5:
    respondWithError(client, "E:SAVE_KEY_SIZE_INVALID")

proc getRequiredFiles(targetDirectory: string, whitelist: seq[string]) : seq[tuple[kind: PathComponent, relativePath: string]]  = 
  result = newSeq[tuple[kind: PathComponent, relativePath: string]]()
  let shouldFilter = whitelist.len > 0
  var s : Stat
  for filePath in walkDirRec(targetDirectory, yieldFilter={pcFile,pcDir}, relative=true, skipSpecial=true):
    let fullPath = targetDirectory / filePath 
    discard stat(fullPath.cstring, s)
    var kind : PathComponent
    if s.st_mode.S_ISDIR:
      kind = pcDir
    elif s.st_mode.S_ISREG:
      kind = pcFile
    
    if shouldFilter and shouldSkipFile(filePath, kind, whitelist):
      continue
    result.add (kind, filePath)

proc dumpSave(cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.} =
  var s: Stat
  if stat(cmd.targetFolder.cstring, s) != 0 or not s.st_mode.S_ISDIR:
    respondWithError(client, "E:TARGET_FOLDER_INVALID")
    return

  let saveStatus = checkSave(SAVE_DIRECTORY, cmd.sourceSaveName)
  if saveStatus != 0:
    await reportSaveError(saveStatus, client)
    return

  setupCredentials()

  let mntFolder = "/data/" & mountId
  discard rmdir(mntFolder.cstring)
  discard mkdir(mntFolder.cstring, 0o777)
  # Then dump everything
  var (errPath, handle) = mountSave(SAVE_DIRECTORY, cmd.sourceSaveName, mntFolder)
  var failed = errPath != 0
  if errPath != 0:
    respondWithError(client, "E:MOUNT_FAILED-" & errPath.toHex(2) & "-" & handle.toHex(8))
  else:
    for (kind, relativePath) in getRequiredFiles(mntFolder, cmd.dumpOnly):
      if kind == pcDir:
        let targetPath = joinPath(cmd.targetFolder, relativePath)
        discard mkdir(targetPath.cstring, 0o777)
      elif kind == pcFile:
        let targetFile = joinPath(cmd.targetFolder, relativePath)
        # Create it just in case
        let fd = open(targetFile.cstring, O_RDONLY, 0o777)
        discard close(fd)
        let sourceFile = joinPath(mntFolder, relativePath)
        try:
          copyFile(sourceFile, targetFile)
        except OSError:
          respondWithError(client, "E:COPY_FAILED")
          failed = true
          break
    discard umountSave(mntFolder, handle, false)
  discard rmdir(mntFolder.cstring)
  if failed:
    exitnow(-1)
  else:
    exitnow(0)

proc updateSave(cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.} =
  var s: Stat
  if stat(cmd.sourceFolder.cstring, s) != 0 or not s.st_mode.S_ISDIR:
    respondWithError(client, "E:SOURCE_FOLDER_INVALID")
    return 
  let saveStatus = checkSave(SAVE_DIRECTORY, cmd.targetSaveName)
  if saveStatus != 0:
    await reportSaveError(saveStatus, client)
    return

  setupCredentials()

  let mntFolder = "/data/" & mountId
  discard rmdir(mntFolder.cstring)
  discard mkdir(mntFolder.cstring, 0o777)
  # Then dump everything
  let (errPath, handle) = mountSave(SAVE_DIRECTORY, cmd.targetSaveName, mntFolder)
  var failed = errPath != 0
  if errPath != 0:
    respondWithError(client, "E:MOUNT_FAILED-" & handle.toHex(8))
  else:
    for (kind, relativePath) in getRequiredFiles(cmd.sourceFolder, cmd.selectOnly):
      let targetPath = joinPath(mntFolder, relativePath)
      if relativePath.startsWith("sce_sys"):
        discard setuid(0)
      else:
        discard setuid(1)
      if kind == pcDir:
        discard mkdir(targetPath.cstring, 0o777)
      elif kind == pcFile:
        # Create and truncate it just in case
        let fd = open(targetPath.cstring, O_CREAT or O_TRUNC, 0o777)
        discard close(fd)
        let sourcePath = joinPath(cmd.sourceFolder, relativePath)
        try:
          copyFile(sourcePath, targetPath)
        except OSError:
          respondWithError(client, "E:COPY_FAILED")
          failed = true
          break
    discard setuid(0)
    discard umountSave(mntFolder, handle, false)
  discard rmdir(mntFolder.cstring)
  if failed:
    exitnow(-1)
  else:
    exitnow(0)

proc listSaveFiles(cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.} =
  let saveStatus = checkSave(SAVE_DIRECTORY, cmd.listTargetSaveName)
  if saveStatus != 0:
    await reportSaveError(saveStatus, client)
    return

  setupCredentials()

  let mntFolder = "/data/" & mountId
  discard rmdir(mntFolder.cstring)
  discard mkdir(mntFolder.cstring, 0o777)

  let (errPath, handle) = mountSave(SAVE_DIRECTORY, cmd.listTargetSaveName, mntFolder)
  var failed = errPath != 0
  if errPath != 0:
    respondWithError(client, "E:MOUNT_FAILED-" & handle.toHex(8))
  else:
    var listEntries: seq[SaveListEntry] = newSeq[SaveListEntry]()
    for (kind, relativePath) in getRequiredFiles(mntFolder, @[]):
      var s : Stat
      if stat((mntFolder / relativePath).cstring, s) == -1:
        respondWithError(client, "E:STAT_FAILED-" & errno.toHex(8))
        break
      listEntries.add SaveListEntry(kind: kind, path: relativePath, mode: s.st_mode)
    respondWithJson(client, %listEntries)
    discard umountSave(mntFolder, handle, false)
  discard rmdir(mntFolder.cstring)
  if failed:
    exitnow(-1)
  else:
    exitnow(0)

type RequestHandler = proc (cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.}
var cmds : array[ClientRequestType, RequestHandler]
cmds[rtDumpSave] = dumpSave
cmds[rtUpdateSave] = updateSave
cmds[rtListSaveFiles] = listSaveFiles
var slot: int
var slotTotal: int
proc handleForkCmds(client: AsyncSocket, cmd: ClientRequest) {.async.} =
  inc slot
  # No matter who mounts
  # it will be a unique mount number
  inc slotTotal
  if slot >= 16:
    dec slot
    respondWithError(client, "E:SLOT_LIMIT_REACHED")
    return
  let pid = sys_fork()
  if pid == -1:
    respondWithError(client, "E:sys_fork-errno-" & $errno)
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
      respondWithOk(client)
    return
  var handler = cmds[cmd.RequestType]
  if not handler.isNil:
    await handler(cmd, client, "mnt" & $slotTotal)
  else:
    respondWithError(client, "E:CMD_NOT_IMPLEMENTED")
  exitnow(-1)

proc handleCmd*(client: AsyncSocket, cmd: ClientRequest) {.async.} =
  if cmd.RequestType == rtKeySet:
    respondWithKeySet(client, getMaxKeySet())
  elif cmd.RequestType == rtInvalid:
    respondWithError(client, "E:INVALID_CMD")
  else:
    await handleForkCmds(client, cmd)

