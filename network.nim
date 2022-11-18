import asyncnet, asyncfile, asyncdispatch

proc downloadFile(sock: AsyncSocket, targetFile: AsyncFile, fileSize: var int64) {.async.} =
  const MAX_BUFFER: int = 1024
  var buff : array[MAX_BUFFER, byte]
  while fileSize > 0:
    var dataRead = if fileSize > MAX_BUFFER: MAX_BUFFER else: int(fileSize)
    dataRead = await sock.recvInto(buff.addr,dataRead)
    await targetFile.writeBuffer(buff.addr, dataRead)
    fileSize -= dataRead

proc uploadFile(sock: AsyncSocket, sourceFile: AsyncFile, fileSize: var int64) {.async.} =
  const MAX_BUFFER: int = 1024
  var buff : array[MAX_BUFFER, byte]
  while filesize > 0:
    var dataRead = if fileSize > MAX_BUFFER: MAX_BUFFER else: int(fileSize)
    dataRead = await sourceFile.readBuffer(buff.addr, dataRead)
    await sock.send(buff.addr,dataRead)
    filesize -= dataRead
