import asyncdispatch
import os
import logging
import colors
import "orbis/pad"
import "orbis/errors"
import "orbis/UserService"
import "orbis/SaveData"

import "./logger"
import "./config"
import "./utils"

import "./watchdog"
import "./scheduler"

var jobStream = newFutureStream[string]()


removeDir(DOWNLOAD_PATH)
createDir(DOWNLOAD_PATH)


var fileLog = newFileLogger(LOG_FILE, levelThreshold=lvlError)
fileLog.flushThreshold = lvlError


var kernelLog = newKernelLogger()

addHandler(fileLog)
addHandler(kernelLog)

if ORBIS_OK != userservice.init():
  log(lvlFatal, "Failed to initialize user service")
  InfiniteLoop()

if ORBIS_OK != savedata.init():
  log(lvlFatal, "Failed to initialize sceSaveData")
  InfiniteLoop()

if ORBIS_OK != pad.init():
  log(lvlFatal, "Failed to initialize scePad")
  InfiniteLoop()

var userId : int32

var controller = newController()

discard getUserId(userId)
discard controller.init(userId)

discard controller.updateColor(colGreen, 255)
asyncCheck watchdog(jobStream)
asyncCheck scheduler(jobStream)
type ServerState = enum
  RUNNING
  PAUSED
  FINISHED
var servState : ServerState = RUNNING

while true:
  discard controller.update()
  if controller.held(OrbisPadButtons.L2):
    if controller.released(OrbisPadButtons.CIRCLE):
      servState = FINISHED
    elif controller.released(OrbisPadButtons.OPTIONS):
      if servState == PAUSED:
        servState = RUNNING
      else:
        servState = PAUSED

  if servState == RUNNING:
    discard controller.updateColor(colGreen, 255)
    poll(1)
  elif servState == PAUSED:
    discard controller.updateColor(colYellow, 255)
  elif servState == FINISHED:
    discard controller.updateColor(colRed, 255)
    break
InfiniteLoop()
