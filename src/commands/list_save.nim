import asyncdispatch
import asyncnet
import os
import posix
import json
import strutils

import "./utils"
import "./response"
import "../savedata"
import "../config"
import "../requests"
import "./object"

type SaveListEntry = object
  kind*: PathComponent
  path*: string
  size*: Off
  mode*: Mode
  uid*: Uid
  gid*: Gid

proc ListSaveFiles*(cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.} =
  let saveStatus = checkSave(SAVE_DIRECTORY, cmd.list.saveName);
  if saveStatus != 0:
    await reportSaveError(saveStatus, client)
    return

  setupCredentials()

  let mntFolder = "/data/" & mountId
  discard rmdir(mntFolder.cstring)
  discard mkdir(mntFolder.cstring, 0o777)

  let (errPath, handle) = mountSave(SAVE_DIRECTORY, cmd.list.saveName, mntFolder)
  var listEntries: seq[SaveListEntry] = newSeq[SaveListEntry]()
  var failed = errPath != 0

  if failed:
    respondWithError(client, "E:MOUNT_FAILED-" & handle.toHex(8))
  else:
    for (kind, relativePath) in getRequiredFiles(mntFolder, @[]):
      var s : Stat
      if stat((mntFolder / relativePath).cstring, s) == -1:
        respondWithError(client, "E:STAT_FAILED-" & errno.toHex(8))
        failed = true
        break
      listEntries.add SaveListEntry(kind: kind, path: relativePath, size: s.st_size, mode: s.st_mode, uid: s.st_uid, gid: s.st_gid)
    discard umountSave(mntFolder, handle, false)
  discard rmdir(mntFolder.cstring)
  if not failed:
    respondWithJson(client, %listEntries)
  # Should not do a srOk response since that's redundant
  exitnow(-1)

let cmd* = Command(useSlot: true, useFork: true, fun: ListSaveFiles)
