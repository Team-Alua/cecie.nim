import logging
import strutils
import posix
import os
import endians
import strformat
import strutils
import "./logger"
import "libjbc"
import "orbis/SaveData"
import "orbis/UserService"
import "orbis/ProcInfo"
import "orbis/errors"
import "./utils"
import "./sysctl"
import "./ptrace"
{.push stackTrace:off, checks: off, optimization: speed.}
proc kernelRdmsr(register: uint32) : uint64 {.cdecl,exportc.} =
  asm """
    ".intel_syntax;"
    "mov ecx, edi;"
    "rdmsr;"
    "shl rdx, 32;"
    "or rax, rdx;"
    : "=a"(`result`) """

proc cpu_enable_wp() {.cdecl, exportc.} =
  asm """
    ".intel_syntax;"
    "mov rax, cr0;"
    "or rax, 0x10000;"
    "mov cr0, rax;"
  """
#cpu_enable_wp:
#    mov rax, cr0
#    or rax, 0x10000
#    mov cr0, rax
#    ret
proc cpu_disable_wp() {.cdecl, exportc.} =
  asm """
    ".intel_syntax;"
    "mov rax, cr0;"
    "and rax, ~0x10000;"
    "mov cr0, rax;"
  """

#cpu_disable_wp:
#  mov rax, cr0
#  and rax, ~0x10000
#  mov cr0, rax
#  ret
template toCError(sysResult: cint, isError: bool) : untyped {.dirty.} = 
  if isError:
    errno = sysResult
    result = -1
  else:
    # Since some syscalls can return a 
    # valid small negative number
    errno = 0
    result = sysResult

proc sys_fork(): cint {.cdecl, exportc.} =
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 2;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

proc sys_open(path: cstring, flags: cint, mode: cint = 0): cint {.cdecl, exportc.} =
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 5;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)
proc sys_read(fd: cint, buffer: pointer, sz: int): cint {.cdecl, exportc.} =
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 3;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

proc sys_write(fd: cint, buffer: pointer, sz: int): cint {.cdecl, exportc.} = 
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 4;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

proc sys_close(fd: cint): cint {.cdecl, exportc.} = 
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 6;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

proc sys_ptrace(req: cint, pid: Pid, address: pointer, data: int64): cint {.cdecl, exportc.} =
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax, 26;"
    "mov r10, rcx;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

proc sys_sysctl(name: var cint, namelen: cuint,
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

proc sys_ioctl(fd: cint, request: cuint): cint {.cdecl, exportc.} =
  var err: bool
  asm """
    ".intel_syntax;"
    "mov rax,  54;"
    "syscall;"
    : "=a"(`result`), "=@ccc"(`err`)
  """
  toCError(result, err)

{.pop.}


kexec:
  # Patches to disable privilege checks for procfs
  var g = kernelRdmsr(uint32(0xC0_00_00_82)) - 0x1C0
#  var off = uint64(0x000f3d31)
  cpu_disable_wp()
  var off = uint64(0x00217a2a)
  var p = cast[ptr array[64, uint8]](g + off) 
  p[][0] = 0xEB
  p[][1] = 0x13

  off = uint64(0x00217894)
  p = cast[ptr array[64, uint8]](g + off) 
  p[][0] = 0x31 
  p[][1] = 0xC0 
  p[][2] = 0xEB 
  p[][3] = 0x2A
  cpu_enable_wp()

type Process = object
  pid: Pid
  name: string

proc getProcessList(): seq[Process] =
  var rawList: seq[byte]
  var mit: array[3, cint] = [
    CTL_KERN,
    KERN_PROC,
    cint(0),
  ]
  var size: csize_t = 0
  if sys_sysctl(mit[0], cuint(mit.len), nil, size, nil, csize_t(0)) < 0:
    echo "sysctl errno: ", errno
    return @[]
  if size == 0:
    echo "size == 0 "
    return @[]
  rawList = newSeq[byte](Natural(size))
  if sys_sysctl(mit[0], cuint(mit.len), addr(rawList[0]), size, nil, csize_t(0)) < 0:
    echo "sysctl(2) errno: ", errno
    return @[]
  var KINFO_SIZE: cint
  littleEndian32(addr(KINFO_SIZE), addr(rawList[0]))
  var procCount = Natural(int(size) / int(KINFO_SIZE))
  var procList = newSeq[Process](procCount)
  for idx in 0..procCount-1:
    let offset = KINFO_SIZE * idx
    for i in 0..19:
      let chr = rawList[offset + 447 + i]
      if chr == 0:
        break
      procList[idx].name.add(char(chr))
    littleEndian32(addr(procList[idx].pid), addr(rawList[offset + 72]))
  return procList


type ProcessMap = object
  pm_type: cint
  pm_start_addr: uint64
  pm_end_addr: uint64
  pm_size: uint64
  pm_prot: uint32

proc getProcessMap(p: Pid) : seq[ProcessMap]  =
  var mit: array[4, cint] = [
    CTL_KERN,
    KERN_PROC,
    KERN_PROC_VMMAP,
    cint(p),
  ]
  var size: csize_t
  if sys_sysctl(mit[0], cuint(mit.len), nil, size, nil, csize_t(0)) < 0:
    echo "sysctl errno: ", errno
    return @[]

  if size == 0:
    return @[]

  var rawList = newSeq[byte](Natural(size))
  if sys_sysctl(mit[0], cuint(mit.len), addr(rawList[0]), size, nil, csize_t(0)) < 0:
    echo "sysctl(2) errno: ", errno
    return @[]
  var entrySize: int32
  littleEndian32(addr(entrySize), addr(rawList[0]))
  var entryCount = Natural(int(size) / int(entrySize))
  var mapList = newSeq[ProcessMap](entryCount)
  for idx in 0..entryCount-1:
    var offset : int = idx * entrySize
    var typeOffset = offset + 0x4
    littleEndian32(addr(mapList[idx].pm_type), addr(rawList[typeOffset]))
    var startAddrOffset = offset + 0x8
    littleEndian64(addr(mapList[idx].pm_start_addr), addr(rawList[startAddrOffset]))
    var endAddrOffset = offset + 0x10
    littleEndian64(addr(mapList[idx].pm_end_addr), addr(rawList[endAddrOffset]))
    var protOffset = offset + 0x38
    littleEndian64(addr(mapList[idx].pm_prot), addr(rawList[protOffset]))
    mapList[idx].pm_size = mapList[idx].pm_end_addr - mapList[idx].pm_start_addr
  return mapList

var cred = get_cred()
## Make a system process
cred.sonyCred = cred.sonyCred or uint64(1 shl 0x3E)
discard set_cred(cred)

var kernelLog = newKernelLogger()
addHandler(kernelLog)

if ORBIS_OK != savedata.init():
  log(lvlFatal, "Failed to initialize sceSaveData")
  InfiniteLoop()

if ORBIS_OK != userservice.init():
  log(lvlFatal, "Failed to initialize user service")
  InfiniteLoop()


var userId : int32
block:
  var uir = getUserId(userId)
  if uir != ORBIS_OK:
    log(lvlError, "Failed to get userId", uir.toHex(8))
    InfiniteLoop()

var sd : SaveData
sd.blocks = 96
sd.userId = userId
sd.titleId = APP_TITLE_ID
sd.dirName= "Init"

sd.mountMode(SaveDataMountMode.DESTRUCT_OFF,
             SaveDataMountMode.CREATE2, 
             SaveDataMountMode.RDWR)

echo "Save Data: ", $sd
var mounter: SaveDataMounter
mounter.data = sd
block fork_block:
  let res = mounter.mount()
  if res.code != 0'u32:
    log(lvlInfo, "There was an error " & res.code.toHex(8))
    break fork_block
  var pid = Pid(sys_fork())
  if pid == 0:
    echo "In child process"
    for i in 0..10:
      echo "Child process loop: ", i
      discard sleep(1)
    echo "Child process will exit now"
    exitnow(0)
  else:
    var res: cint
    discard wait(addr(res))
  discard mounter.unmount()


echo "procfs mount result: ", sudo_mount("procfs", "proc")
var procList = getProcessList()

#for path in walkDirRec("/proc"):
#  var s: Stat
#  if not path.endsWith("map"):
#    continue
#  echo "path: ", path
#  discard stat(path, s)
#  echo "stat: ", s
echo "Proc List"
var ppid : Pid
for procItem in procList:
  if procItem.name == "SceShellCore":
    echo procItem
    ppid = procItem.pid
    break
#echo "Process Map Entries" 
#for mapEntry in procMap:
#  if mapEntry.pm_prot == 0b101'u32:
#    echo "Read executable" , mapEntry

#echo "Done getting process map"
#var fd = open("/data/mapdump", fmWrite, 0777)
#var offset = 0
#while offset < procMap.len:
#  var written = fd.writeBuffer(addr(procMap[offset]), Natural(procMap.len - offset))
#  if written <= 0:
#    break
#  offset += written 
#close(fd)

#echo "pid:", getpid()
#discard setuid(0)
#ppid = getpid()
var procMap = getProcessMap(ppid)
echo "pid:", getpid()
echo "ppid: " , ppid
# Parent process
var p = fmt"/proc/{ppid}/mem"
var fd = sys_open(p.cstring, O_RDWR, 0)
var data: string
type ptrace_io_desc = object
  piod_op: cint
  piod_offs: pointer
  piod_addr: pointer
  piod_len: csize_t
if fd == -1:
  echo "errno: ", errno
else:
#  var got = 0x013cfe80'u64
  var got = 0x0'u64
  while true:
    echo "calling sys_read"
    for mapEntry in procMap:
      if mapEntry.pm_prot == 0b0:
        echo "start: " , mapEntry.pm_start_addr.toHex(16), " size: ", mapEntry.pm_size.toHex(16)
        var lData: array[64, byte]

        discard lseek(fd, Off(mapEntry.pm_start_addr), SEEK_SET)
        var rr = sys_read(fd, addr(lData), 64)
        #echo "done calling sys_read"
        #echo "rr: ", rr
        if rr < 0:
          echo "rr: ", rr, " errno: ", errno
        if rr <= 0:
          continue
#        lData[0] = 0
#        discard lseek(fd, Off(mapEntry.pm_start_addr + 0xE351D9'u64), SEEK_SET)
#        echo "I wrote: ", sys_write(fd, addr(lData), rr)
#        discard lseek(fd, Off(mapEntry.pm_start_addr + 0xE351D9'u64), SEEK_SET)
#        discard sys_read(fd, addr(lData), 64)
#        echo lData
#        echo "rr :", rr
#        echo "offset:" , mapEntry.pm_start_addr.toHex(16)
        var code: string
        for idx in 0..rr-1:
          code.add(lData[idx].toHex(2))
          if idx < rr-1:
            code.add(' ')
        echo code
    break
  echo "ptrace(detach) = ", errno
  echo "Data:", data
  if sys_close(fd) == -1:
    echo "errno: ", errno

discard sudo_unmount("proc")
InfiniteLoop()
