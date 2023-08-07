const
  PT_TRACE_ME* = 0
  PT_READ_I* = 1
  PT_READ_D* = 2

##  was	PT_READ_U	3	 * read word in child's user structure

const
  PT_WRITE_I* = 4
  PT_WRITE_D* = 5

##  was	PT_WRITE_U	6	 * write word in child's user structure

const
  PT_CONTINUE* = 7
  PT_KILL* = 8
  PT_STEP* = 9
  PT_ATTACH* = 10
  PT_DETACH* = 11
  PT_IO* = 12
  PT_LWPINFO* = 13
  PT_GETNUMLWPS* = 14
  PT_GETLWPLIST* = 15
  PT_CLEARSTEP* = 16
  PT_SETSTEP* = 17
  PT_SUSPEND* = 18
  PT_RESUME* = 19
  PT_TO_SCE* = 20
  PT_TO_SCX* = 21
  PT_SYSCALL* = 22
  PT_FOLLOW_FORK* = 23
  PT_GETREGS* = 33
  PT_SETREGS* = 34
  PT_GETFPREGS* = 35
  PT_SETFPREGS* = 36
  PT_GETDBREGS* = 37
  PT_SETDBREGS* = 38
  PT_VM_TIMESTAMP* = 40
  PT_VM_ENTRY* = 41
  PT_FIRSTMACH* = 64
