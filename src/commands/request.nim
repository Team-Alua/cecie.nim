import asyncdispatch
import asyncnet
import "../requests"

type RequestHandler* = proc (cmd: ClientRequest, client: AsyncSocket, mountId: string) {.async.}

