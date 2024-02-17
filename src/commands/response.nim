import os
import posix
import asyncdispatch
import asyncnet

# $$
import marshal

type ServerResponseType* = enum
  srOk,
  srInvalid,
  srKeySet,
  srJson

type ServerResponse* = object
  case ResponseType*: ServerResponseType
  of srOk:
    discard
  of srKeySet:
    keyset*: cshort
  of srInvalid:
    code*: string
  of srJson:
    json*: string

template respondWithOk*(client: untyped) = 
  await client.send($$ServerResponse(ResponseType: srOk) & "\r\L")

template respondWithError*(client,errorCode: untyped) = 
  await client.send($$ServerResponse(ResponseType: srInvalid, code: errorCode) & "\r\L")

template respondWithKeySet*(client,fwKeyset: untyped) =
  await client.send($$ServerResponse(ResponseType: srKeySet, keyset: fwKeyset) & "\r\L")

template respondWithJson*(client,jsonNode: untyped) =
  await client.send($$ServerResponse(ResponseType: srJson, json: $jsonNode) & "\r\L")

proc reportSaveError*(saveStatus: int, client:AsyncSocket) {.async.} =
  if saveStatus == -1:
    respondWithError(client, "E:SAVE_IMAGE_INVALID")
  elif saveStatus == -2 or saveStatus == -3:
    respondWithError(client, "E:SAVE_IMAGE_SIZE_INVALID")
  elif saveStatus == -4:
    respondWithError(client, "E:SAVE_KEY_INVALID")
  elif saveStatus == -5:
    respondWithError(client, "E:SAVE_KEY_SIZE_INVALID")

