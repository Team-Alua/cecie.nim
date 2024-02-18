import strutils
import asyncdispatch
import asyncnet
import posix
import json
import nativesockets

import "./response"
import "../syscalls"
import "../requests"
import "./object"

proc sendfile*(fd: cint, soc: cint, 
                   offset: Off, nbytes: csize_t,
                  hdtr: pointer,sbytes: ptr Off,
                  flags: cint): cint {.cdecl, importc:"sendfile", header:"<orbis/libkernel.h>".}

const BUFFER_SIZE = 8192 * 4

type SizeResponse = object
  size: Off

proc download(fd: cint, soc: cint,  total: Off) {.async.} =
  var off : Off
  let size = csize_t(BUFFER_SIZE)
  var written : Off
  while off < total:
    let ret = sendfile(fd,soc, off, size , nil, addr(written), 0)
    if ret < 0:
      if errno != EAGAIN:
        echo "errno: ", errno, " written: ", written
        break 
    off += written
    await sleepAsync(0)
  

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


  # var buffer: array[BUFFER_SIZE, byte]
  var off: Off
  

  let soc = cint(client.getFd())
  await download(file, soc, total)
  discard file.close()

let cmd* = Command(useSlot: false, useFork: false, fun: DownloadFile)

