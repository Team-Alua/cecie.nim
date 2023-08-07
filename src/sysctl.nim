##
##  Top-level identifiers
##

const
  CTL_UNSPEC* = cint(0)
  CTL_KERN* = cint(1)
  CTL_VM* = cint(2)
  CTL_VFS* = cint(3)
  CTL_NET* = cint(4)
  CTL_DEBUG* = cint(5)
  CTL_HW* = cint(6)
  CTL_MACHDEP* = cint(7)
  CTL_USER* = cint(8)
  CTL_P1003_1B* = cint(9)
  CTL_MAXID* = cint(10)

##
##  CTL_KERN identifiers
##

const
  KERN_OSTYPE* = cint(1)
  KERN_OSRELEASE* = cint(2)
  KERN_OSREV* = cint(3)
  KERN_VERSION* = cint(4)
  KERN_MAXVNODES* = cint(5)
  KERN_MAXPROC* = cint(6)
  KERN_MAXFILES* = cint(7)
  KERN_ARGMAX* = cint(8)
  KERN_SECURELVL* = cint(9)
  KERN_HOSTNAME* = cint(10)
  KERN_HOSTID* = cint(11)
  KERN_CLOCKRATE* = cint(12)
  KERN_VNODE* = cint(13)
  KERN_PROC* = cint(14)
  KERN_FILE* = cint(15)
  KERN_PROF* = cint(16)
  KERN_POSIX1* = cint(17)
  KERN_NGROUPS* = cint(18)
  KERN_JOB_CONTROL* = cint(19)
  KERN_SAVED_IDS* = cint(20)
  KERN_BOOTTIME* = cint(21)
  KERN_NISDOMAINNAME* = cint(22)
  KERN_UPDATEINTERVAL* = cint(23)
  KERN_OSRELDATE* = cint(24)
  KERN_NTP_PLL* = cint(25)
  KERN_BOOTFILE* = cint(26)
  KERN_MAXFILESPERPROC* = cint(27)
  KERN_MAXPROCPERUID* = cint(28)
  KERN_DUMPDEV* = cint(29)
  KERN_IPC* = cint(30)
  KERN_DUMMY* = cint(31)
  KERN_PS_STRINGS* = cint(32)
  KERN_USRSTACK* = cint(33)
  KERN_LOGSIGEXIT* = cint(34)
  KERN_IOV_MAX* = cint(35)
  KERN_HOSTUUID* = cint(36)
  KERN_ARND* = cint(37)
  KERN_MAXID* = cint(38)

##
##  KERN_PROC subtypes
##

const
  KERN_PROC_ALL* = cint(0)
  KERN_PROC_PID* = cint(1)
  KERN_PROC_PGRP* = cint(2)
  KERN_PROC_SESSION* = cint(3)
  KERN_PROC_TTY* = cint(4)
  KERN_PROC_UID* = cint(5)
  KERN_PROC_RUID* = cint(6)
  KERN_PROC_ARGS* = cint(7)
  KERN_PROC_PROC* = cint(8)
  KERN_PROC_SV_NAME* = cint(9)
  KERN_PROC_RGID* = cint(10)
  KERN_PROC_GID* = cint(11)
  KERN_PROC_PATHNAME* = cint(12)
  KERN_PROC_OVMMAP* = cint(13)
  KERN_PROC_OFILEDESC* = cint(14)
  KERN_PROC_KSTACK* = cint(15)
  KERN_PROC_INC_THREAD* = cint(0x10)
  KERN_PROC_VMMAP* = cint(32)
  KERN_PROC_FILEDESC* = cint(33)
  KERN_PROC_GROUPS* = cint(34)

##
##  KERN_IPC identifiers
##

const
  KIPC_MAXSOCKBUF* = cint(1)
  KIPC_SOCKBUF_WASTE* = cint(2)
  KIPC_SOMAXCONN* = cint(3)
  KIPC_MAX_LINKHDR* = cint(4)
  KIPC_MAX_PROTOHDR* = cint(5)
  KIPC_MAX_HDR* = cint(6)
  KIPC_MAX_DATALEN* = cint(7)

##
##  CTL_HW identifiers
##

const
  HW_MACHINE* = cint(1)
  HW_MODEL* = cint(2)
  HW_NCPU* = cint(3)
  HW_BYTEORDER* = cint(4)
  HW_PHYSMEM* = cint(5)
  HW_USERMEM* = cint(6)
  HW_PAGESIZE* = cint(7)
  HW_DISKNAMES* = cint(8)
  HW_DISKSTATS* = cint(9)
  HW_FLOATINGPT* = cint(10)
  HW_MACHINE_ARCH* = cint(11)
  HW_REALMEM* = cint(12)
  HW_MAXID* = cint(13)

##
##  CTL_USER definitions
##

const
  USER_CS_PATH* = cint(1)
  USER_BC_BASE_MAX* = cint(2)
  USER_BC_DIM_MAX* = cint(3)
  USER_BC_SCALE_MAX* = cint(4)
  USER_BC_STRING_MAX* = cint(5)
  USER_COLL_WEIGHTS_MAX* = cint(6)
  USER_EXPR_NEST_MAX* = cint(7)
  USER_LINE_MAX* = cint(8)
  USER_RE_DUP_MAX* = cint(9)
  USER_POSIX2_VERSION* = cint(10)
  USER_POSIX2_C_BIND* = cint(11)
  USER_POSIX2_C_DEV* = cint(12)
  USER_POSIX2_CHAR_TERM* = cint(13)
  USER_POSIX2_FORT_DEV* = cint(14)
  USER_POSIX2_FORT_RUN* = cint(15)
  USER_POSIX2_LOCALEDEF* = cint(16)
  USER_POSIX2_SW_DEV* = cint(17)
  USER_POSIX2_UPE* = cint(18)
  USER_STREAM_MAX* = cint(19)
  USER_TZNAME_MAX* = cint(20)
  USER_MAXID* = cint(21)
  CTL_P1003_1B_ASYNCHRONOUS_IO* = cint(1)
  CTL_P1003_1B_MAPPED_FILES* = cint(2)
  CTL_P1003_1B_MEMLOCK* = cint(3)
  CTL_P1003_1B_MEMLOCK_RANGE* = cint(4)
  CTL_P1003_1B_MEMORY_PROTECTION* = cint(5)
  CTL_P1003_1B_MESSAGE_PASSING* = cint(6)
  CTL_P1003_1B_PRIORITIZED_IO* = cint(7)
  CTL_P1003_1B_PRIORITY_SCHEDULING* = cint(8)
  CTL_P1003_1B_REALTIME_SIGNALS* = cint(9)
  CTL_P1003_1B_SEMAPHORES* = cint(10)
  CTL_P1003_1B_FSYNC* = cint(11)
  CTL_P1003_1B_SHARED_MEMORY_OBJECTS* = cint(12)
  CTL_P1003_1B_SYNCHRONIZED_IO* = cint(13)
  CTL_P1003_1B_TIMERS* = cint(14)
  CTL_P1003_1B_AIO_LISTIO_MAX* = cint(15)
  CTL_P1003_1B_AIO_MAX* = cint(16)
  CTL_P1003_1B_AIO_PRIO_DELTA_MAX* = cint(17)
  CTL_P1003_1B_DELAYTIMER_MAX* = cint(18)
  CTL_P1003_1B_MQ_OPEN_MAX* = cint(19)
  CTL_P1003_1B_PAGESIZE* = cint(20)
  CTL_P1003_1B_RTSIG_MAX* = cint(21)
  CTL_P1003_1B_SEM_NSEMS_MAX* = cint(22)
  CTL_P1003_1B_SEM_VALUE_MAX* = cint(23)
  CTL_P1003_1B_SIGQUEUE_MAX* = cint(24)
  CTL_P1003_1B_TIMER_MAX* = cint(25)
  CTL_P1003_1B_MAXID* = cint(26)
