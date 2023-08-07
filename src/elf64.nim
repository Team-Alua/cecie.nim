## -
##  Copyright (c) 1996-1998 John D. Polstra.
##  All rights reserved.
##
##  Redistribution and use in source and binary forms, with or without
##  modification, are permitted provided that the following conditions
##  are met:
##  1. Redistributions of source code must retain the above copyright
##     notice, this list of conditions and the following disclaimer.
##  2. Redistributions in binary form must reproduce the above copyright
##     notice, this list of conditions and the following disclaimer in the
##     documentation and/or other materials provided with the distribution.
##
##  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
##  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
##  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
##  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
##  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
##  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
##  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
##  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
##  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
##  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
##  SUCH DAMAGE.
##
##  $FreeBSD: release/9.0.0/sys/sys/elf64.h 186667 2009-01-01 02:08:56Z obrien $
##

type Elf_Note* {.bycopy.}= object
  n_namesz: uint32
  n_descsz: uint32
  n_type: uint32

const EI_NIDENT* = 16 # Size of e_ident array

##
##  ELF definitions common to all 64-bit architectures.
##
type
  Elf64_Addr* = uint64
  Elf64_Half* = uint16
  Elf64_Off* = uint64
  Elf64_Sword* = int32
  Elf64_Sxword* = int64
  Elf64_Word* = uint32
  Elf64_Lword* = uint64
  Elf64_Xword* = uint64
##
##  Types of dynamic symbol hash table bucket and chain elements.
##
##  This is inconsistent among 64 bit architectures, so a machine dependent
##  typedef is required.
##
type
  Elf64_Hashelt* = Elf64_Word
##  Non-standard class-dependent datatype used for abstraction.
type
  Elf64_Size* = Elf64_Xword
  Elf64_Ssize* = Elf64_Sxword
##
##  ELF header.
##
type
  Elf64_Ehdr* {.bycopy.} = object
    e_ident*: array[EI_NIDENT, cuchar]
    ##  File identification.
    e_type*: Elf64_Half
    ##  File type.
    e_machine*: Elf64_Half
    ##  Machine architecture.
    e_version*: Elf64_Word
    ##  ELF format version.
    e_entry*: Elf64_Addr
    ##  Entry point.
    e_phoff*: Elf64_Off
    ##  Program header file offset.
    e_shoff*: Elf64_Off
    ##  Section header file offset.
    e_flags*: Elf64_Word
    ##  Architecture-specific flags.
    e_ehsize*: Elf64_Half
    ##  Size of ELF header in bytes.
    e_phentsize*: Elf64_Half
    ##  Size of program header entry.
    e_phnum*: Elf64_Half
    ##  Number of program header entries.
    e_shentsize*: Elf64_Half
    ##  Size of section header entry.
    e_shnum*: Elf64_Half
    ##  Number of section header entries.
    e_shstrndx*: Elf64_Half
    ##  Section name strings section.

##
##  Section header.
##
type
  Elf64_Shdr* {.bycopy.} = object
    sh_name*: Elf64_Word
    ##  Section name (index into the
    ## 					   section header string table).
    sh_type*: Elf64_Word
    ##  Section type.
    sh_flags*: Elf64_Xword
    ##  Section flags.
    sh_addr*: Elf64_Addr
    ##  Address in memory image.
    sh_offset*: Elf64_Off
    ##  Offset in file.
    sh_size*: Elf64_Xword
    ##  Size in bytes.
    sh_link*: Elf64_Word
    ##  Index of a related section.
    sh_info*: Elf64_Word
    ##  Depends on section type.
    sh_addralign*: Elf64_Xword
    ##  Alignment in bytes.
    sh_entsize*: Elf64_Xword
    ##  Size of each entry in section.

##
##  Program header.
##
type
  Elf64_Phdr* {.bycopy.} = object
    p_type*: Elf64_Word
    ##  Entry type.
    p_flags*: Elf64_Word
    ##  Access permission flags.
    p_offset*: Elf64_Off
    ##  File offset of contents.
    p_vaddr*: Elf64_Addr
    ##  Virtual address in memory image.
    p_paddr*: Elf64_Addr
    ##  Physical address (not used).
    p_filesz*: Elf64_Xword
    ##  Size of contents in file.
    p_memsz*: Elf64_Xword
    ##  Size of contents in memory.
    p_align*: Elf64_Xword
    ##  Alignment in memory and file.

##
##  Dynamic structure.  The ".dynamic" section contains an array of them.
##
type
  INNER_C_UNION_elf64_1* {.bycopy, union.} = object
    d_val*: Elf64_Xword
    ##  Integer value.
    d_ptr*: Elf64_Addr
    ##  Address value.

type
  Elf64_Dyn* {.bycopy.} = object
    d_tag*: Elf64_Sxword
    ##  Entry type.
    d_un*: INNER_C_UNION_elf64_1

##
##  Relocation entries.
##
##  Relocations that don't need an addend field.
type
  Elf64_Rel* {.bycopy.} = object
    r_offset*: Elf64_Addr
    ##  Location to be relocated.
    r_info*: Elf64_Xword
    ##  Relocation type and symbol index.

##  Relocations that need an addend field.
type
  Elf64_Rela* {.bycopy.} = object
    r_offset*: Elf64_Addr
    ##  Location to be relocated.
    r_info*: Elf64_Xword
    ##  Relocation type and symbol index.
    r_addend*: Elf64_Sxword
    ##  Addend.

##  Macros for accessing the fields of r_info.
template ELF64_R_SYM*(info: untyped): untyped =
  ((info) shr 32)

template ELF64_R_TYPE*(info: untyped): untyped =
  ((info) and 0xffffffff)

##  Macro for constructing r_info from field values.
template ELF64_R_INFO*(sym, `type`: untyped): untyped =
  (((sym) shl 32) + ((`type`) and 0xffffffff))

template ELF64_R_TYPE_DATA*(info: untyped): untyped =
  (((Elf64_Xword)(info) shl 32) shr 40)

template ELF64_R_TYPE_ID*(info: untyped): untyped =
  (((Elf64_Xword)(info) shl 56) shr 56)

template ELF64_R_TYPE_INFO*(data, `type`: untyped): untyped =
  (((Elf64_Xword)(data) shl 8) + (Elf64_Xword)(`type`))

##
## 	Note entry header
##
type
  Elf64_Nhdr* = Elf_Note
##
## 	Move entry
##
type
  Elf64_Move* {.bycopy.} = object
    m_value*: Elf64_Lword
    ##  symbol value
    m_info*: Elf64_Xword
    ##  size + index
    m_poffset*: Elf64_Xword
    ##  symbol offset
    m_repeat*: Elf64_Half
    ##  repeat count
    m_stride*: Elf64_Half
    ##  stride info

template ELF64_M_SYM*(info: untyped): untyped =
  ((info) shr 8)

template ELF64_M_SIZE*(info: untyped): untyped =
  (cast[cuchar]((info)))

template ELF64_M_INFO*(sym, size: untyped): untyped =
  (((sym) shl 8) + cast[cuchar]((size)))

##
## 	Hardware/Software capabilities entry
##
type
  INNER_C_UNION_elf64_3* {.bycopy, union.} = object
    c_val*: Elf64_Xword
    c_ptr*: Elf64_Addr

type
  Elf64_Cap* {.bycopy.} = object
    c_tag*: Elf64_Xword
    ##  how to interpret value
    c_un*: INNER_C_UNION_elf64_3

##
##  Symbol table entries.
##
type
  Elf64_Sym* {.bycopy.} = object
    st_name*: Elf64_Word
    ##  String table index of name.
    st_info*: cuchar
    ##  Type and binding information.
    st_other*: cuchar
    ##  Reserved (not used).
    st_shndx*: Elf64_Half
    ##  Section index of symbol.
    st_value*: Elf64_Addr
    ##  Symbol value.
    st_size*: Elf64_Xword
    ##  Size of associated object.

##  Macros for accessing the fields of st_info.
template ELF64_ST_BIND*(info: untyped): untyped =
  ((info) shr 4)

template ELF64_ST_TYPE*(info: untyped): untyped =
  ((info) and 0xf)

##  Macro for constructing st_info from field values.
template ELF64_ST_INFO*(`bind`, `type`: untyped): untyped =
  (((`bind`) shl 4) + ((`type`) and 0xf))

##  Macro for accessing the fields of st_other.
template ELF64_ST_VISIBILITY*(oth: untyped): untyped =
  ((oth) and 0x3)

##  Structures used by Sun & GNU-style symbol versioning.
type
  Elf64_Verdef* {.bycopy.} = object
    vd_version*: Elf64_Half
    vd_flags*: Elf64_Half
    vd_ndx*: Elf64_Half
    vd_cnt*: Elf64_Half
    vd_hash*: Elf64_Word
    vd_aux*: Elf64_Word
    vd_next*: Elf64_Word

  Elf64_Verdaux* {.bycopy.} = object
    vda_name*: Elf64_Word
    vda_next*: Elf64_Word

  Elf64_Verneed* {.bycopy.} = object
    vn_version*: Elf64_Half
    vn_cnt*: Elf64_Half
    vn_file*: Elf64_Word
    vn_aux*: Elf64_Word
    vn_next*: Elf64_Word

  Elf64_Vernaux* {.bycopy.} = object
    vna_hash*: Elf64_Word
    vna_flags*: Elf64_Half
    vna_other*: Elf64_Half
    vna_name*: Elf64_Word
    vna_next*: Elf64_Word

  Elf64_Versym* = Elf64_Half
  Elf64_Syminfo* {.bycopy.} = object
    si_boundto*: Elf64_Half
    ##  direct bindings - symbol bound to
    si_flags*: Elf64_Half
    ##  per symbol flags
  
