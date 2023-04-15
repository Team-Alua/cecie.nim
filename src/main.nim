import asyncdispatch
import os
import logging
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
asyncCheck watchdog(jobStream)
asyncCheck scheduler(jobStream)

while true:
  discard controller.update()
  if controller.pressed(OrbisPadButtons.CIRCLE):
    echo "Quitting..."
    break
  poll(1)

InfiniteLoop()
