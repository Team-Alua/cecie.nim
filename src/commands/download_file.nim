import strutils
import asyncdispatch
import asyncnet
import posix
import json

import "./response"
import "../syscalls"
import "../requests"
import "./object"

const BUFFER_SIZE = 32768

proc readFromFile(fd: cint, buffer: array[BUFFER_SIZE, byte], amt: int): Future[bool] {.async.} =
  if buffer.len < amt:
    return false

  var p = 0
  while p < amt:
    let rd = sys_read(fd, addr(buffer[p]), amt - p)
    if rd <= 0:
      return false
    p += rd
    await sleepAsync(0)

  return true

proc sendToClient(client: AsyncSocket, buffer: array[BUFFER_SIZE, byte], amt: int): Future[bool] {.async.} =
  if buffer.len < amt:
    return false
  let fut = client.send(addr(buffer[0]), amt)
  let sent = await withTimeout(fut, 1000)
  if not sent:
    return false
  yield fut
  return not fut.failed

type SizeResponse = object
  size: Off

proc DownloadFile*(cmd: ClientRequest, client: AsyncSocket, id: string) {.async.} =
  let download = cmd.download
  let source = download.source

  var s : Stat
  if stat(source.cstring, s) < 0:
    respondWithError(client, "E:STAT_FAILED-" & errno.toHex(8))
    return

  let file = open(source.cstring, O_RDONLY, 0o777)
  if file < 0:
    respondWithError(client, "E:OPEN_FAILED-" & errno.toHex(8))
    return
  var total = s.st_size
  var resp: SizeResponse
  resp.size = total
  respondWithJson(client, %resp)

  var buffer: array[BUFFER_SIZE, byte]

  while total > 0:
    let size = int(min(total, Off(BUFFER_SIZE)))
    if not await readFromFile(file, buffer, size):
      break
    if not await sendToClient(client, buffer, size):
      break
    total -= size
  discard file.close()

let cmd* = Command(useSlot: false, useFork: false, fun: DownloadFile)
