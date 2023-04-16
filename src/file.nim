import asyncfile
import asyncdispatch
import posix
import os

proc openAsync*(filepath: string, flags: cint, perm: cint): AsyncFile = 
  var fd = open(filepath, flags or O_NONBLOCK, perm)
  if fd == -1:
    raiseOSError(osLastError())
  newAsyncFile(fd.AsyncFD)

