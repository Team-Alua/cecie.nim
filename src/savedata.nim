import os
import posix
import logging

import "orbis/kernel"
import "orbis/savedata_advanced"

import "syscalls"

import libjbc

var sceFsUfsAllocateSaveData : proc (fd: cint, imageSize: culonglong, imageFlags: culonglong, ext: cint) : cint {.cdecl.}

type CreatePfsSaveDataOpt {.bycopy.} = object
  blockSize: cint
  idk: array[2, byte]

var sceFsInitCreatePfsSaveDataOpt: proc(opt: ptr CreatePfsSaveDataOpt) : cint {.cdecl.}
var sceFsCreatePfsSaveDataImage : proc(opt: ptr CreatePfsSaveDataOpt, volumePath: cstring, idk:cint, volumeSize: culonglong, decryptSealedKey : array[32,byte]) : cint {.cdecl.}

type MountSaveDataOpt = object
  idk: bool
  budgetid: cstring

var sceFsInitMountSaveDataOpt: proc(opt: ptr MountSaveDataOpt) : cint {.cdecl.}
var sceFsMountSaveData: proc(opt: ptr MountSaveDataOpt, volumePath: cstring, mountPath: cstring, decryptedSealKey: array[32, byte]) : cint {.cdecl.}



type UmountSaveDataOpt = object
  dummy: bool
var sceFsInitUmountSaveDataOpt: proc(opt: ptr UmountSaveDataOpt) : cint {.cdecl.}
var sceFsUmountSaveData: proc(opt: ptr UmountSaveDataOpt, mountPath: cstring, handle: cint, ignoreErrors: bool) : cint {.cdecl.}

var statfs: proc() {.cdecl.}

proc loadPrivLibs*(): bool  = 
  const privDirectory = "/system/priv/lib"
  let mr = sudo_mount(privDirectory, "priv")
  if mr != 0:
    log(lvlError, "Failed to mount user save data directory: ", errno)
    return false
  let sys = sceKernelLoadStartModule("/priv/libSceFsInternalForVsh.sprx",0,nil,0,nil,nil);
  discard sudo_unmount("priv")
  var success = sys >= 0
  if sys >= 0:
    discard sceKernelDlsym(sys, "sceFsInitCreatePfsSaveDataOpt", cast[ptr pointer](sceFsInitCreatePfsSaveDataOpt.addr));
    discard sceKernelDlsym(sys, "sceFsCreatePfsSaveDataImage", cast[ptr pointer](sceFsCreatePfsSaveDataImage.addr));
    discard sceKernelDlsym(sys, "sceFsUfsAllocateSaveData", cast[ptr pointer](sceFsUfsAllocateSaveData.addr));

    discard sceKernelDlsym(sys, "sceFsInitMountSaveDataOpt", cast[ptr pointer](sceFsInitMountSaveDataOpt.addr));
    discard sceKernelDlsym(sys, "sceFsMountSaveData", cast[ptr pointer](sceFsMountSaveData.addr));

    discard sceKernelDlsym(sys, "sceFsInitUmountSaveDataOpt", cast[ptr pointer](sceFsInitUmountSaveDataOpt.addr));
    discard sceKernelDlsym(sys, "sceFsUmountSaveData", cast[ptr pointer](sceFsUmountSaveData.addr));
  const commonDirectory = "/system/common/lib"
  discard sudo_mount(commonDirectory, "common")
  let kernel_sys = sceKernelLoadStartModule("/common/libkernel_sys.sprx",0,nil,0,nil,nil);
  discard sudo_unmount("common")
  if kernel_sys >= 0:
    discard sceKernelDlsym(kernel_sys, "statfs", cast[ptr pointer](statfs.addr));
  else:
    echo "kernel_sys: ", kernel_sys
    success = false
  return success

proc createSave*(folder: string, saveName: string, blocks: cint) : cint =
  var sealedKey : array[96, byte]
  var ret: cint
  ret = generateSealedKey(sealedKey)
  if ret == -1:
    return -1
  var decryptedSealedKey: array[32, byte]
  ret = decryptSealedKey(sealedKey, decryptedSealedKey)
  if ret == -1:
    return -2
  var volumeKeyPath : string = joinPath(folder, saveName & ".bin")
  var volumePath : string = joinPath(folder, saveName)
  removeFile(volumeKeyPath)
  removeFile(volumePath)
  var fd = sys_open(volumeKeyPath.cstring, O_CREAT or O_EXCL or O_RDWR, 0o777)
  if fd == -1:
    echo "errno: ", errno, " file: ", volumeKeyPath
    return -3
  discard write(fd,sealedKey.addr, sealedKey.len)
  discard close(fd)
  fd = sys_open(volumePath.cstring,O_CREAT or O_EXCL or O_RDWR, 0o777)
  if fd == -1:
    return -4
  var volumeSize = culonglong(blocks shl 15)
  ret = sceFsUfsAllocateSaveData(fd, volumeSize, 0 shl 7, 0)
  discard close(fd);
  if ret < 0:
    return -5
  var opt : CreatePfsSaveDataOpt
  ret = sceFsInitCreatePfsSaveDataOpt(opt.addr)
  if ret < 0:
    return -6
  ret = sceFsCreatePfsSaveDataImage(opt.addr, volumePath.cstring, 0, volumeSize, decryptedSealedKey)
  if ret < 0:
    return -7
  fd = sys_open(volumePath.cstring,O_RDONLY,0)
  discard fsync(fd);
  discard close(fd);
  return 0

proc mountSave*(folder: string, saveName: string, mountPath: string) : cint = 
  var sealedKey : array[96, byte]
  var volumeKeyPath : string = joinPath(folder, saveName & ".bin")
  var volumePath : string = joinPath(folder, saveName)
  var fd = sys_open(volumeKeyPath.cstring, O_RDONLY, 0)
  if fd == -1:
    echo "errno: ", errno, " file: ", volumeKeyPath
    return -1
  discard read(fd,sealedKey.addr, sealedKey.len)
  discard close(fd)

  var decryptedSealedKey: array[32, byte]
  var ret = decryptSealedKey(sealedKey, decryptedSealedKey)
  if ret == -1:
    return -2
  var opt : MountSaveDataOpt
  discard sceFsInitMountSaveDataOpt(opt.addr)
  ret = sceFsMountSaveData(opt.addr, volumePath.cstring, mountPath.cstring, decryptedSealedKey)
  if ret < 0:
    return -3
  return ret

proc umountSave*(mountPath: string, handle: cint, ignoreErrors: bool) : cint = 
  var opt: UmountSaveDataOpt
  discard sceFsInitUmountSaveDataOpt(opt.addr)
  return sceFsUmountSaveData(opt.addr,mountPath.cstring, handle, ignoreErrors)
