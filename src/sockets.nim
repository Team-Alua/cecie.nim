import asyncnet
import nativesockets
import asyncdispatch
import os
import "libjbc"
# Pretty much createAsyncNativeSocket
# but with the proper sudo at the right place

proc newAsyncSocket*() : AsyncSocket = 
  let handle = createNativeSocket()
  if handle == osInvalidSocket:
    raiseOSError(osLastError())
  sudo:
    handle.setBlocking(false)
  let fd = handle.AsyncFD
  register(fd)
  try:
    result = newAsyncSocket(fd)
  except CatchableError as e:
    # Close socket handle if exception occurs
    handle.close()
    raise e
