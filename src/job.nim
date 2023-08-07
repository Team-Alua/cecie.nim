import asyncfile
import asyncnet
import asyncdispatch
import network
import json
import strutils
import asyncstreams

##
##             JobListener
##

type JobListener* = ref object
  socket: AsyncSocket

proc newJobListener*() : JobListener = 
  var socket: AsyncSocket = newAsyncSocket()
  return JobListener(socket: socket)


proc connect*(listener: JobListener, address: string, port: Port) {.async.} = 
  await listener.socket.connect(address, port)

proc close*(listener: JobListener) =
  if not listener.socket.isClosed:
    listener.socket.close()

proc listen*(l : JobListener, data: string, jobStream: FutureStream[string]) {.async.} = 
  await l.socket.send($(%* {
    "path": "/jobs/listen",
    "data": data
  }))
  while true:
    var data = await l.socket.recvLine()
    if data.len == 0:
      break 
    let jsonResponse = parseJson(data) 
    for job in jsonResponse["jobs"].getElems():
      let jobName = job.getStr("")
      if jobName != "":
        await jobStream.write(jobName)

##
##             JobList
##

type JobList* = ref object
  jobs: array[16, string]

proc getIndex(jl: JobList, job: string): int = 
  for idx, value in jl.jobs:
    if value == job:
      return idx
  return -1


proc nextEmpty(jl: JobList): int = 
  for idx, value in jl.jobs:
    if value == "":
      return idx
  return -1

proc isFull*(jl: JobList): bool = 
  return jl.nextEmpty() == -1

proc add*(jl: var JobList, job: string): int =
  var idx = jl.getIndex(job)
  if idx == -1 and not jl.isFull:
    idx = jl.nextEmpty() 
    jl.jobs[idx] = job
  return idx

proc remove*(jl: var JobList, job: string): int =
  var idx = jl.getIndex(job)
  if idx != -1:
    jl.jobs[idx] = ""
  return idx

proc remove*(jl: var JobList, jobIndex: int) =
  jl.jobs[jobIndex] = ""

proc has*(jl: JobList, job: string): bool =
  return jl.getIndex(job) > -1

##
##
##
##        Individual Job
##
##

type JobError* = object of CatchableError

type Job* = ref object
  id: string
  serverIp: string
  serverPort: Port

proc newJob*(id: string, sIp: string, sPort: Port) : Job = 
  Job(id: id, serverIp: sIp, serverPort: sPort)

proc createRequest[V](id, cmd: string; data: V): string = 
  let jsonPayload = %* {
    "path": "/job/$#/$#" % [id, cmd],
    "data": data
  }
  return $jsonPayload

static: 
  doAssert createRequest("abc", "upload", "") == "{\"path\":\"/job/abc/upload\",\"data\":\"\"}"
  doAssert createRequest("abc", "upload", "hash") == "{\"path\":\"/job/abc/upload\",\"data\":\"hash\"}"
  doAssert createRequest("abc", "upload", 1) == "{\"path\":\"/job/abc/upload\",\"data\":1}"

proc getResponseValue[T](n: JsonNode): T =
  when T is int:
    return getInt(n)
  elif T is string:
    return n.getStr()
  elif T is float:
    return n.getFloat()
  elif T is bool:
    return n.getBool()
  else:
    return

proc send[T, V](socket: AsyncSocket, id: string,  cmd: string, data: V): Future[T] {.async.} = 
  var reqStr: string = createRequest[V](id, cmd, data)
  await socket.send(reqStr & "\r\L")
  let response = await socket.recvLine()

  if response == "":
    raise newException(JobError, "Server closed connection")

  let responseJson = parseJson(response)
  if responseJson["status"].getStr("") != "OK":
    raise newException(JobError, responseJson["status"].getStr("Unknown Error"))

  when T isnot void:
    return getResponseValue[T](responseJson["data"])

proc quickConnect(sIp: string, sPort: Port): Future[AsyncSocket] {.async.} =
  var sock = newAsyncSocket()
  let connFut = sock.connect(sIp, sPort)
  yield connFut
  if connFut.failed:
    sock.close()
    raise connFut.error
  return sock

proc upload*(job: Job, file: AsyncFile, filepath: string): Future[void] {.async.} =
  if filepath.len == 0 or filepath[0] != '/':
    raise newException(ValueError, "Invalid file path provided")

  let sock = await quickConnect(job.serverIp, job.serverPort)

  let uploadFut =  send[void, int64](sock, job.id, "upload" & filepath, file.getFileSize())
  yield uploadFut
  if uploadFut.failed:
    sock.close()
    raise uploadFut.error

  let fut = uploadFile(sock, file)
  yield fut
  sock.close()
  if fut.failed:
    raise fut.error

proc verify*(job: Job, filepath: string, hash: string): Future[void] {.async.} =
  if filepath.len == 0 or filepath[0] != '/':
    raise newException(ValueError, "Invalid file path provided")

  let sock = await quickConnect(job.serverIp, job.serverPort)
  let fut = send[void, string](sock, job.id, "verify" & filepath, hash)
  yield fut
  sock.close()
  if fut.failed:
    raise fut.error

proc download*(job: Job, file: AsyncFile) {.async.} = 
  let sock = await quickConnect(job.serverIp, job.serverPort)

  let sendFut = send[int, string](sock, job.id, "download", "")
  yield sendFut
  if sendFut.failed:
    sock.close()
    raise sendFut.error

  var fz: int64 = read(sendFut)

  let fut = downloadFile(sock, file, fz)
  yield fut

  sock.close() 
  if fut.failed:
    raise fut.error

proc notify*(job: Job, message: string) {.async.} =
  let sock = await quickConnect(job.serverIp, job.serverPort)
  let sendFut = send[string, string](sock, job.id, "notify", message)
  yield sendFut
  sock.close() 
  if sendFut.failed:
    raise sendFut.error

proc complete*(job: Job, errorMessage: string = "") {.async.} =
  let sock = await quickConnect(job.serverIp, job.serverPort)
  let sendFut = send[string, string](sock, job.id, "complete", errorMessage)
  yield sendFut
  sock.close()
  if sendFut.failed:
    raise sendFut.error

