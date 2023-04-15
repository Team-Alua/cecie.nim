import asyncfile
import macros
import streams
import os
import strutils
import posix
import asyncdispatch
import nativesockets
import logging

import "orbis/kernel"
import "orbis/errors"
import "orbis/UserService"
import "orbis/SaveData"
import "libjbc"

import "./logger"
import "./config"
import "./utils"

import "./watchdog"
import "./scheduler"

var jobStream = newFutureStream[string]()


proc setupFileDirectories() = 
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

asyncCheck watchdog(jobStream)
asyncCheck scheduler(jobStream)

while true:
  poll(1)
