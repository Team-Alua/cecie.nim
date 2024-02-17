import asyncdispatch 
import strutils
import asyncnet
import logging
import "logger"
import "syscalls"
import "./config"
import "./savedata"
import "./utils"
import "./commands"
import "./requests"

import libjbc
import posix
{.passc: "-fstack-protector".}
addHandler(newKernelLogger())
signal(SIG_PIPE, SIG_IGN)

proc setup() =
  # Load private libs
  if not loadPrivLibs():
    log(lvlError, "Failed to load private lib")
    InfiniteLoop()
  else:
    log(lvlInfo, "Loaded private lib!")
  # Mount required devices into sandbox
  discard sudo_mount("/dev/", "rootdev")
  var s : Stat
  echo stat("/rootdev/pfsctldev", s)
  echo sys_mknod("/dev/pfsctldev", Mode(S_IFCHR or 0o777), s.st_dev)
  echo stat("/rootdev/lvdctl", s)
  echo sys_mknod("/dev/lvdctl", Mode(S_IFCHR or 0o777), s.st_dev)
  echo stat("/rootdev/sbl_srv", s)
  echo sys_mknod("/dev/sbl_srv", Mode(S_IFCHR or 0o777), s.st_dev)
  discard sudo_unmount("rootdev")

  # Get max keyset that can be decrypted
  discard getMaxKeySet()
var old_cred = get_cred()
old_cred.sonyCred = old_cred.sonyCred or uint64(0x40_00_00_00_00_00_00_00)
var cred = get_cred()
## Allow process to make sockets async
cred.sonyCred = cred.sonyCred or uint64(0x40_00_00_00_00_00_00_00)
cred.sceProcType = uint64(0x3801000000000013)
discard set_cred(cred)
discard setuid(0)
setup()
discard set_cred(old_cred)


proc handleClient(clientContext : tuple[address: string, client: AsyncSocket]) {.async.} = 
  # Wait for message
  # let address = clientContext.address
  let client = clientContext.client
  var data = await client.recvLine()
  if data.len == 0:
    return
  let req = parseRequest(data)
  await handleCmd(client, req)
  client.close()

proc requestListener() {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(SERVER_PORT)
  server.listen()
  echo "Listening at port ", int(SERVER_PORT)
  while true:
    let clientContext = await server.acceptAddr()
    asyncCheck handleClient(clientContext)

asyncCheck requestListener()

while true:
  poll()
