import posix
{.push stackTrace:off, checks: off, optimization: speed.}
template toCError(sysResult: cint, isError: bool) : untyped {.dirty.} = 
  if isError:
    errno = sysResult
    result = -1
  else:
    # Since some syscalls can return a 
    # valid small negative number
    errno = 0
    result = sysResult

proc sys_open*(path: cstring, flags: cint, mode: cint = 0): cint {.cdecl, exportc.} =
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 5;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)


proc sys_symlink*(src: cstring, dest: cstring): cint {.cdecl, exportc.} = 
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 57;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

proc sys_link*(src: cstring, dest: cstring): cint {.cdecl, exportc.} = 
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 9;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)
proc sys_chroot*(newRoot: cstring): cint {.cdecl, exportc.} = 
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 61;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

proc sys_mknod*(path: cstring, mode: Mode, dev: Dev): cint {.cdecl, exportc.} = 
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 14;"
    "mov r10, rcx;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)
proc sys_fork*(): cint {.cdecl, exportc.} = 
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 2;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
{.pop.}
