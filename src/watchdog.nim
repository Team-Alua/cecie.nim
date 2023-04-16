import logging
import config
import asyncdispatch

import "./job"

proc watchdog*(jobStream: FutureStream[string]) {.async.} = 
  log(lvlInfo, "watchdog: Starting up...")
  while true:
    var jobListener = newJobListener()

    let connFut = jobListener.connect(SERVER_IP, SERVER_PORT)
    yield connFut
    if connFut.failed:
      log(lvlInfo, "watchdog: Failed to connect to job server...", connFut.error.msg)
      jobListener.close()
      continue
    log(lvlInfo, "watchdog: Connected to server.")
    let listenFut = jobListener.listen($MAX_DECRYPTABLE_KEYSET, jobStream)
    yield listenFut
    if listenFut.failed:
      log(lvlError, "watchdog: Listen failed... ", listenFut.error.msg)
    log(lvlInfo, "watchdog: Attempting to reconnect to server.")
    jobListener.close()
