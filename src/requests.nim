import json
type ClientRequestType* = enum
  rtKeySet,
  rtCreateSave,
  rtDumpSave,
  rtUpdateSave,
  rtInvalid


type ClientRequest* = object
  case RequestType*: ClientRequestType
  of rtKeySet:
    discard
  of rtCreateSave, rtUpdateSave:
    sourceFolder*: string
    targetSaveName*: string
  of rtDumpSave:
    sourceSaveName*: string
    targetFolder*: string
  of rtInvalid:
    discard

proc parseRequest*(data: string): ClientRequest = 
  try:
    let jsonData = parseJson(data)
    result = to(jsonData, ClientRequest)
  except JsonParsingError, KeyError, ValueError:
    result = ClientRequest(RequestType: rtInvalid)

