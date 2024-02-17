import asyncdispatch
import asyncnet
import os

import "../requests"
import "./response"
import "../config"
import "./object"
import json

type DeleteEntry = object
  path: string
  error: string

proc Cleanup*(cmd: ClientRequest, client: AsyncSocket, id: string) {.async.} =
  # Delete the save before deleting the folder
  let saveName = cmd.clean.saveName
  var failed: seq[DeleteEntry] = @[]
  if saveName.len > 0:
    let saveImagePath = joinPath(SAVE_DIRECTORY, saveName)
    try:
      removeFile(saveImagePath)
    except OSError as e:
      failed.add DeleteEntry(path: saveImagePath, error: e.msg)
      discard  

    let saveKeyPath = joinPath(SAVE_DIRECTORY, saveName & ".bin")
    try:
      removeFile(saveKeyPath)
    except OSError as e:
      failed.add DeleteEntry(path: saveKeyPath, error: e.msg)
      discard  
    
  let folder = cmd.clean.folder
  if folder.len > 0:
    try:
      removeDir(folder)
    except OSError as e:
      failed.add DeleteEntry(path: folder, error: e.msg)
      discard
  respondWithJson(client, %failed)

let cmd* = Command(useSlot: false, useFork: false, fun: Cleanup)
