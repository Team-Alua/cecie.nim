import std/[asyncnet, asyncfutures, asyncstreams, asyncdispatch]
import std/[oids, tables, json]
import network

type Container = object
  titleId: string
  directoryName: string
  saveBlocks: uint64
  fingerprint: string

type Session = object
  id: string
  lockedFiles: Table[string, bool]
  container: Container
  mountPoint: string

type SessionRef = ref Session


type SessionCommandKind = enum
  sckCreate

type SessionCommand = object
  response: Future[SessionRef] 
  case kind: SessionCommandKind
    of sckCreate: 
      container: Container

proc mountLoop() {.async.} =
  while true:
    await sleepAsync(0)

proc recorderLoop(stream: FutureStream[SessionCommand]) {.async.} =
  let sessions = newTable[string, SessionRef]()
  while true:
    let (retrieved, cmd) = await read(stream)
    if not retrieved:
      return
    case cmd.kind:
    of sckCreate:
      let session = new(Session)
      let id = $genOid()
      session[].id = id
      session[].container = cmd.container
      sessions[id] = session
      cmd.response.complete(session)



proc clientHandler(client: AsyncSocket) {.async.} =
  let jsonPayload = await client.recvLine()
  let jsonNode = parseJson(jsonPayload)
  jsonNode["cmd"]
   


proc main {.async.} =
  let sessionCommandStream = newFutureStream[SessionCommand]()
  asyncCheck mountLoop()
  asyncCheck recorderLoop(sessionCommandStream)

  var server = newAsyncSocket()
  server.bindAddr(Port(1234))
  server.listen()

  while true:
    let client = await server.accept()
    asyncCheck clientHandler(client)

asyncCheck main()
runForever()
