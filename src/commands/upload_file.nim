import strutils
import asyncdispatch
import asyncnet
import posix
import os

import "./response"
import "../syscalls"
import "../requests"
import "./object"

# Best buffer size 
const BUFFER_SIZE = 32768

proc writeToFile(fd: cint, buffer: array[BUFFER_SIZE, byte], amt: int): Future[bool] {.async.} =
  var p = 0
  while p < amt:
    let written = sys_write(fd, addr(buffer[p]), amt - p)
    if written <= 0:
      return false
    p += written
    let fut = sleepAsync(0)
    yield fut
  return true

proc UploadFile*(cmd: ClientRequest, client: AsyncSocket, id: string) {.async.} =
  let upload = cmd.upload
  let target = upload.target 
  createDir(parentDir(target))
  let file = open(target.cstring, O_CREAT or O_TRUNC or O_WRONLY, 0o777)
  if file < 0:
    respondWithError(client, "E:OPEN_FAILED-" & errno.toHex(8))
    return

  var buffer: array[BUFFER_SIZE, byte]

  var size = upload.size
  while size > 0:
    let sz = min(uint64(BUFFER_SIZE), size)
    let fut = client.recvInto(addr(buffer[0]), int(sz))
    let recvd = await withTimeout(fut, 1000)
    if not recvd:
      break

    yield fut
    if fut.failed:
      break

    let rd = fut.read()
    if not await writeToFile(file, buffer, rd):
      break
    size -= uint64(rd)

  discard file.close()
  if size > 0:
    discard unlink(target.cstring)
  else:
    respondWithOk(client)

let cmd* = Command(useSlot: false, useFork: false, fun: UploadFile)
