import asyncdispatch
import config
import logging
import asyncnet
import asyncfile
import os
import strutils

import "./job"

proc executor*(jobName: string): Future[void] {.async.} = 
  var job = newJob(jobName, SERVER_IP, SERVER_PORT)

  var zipHandle = openAsync(joinPath(DOWNLOAD_PATH, jobName & ".zip"), fmReadWrite)

  yield job.notify("Downloading job data...")
  let downloadFut = job.download(zipHandle)
  yield downloadFut
  if downloadFut.failed:
    log(lvlError, "jobHandler: Failed to download zip. ", downloadFut.error.msg)
    yield job.notify("Job failed to download file.")
    yield job.complete("Job: $# Error: $#" % [jobName, "Failed to download zip"])
  else:
    yield job.notify("Job data downloaded successfully.")
    yield job.complete()
  zipHandle.close()
