import strutils
import asyncdispatch
import asyncnet
import posix
import json
import nativesockets

import "./response"
import "../requests"
import "./object"

proc sendfile*(fd: cint, soc: cint, 
                   offset: Off, nbytes: csize_t,
                  hdtr: pointer,sbytes: ptr Off,
                  flags: cint): cint {.cdecl, importc:"sendfile", header:"<orbis/libkernel.h>".}


type SizeResponse = object
  size: Off

proc download(fd: cint, soc: cint,  total: Off) {.async.} =
  let size = csize_t(32768)
  var off : Off
  while off < total:
    var written : Off
    let ret = sendfile(fd,soc, off, size, nil, addr(written), 0)
    if ret < 0:
      if errno != EAGAIN:
        break 
    off += written
    await sleepAsync(0)

proc DownloadFile*(cmd: ClientRequest, client: AsyncSocket, id: string) {.async.} =
  let download: DownloadClientRequest = cmd.download
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


  # var buffer: array[BUFFER_SIZE, byte]
  let soc = cint(client.getFd())
  await download(file, soc, total)
  discard file.close()

let cmd* = Command(useSlot: false, useFork: false, fun: DownloadFile)

