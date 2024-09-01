import asyncdispatch
import asyncnet
import posix
import strutils
import os

import "../requests"
import "./response"
import "./utils"
import "../config"
import "../savedata"
import "./object"

proc UpdateSave*(cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.} =
  let update: UpdateClientRequest = cmd.update

  var s: Stat
  if stat(update.sourceFolder.cstring, s) != 0 or not s.st_mode.S_ISDIR:
    respondWithError(client, "E:SOURCE_FOLDER_INVALID")
    return 
  let (saveDir, saveName) = getSavePathComponents(update.saveName, SAVE_DIRECTORY)
  let saveStatus = checkSave(saveDir, saveName)
  if saveStatus != 0:
    await reportSaveError(saveStatus, client)
    return

  setupCredentials()

  let mntFolder = "/data/" & mountId
  discard rmdir(mntFolder.cstring)
  discard mkdir(mntFolder.cstring, 0o777)
  # Then dump everything
  let (errPath, handle) = mountSave(saveDir, saveName, mntFolder)
  var failed = errPath != 0
  if errPath != 0:
    respondWithError(client, "E:MOUNT_FAILED-" & handle.toHex(8))
  else:
    for (kind, relativePath) in getRequiredFiles(update.sourceFolder, update.selectOnly):
      if relativePath.startsWith("sce_sys") or relativePath == "memory.dat":
        discard setuid(0)
      else:
        discard setuid(1)

      let targetPath = joinPath(mntFolder, relativePath)
      if kind == pcDir:
        discard mkdir(targetPath.cstring, 0o777)
      elif kind == pcFile:
        # Create and truncate it just in case
        let fd = open(targetPath.cstring, O_CREAT or O_TRUNC, 0o777)
        discard close(fd)
        let sourcePath = joinPath(update.sourceFolder, relativePath)
        try:
          copyFile(sourcePath, targetPath)
        except IOError:
          respondWithError(client, "E:COPY_FAILED")
          failed = true
          break
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

let cmd* = Command(useSlot: true, useFork: true, fun: UpdateSave)
