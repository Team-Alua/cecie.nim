import parseCfg
import strutils
import nativesockets

const CONFIG_FILE* = "/data/cecie/config.ini"
const LOG_FILE* = "/data/cecie/log.txt"

var config: Config = newConfig()
try:
  config = loadConfig(CONFIG_FILE)
except IOError:
  discard

let SAVE_DIRECTORY* = config.getSectionValue("", "saveDirectory", "/data")
let SERVER_PORT* = nativesockets.Port(parseInt(config.getSectionValue("", "port", "1234")))

