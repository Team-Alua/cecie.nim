import std/logging
import asyncdispatch
import "./executor"
import "./job"

proc scheduler*(jobStream: FutureStream[string]) {.async.} =
  var currentJobs = JobList()
  var jobHandles: array[16, Future[void]]
  log(lvlInfo, "scheduler: Starting up...")
  while true:
    # check if any jobs are done
    # update currentJobs list accordingly
    for index, jobHandle in jobHandles:
      if jobHandle.isNil:
        continue

      if jobHandle.finished:
        jobHandles[index] = nil
        currentJobs.remove(index) 

    # check for new jobs
    while not currentJobs.isFull and jobStream.len > 0: 
      let (active, jobName) = await jobStream.read()
      if not active:
        break

      # Ignore jobs that already exist
      if currentJobs.has(jobName):
        continue

      let jobIdx = currentJobs.add(jobName)
      jobHandles[jobIdx] = executor(jobName)
    await sleepAsync(0)
