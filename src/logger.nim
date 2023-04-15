import std/logging

type KernelLogger* = ref object of Logger

proc newKernelLogger*(): KernelLogger =
  new(result)
  result.levelThreshold = lvlAll


method log*(logger: KernelLogger; level: Level; args: varargs[string, `$`]) =
  var str: string
  for arg in args:
    str.add(arg)
  echo str
