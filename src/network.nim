import asyncnet, asyncfile, asyncdispatch

proc downloadFile*(sock: AsyncSocket, targetFile: AsyncFile, totalSize: int64): Future[bool] {.async.} =
  var size = totalSize
  const MAX_BUFFER: int = 1024
  var buff : array[MAX_BUFFER, byte]
  while size > 0:
    let dataRead = await sock.recvInto(buff.addr,MAX_BUFFER)
    if dataRead == 0:
      break
    size -= dataRead.int64
    await targetFile.writeBuffer(buff.addr, dataRead)
  return size == 0

proc uploadFile*(sock: AsyncSocket, sourceFile: AsyncFile) {.async.} =
  const MAX_BUFFER: int = 1024
  var buff : array[MAX_BUFFER, byte]
  while true:
    let dataRead = await sourceFile.readBuffer(buff.addr, MAX_BUFFER)
    if dataRead == 0:
      break
    await sock.send(buff.addr,dataRead)
