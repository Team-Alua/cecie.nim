import "./syscalls"
import "./savedata"
import "./requests"

import "./commands/object"
import "./commands/response"
import "./commands/list_save"
import "./commands/dump_save"
import "./commands/update_save"
import "./commands/resign_save"
import "./commands/cleanup"
import "./commands/upload_file"
import "./commands/download_file"
import "./commands/list_files"
import strutils
import asyncnet
import asyncdispatch
import posix

import marshal


var cmds : array[ClientRequestType, Command]

cmds[rtDumpSave] = dumpSave.cmd
cmds[rtUpdateSave] = updateSave.cmd
cmds[rtListSaveFiles] = listSave.cmd
cmds[rtResignSave] = resignSave.cmd
cmds[rtClean] = cleanup.cmd
cmds[rtUploadFile] = uploadFile.cmd 
cmds[rtDownloadFile] = downloadFile.cmd 
cmds[rtListFiles] = listFiles.cmd

var slot: uint
var slotTotal: uint64

proc handleForkCmds(client: AsyncSocket, req: ClientRequest, cmd: Command, id: string) {.async.} =
  let pid = sys_fork()
  if pid == -1:
    respondWithError(client, "E:sys_fork-errno-" & $errno)
    return
  elif pid > 0:
    var status: cint
    var cPid = Pid(pid)
    while true: 
      let wPid = waitpid(cPid, status, WNOHANG)
      if cPid == wPid:
        break
      await sleepAsync(250)
    if status == 0:
      respondWithOk(client)
  else:
    await cmd.fun(req, client, id)
    exitnow(-1)

proc handleSlotCmds(client: AsyncSocket, req: ClientRequest, cmd: Command) {.async.} =
  inc slot
  if slot >= 16:
    dec slot
    respondWithError(client, "E:SLOT_LIMIT_REACHED")
    return
  inc slotTotal
  await handleForkCmds(client, req, cmd, "mnt" & $slotTotal)
  dec slot


proc handleCmd*(client: AsyncSocket, req: ClientRequest) {.async.} =
  if req.RequestType == rtKeySet:
    respondWithKeySet(client, getMaxKeySet())
    return
  elif req.RequestType == rtInvalid:
    respondWithError(client, "E:INVALID_CMD")
    return
  let handler = cmds[req.RequestType]
  if handler.fun.isNil:
    respondWithError(client, "E:CMD_NOT_IMPLEMENTED")
  elif handler.useSlot:
    await handleSlotCmds(client, req, handler)
  elif handler.useFork:
    await handleForkCmds(client, req, handler, "")
  else:
    let fut = handler.fun(req, client, "")
    yield fut
    if fut.failed:
      respondWithError(client, fut.error.msg)

