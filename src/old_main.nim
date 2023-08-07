import asyncdispatch
import strutils
import os
import logging
import colors
import posix
import "orbis/procinfo"
import "orbis/pad"
import "orbis/errors"
import "orbis/UserService"
import "orbis/SaveData"
import "orbis/systemservice"
import "./logger"
import "./config"
import "./utils"

import "./watchdog"
import "./scheduler"
import libjbc
{.passl: "-lSceLncUtil".}

var cred = get_cred()
## Allow process to make sockets async
cred.sonyCred = cred.sonyCred or uint64(0x40_00_00_00_00_00_00_00)
discard set_cred(cred)
var jobStream = newFutureStream[string]()


removeDir(DOWNLOAD_PATH)
createDir(DOWNLOAD_PATH)


var fileLog = newFileLogger(LOG_FILE, levelThreshold=lvlError, fmtStr="[$time] - $levelname: ")
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

var appId : int32 

var userId : int32

var controller = newController()
proc setup() : bool =
  kernelLog.log(lvlInfo, "Performing setup...")
  sudo:
    appId = getAppId(APP_TITLE_ID)
  kernelLog.log(lvlInfo, "My App Id is ", appId.toHex(8))
  var uir = getUserId(userId)
  if  uir != ORBIS_OK:
    log(lvlError, "Failed to get userId", uir.toHex(8))
    return false
  var userSaveDataDirectory = "/user/home/$#/savedata" % userId.toHex(8).toLowerAscii()
  kernelLog.log(lvlInfo, "Trying to mount..." , userSaveDataDirectory)
  let mr = sudo_mount(userSaveDataDirectory, "sd")
  if mr != 0:
    log(lvlError, "Failed to mount user save data directory: ", osLastError())
    return false
  kernelLog.log(lvlInfo, "Mounted")

  let ctrlInitResult = controller.init(userId)
  if ctrlInitResult != ORBIS_OK:
    log(lvlError, "Failed to initialize controller: ", ctrlInitResult)
    return false
  return true

if not setup():
  log(lvlError, "Failed to do setup")
  InfiniteLoop()


proc cleanup(): bool =
  let umr = sudo_unmount("sd")
  log(lvlInfo, "Trying to unmount sd...")
  if umr != 0:
    log(lvlError, "Failed to unmount user save data directory: ", osLastError())
    return false
  log(lvlInfo, "Unmounted save data directory")
  return true

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
    jobStream.complete()
    discard controller.updateColor(colRed, 255)
    break

discard cleanup()
InfiniteLoop()
