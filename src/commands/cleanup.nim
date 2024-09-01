import asyncdispatch
import asyncnet
import os

import "../requests"
import "./response"
import "../config"
import "./object"
import "./utils"
import json

type DeleteEntry = object
  path: string
  error: string

proc Cleanup*(cmd: ClientRequest, client: AsyncSocket, id: string) {.async.} =
  let clean : CleanClientRequest = cmd.clean

  # Delete the save before deleting the folder
  var failed: seq[DeleteEntry] = @[]
  let (saveDir, saveName) = getSavePathComponents(clean.saveName, SAVE_DIRECTORY)

  if saveDir != SAVE_DIRECTORY:
    let saveStatus = checkSave(saveDir, saveName)
    if saveStatus != 0:
      await reportSaveError(saveStatus, client)
      return
  
  if saveName.len > 0:
    let saveImagePath = joinPath(saveDir, saveName)
    try:
      removeFile(saveImagePath)
    except OSError as e:
      failed.add DeleteEntry(path: saveImagePath, error: e.msg)
      discard  

    let saveKeyPath = joinPath(saveDir, saveName & ".bin")
    try:
      removeFile(saveKeyPath)
    except OSError as e:
      failed.add DeleteEntry(path: saveKeyPath, error: e.msg)
      discard  
    
  let folder = clean.folder
  if folder.len > 0:
    try:
      removeDir(folder)
    except OSError as e:
      failed.add DeleteEntry(path: folder, error: e.msg)
      discard
  respondWithJson(client, %failed)

let cmd* = Command(useSlot: false, useFork: false, fun: Cleanup)
