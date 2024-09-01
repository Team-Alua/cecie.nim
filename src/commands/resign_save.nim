import asyncdispatch
import asyncnet
import posix
import strutils
import os

import "../requests"
import "../syscalls"
import "../config"
import "../savedata"
import "./utils"
import "./response"
import "./object"

proc ResignSave*(cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.} =
  let resign: ResignClientRequest = cmd.resign

  let (saveDir, saveName) = getSavePathComponents(resign.saveName, SAVE_DIRECTORY)
  let saveStatus = checkSave(saveDir, saveName)
  if saveStatus != 0:
    await reportSaveError(saveStatus, client)
    return
  setupCredentials()
  let mntFolder = "/data/" & mountId
  discard rmdir(mntFolder.cstring)
  discard mkdir(mntFolder.cstring, 0o777)

  var (errPath, handle) = mountSave(saveDir, saveName, mntFolder)
  var failed = errPath != 0
  if errPath != 0:
    respondWithError(client, "E:MOUNT_FAILED-" & errPath.toHex(2) & "-" & handle.toHex(8))
  else:
    # Open save file for writing
    # Change value @0x15C to supplied value
    # Can't modify sce_sys otherwise
    discard setuid(0); 
    let sfoPath = joinPath(mntFolder, "sce_sys/param.sfo")
    let sfoFd = open(sfoPath.cstring, O_RDWR, 0o777) 
    let writeResult = sys_pwrite(sfoFd, resign.accountId.addr, int(8), Off(0x15C))
    failed = writeResult != 8
    if writeResult < 0:
      respondWithError(client, "E:PWRITE_FAILED-" & errno.toHex(8))
    elif writeResult < 8:
      respondWithError(client, "E:PWRITE_INCOMPLETE_WRITE")
    elif failed:
      respondWithError(client, "E:UNKNOWN_ISSUE-" & writeResult.toHex(16))
    discard close(sfoFd)
    discard umountSave(mntFolder, handle, false)
  discard rmdir(mntFolder.cstring)
  if failed:
    exitnow(-1)
  else:
    exitnow(0)

let cmd* = Command(useSlot: true, useFork: true, fun: ResignSave)
