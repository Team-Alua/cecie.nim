import parseCfg
import strutils
import nativesockets
import "orbis/kernel"
import "libjbc"

const DOWNLOAD_PATH* = "/data/cecie/downloads/"
const CONFIG_FILE* = "/data/cecie/config.ini"
const LOG_FILE* = "/data/cecie/log.txt"

let config = loadConfig(CONFIG_FILE)
let SERVER_IP* = config.getSectionValue("", "ip")
let SERVER_PORT* = nativesockets.Port(parseInt(config.getSectionValue("", "port")))

proc getMaxKeySet(): cshort = 
  var sampleSealedKey : array[96, byte]
  var response : cint
  sudo:
    response = getSaveDataGetBinFile(sampleSealedKey)
  if response != 0:
    return 0
  return cshort(sampleSealedKey[9] shl 8 + sampleSealedKey[8])

let MAX_DECRYPTABLE_KEYSET* = getMaxKeySet()
