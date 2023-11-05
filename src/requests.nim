import json

type ClientRequestType* = enum
  rtKeySet,
  rtListSaveFiles,
  rtCreateSave,
  rtDumpSave,
  rtUpdateSave,
  rtResignSave,
  rtInvalid


type ListClientRequest* = object
  saveName*: string

type CreateClientRequest* = object
  sourceFolder*: string
  saveName*: string
  selectOnly*: seq[string]

type UpdateClientRequest* = object
  sourceFolder*: string
  saveName*: string
  selectOnly*: seq[string]

type DumpClientRequest* = object
  targetFolder*: string
  saveName*: string
  selectOnly*: seq[string]

type ResignClientRequest* = object
  accountId*: uint64
  saveName*: string

type ClientRequest* = object
  case RequestType*: ClientRequestType
  of rtKeySet, rtInvalid:
    discard
  of rtListSaveFiles:
    list*: ListClientRequest
  of rtCreateSave:
    create*: CreateClientRequest
  of rtUpdateSave:
    update*: UpdateClientRequest
  of rtDumpSave:
    dump*: DumpClientRequest
  of rtResignSave:
    resign*: ResignClientRequest

proc parseRequest*(data: string): ClientRequest = 
  try:
    let jsonData = parseJson(data)
    result = to(jsonData, ClientRequest)
  except JsonParsingError, KeyError, ValueError:
    result = ClientRequest(RequestType: rtInvalid)

