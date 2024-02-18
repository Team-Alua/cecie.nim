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


proc DumpSave*(cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.} =
  var s: Stat
  if stat(cmd.dump.targetFolder.cstring, s) != 0 or not s.st_mode.S_ISDIR:
    respondWithError(client, "E:TARGET_FOLDER_INVALID")
    return

  let saveStatus = checkSave(SAVE_DIRECTORY, cmd.dump.saveName)
  if saveStatus != 0:
    await reportSaveError(saveStatus, client)
    return

  setupCredentials()

  let mntFolder = "/data/" & mountId
  discard rmdir(mntFolder.cstring)
  discard mkdir(mntFolder.cstring, 0o777)
  # Then dump everything
  var (errPath, handle) = mountSave(SAVE_DIRECTORY, cmd.dump.saveName, mntFolder)
  var failed = errPath != 0
  if errPath != 0:
    respondWithError(client, "E:MOUNT_FAILED-" & errPath.toHex(2) & "-" & handle.toHex(8))
  else:
    for (kind, relativePath) in getRequiredFiles(mntFolder, cmd.dump.selectOnly):
      if kind == pcDir:
        let targetPath = joinPath(cmd.dump.targetFolder, relativePath)
        discard mkdir(targetPath.cstring, 0o777)
      elif kind == pcFile:
        let targetFile = joinPath(cmd.dump.targetFolder, relativePath)
        # Create it just in case
        let fd = open(targetFile.cstring, O_CREAT, 0o777)
        discard close(fd)
        let sourceFile = joinPath(mntFolder, relativePath)
        try:
          copyFile(sourceFile, targetFile)
        except IOError:
          respondWithError(client, "E:COPY_FAILED")
          failed = true
          break
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

let cmd* = Command(useSlot: true, useFork: true, fun: DumpSave)
