import libjbc
import posix
import os
import strutils

proc shouldSkipFile*(relativePath: string, kind: PathComponent, fileWhitelist: seq[string]): bool =
  var skipFile = false

  if kind == pcFile:
    skipFile = not fileWhitelist.contains(relativePath)
  elif kind == pcDir:
    skipFile = true
    for entry in fileWhitelist:
      if entry.startsWith(relativePath):
        skipFile = false
        break
  else:
    # Always skip non regular files
    # and directories
    skipFile = true
  return skipFile

proc setupCredentials*() = 
  # Run as root
  var cred = get_cred()
  cred.sonyCred = cred.sonyCred or uint64(0x40_00_00_00_00_00_00_00)
  cred.sceProcType = uint64(0x3801000000000013)
  discard set_cred(cred)
  discard setuid(0)

proc checkSave*(saveDirectory: string, saveName: string) : int = 
  var s: Stat
  let saveImagePath = joinPath(saveDirectory, saveName)
  if stat(saveImagePath.cstring, s) != 0 or s.st_mode.S_ISDIR:
    return -1

  const saveBlocks = 1 shl 15
  if s.st_size mod saveBlocks != 0:
    return -2
  
  const minImageSize = 96 * saveBlocks
  const maxImageSize = (1 shl 15) * saveBlocks
  if s.st_size > maxImageSize or s.st_size < minImageSize:
    return -3

  let saveKeyPath = joinPath(saveDirectory, saveName & ".bin")
  if stat(saveKeyPath.cstring, s) != 0 or s.st_mode.S_ISDIR:
    return -4

  if s.st_size != 96:
    return -5
  return 0


proc getRequiredFiles*(targetDirectory: string, whitelist: seq[string]) : seq[tuple[kind: PathComponent, relativePath: string]]  = 
  result = newSeq[tuple[kind: PathComponent, relativePath: string]]()
  let shouldFilter = whitelist.len > 0
  var s : Stat

  for filePath in walkDirRec(targetDirectory, yieldFilter={pcFile,pcDir}, relative=true, skipSpecial=true):
    let fullPath = targetDirectory / filePath 
    discard stat(fullPath.cstring, s)
    var kind : PathComponent
    if s.st_mode.S_ISDIR:
      kind = pcDir
    elif s.st_mode.S_ISREG:
      kind = pcFile
    
    if shouldFilter and shouldSkipFile(filePath, kind, whitelist):
      continue
    result.add (kind, filePath)

