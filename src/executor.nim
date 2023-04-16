import asyncdispatch
import os
import config
import logging
import asyncfile
import strutils
import "./job"
import "./file"
import posix
proc executor*(jobName: string): Future[void] {.async.} = 
  var job = newJob(jobName, SERVER_IP, SERVER_PORT)
  var zipFilePath = joinPath(DOWNLOAD_PATH, jobName & ".zip")
  var zipHandle = openAsync(zipFilePath, O_CREAT or O_TRUNC or O_RDWR, 0777)

  yield job.notify("Downloading job data...")
  let downloadFut = job.download(zipHandle)
  yield downloadFut
  zipHandle.close()
  if downloadFut.failed:
    log(lvlError, "executor: Failed to download zip. ", downloadFut.error.msg)
    yield job.notify("Job failed to download file.")
    yield job.complete("Job: $# Error: $#" % [jobName, "Failed to download zip"])
  else:
    yield job.notify("Job data downloaded successfully.")
    yield job.complete()

  removeFile(zipFilePath)
