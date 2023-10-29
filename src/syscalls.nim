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

proc sys_read*(fd: cint, buffer: pointer, sz: int): cint {.cdecl, exportc.} =
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 3;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

proc sys_pread*(fd: cint, buffer: pointer, sz: int, offset: Off): cint {.cdecl, exportc.} =
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 475;"
    "mov r10, rcx;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

proc sys_write*(fd: cint, buffer: pointer, sz: int): cint {.cdecl, exportc.} = 
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 4;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

proc sys_pwrite*(fd: cint, buffer: pointer, sz: int, offset: Off): cint {.cdecl, exportc.} =
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 476;"
    "mov r10, rcx;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

proc sys_close*(fd: cint): cint {.cdecl, exportc.} = 
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 6;"
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

proc sys_unmount*(dir: cstring, flags: cint): cint {.cdecl, exportc.} = 
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 22;"
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

proc sys_rename*(src: cstring, dest: cstring): cint {.cdecl, exportc.} = 
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 128;"
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

proc sys_get_authinfo*(pid : Pid, authinfo: pointer) : cint {.cdecl, exportc.} =
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 587;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
proc sys_sysctl*(name: var cint, namelen: cuint,
                oldp: pointer, oldlenp: var csize_t,
                newp: pointer, newlen: csize_t): cint {.cdecl, exportc.} =
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 202;"
    "mov r10, rcx;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

{.pop.}
