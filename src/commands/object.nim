import "./request"

type Command* = object
  useSlot*: bool
  useFork*: bool
  fun*: RequestHandler

