[BITS 16]

section .data

global RGOS_INFO_STRUCT, rgos_bd

RGOS_INFO_STRUCT:
    ; The info struct that will be passed to the kernel
    rgos_bd: db 0x00 ; Boot device (1 byte)

global fat_partition_start_lba

fat_partition_start_lba: dq 0 ; Starting LBA of the FAT32 partition

global BPB_NumFATs, BPB_FATSz32, BPB_RootClus, BPB_SecPerClus, BPB_RsvdSecCnt, BPB_BytsPerSec

BPB_info:
    ; BPB info from the FAT32 boot sector
    BPB_NumFATs: db 0 ; Number of FATs (1 byte)
    BPB_FATSz32: dd 0 ; Size of each FAT in sectors (4 bytes)
    BPB_RootClus: dd 0 ; First cluster of the root directory (4 bytes)
    BPB_SecPerClus: db 0 ; Sectors per cluster (1 byte)
    BPB_RsvdSecCnt: dw 0 ; Reserved sectors count (2 bytes)
    BPB_BytsPerSec: dw 0 ; Bytes per sector in FAT32 system (2 bytes)

global UNREAL_PROTECTED_GDT_POINTER

UNREAL_PROTECTED_GDT:

    ; Null segment descriptor
    dq 0x0000000000000000

    ; Code Segment Descriptor (Base=0, Limit=4GB, Executable, Readable)
    dw 0xFFFF          ; Limit (bits 0-15)
    dw 0x0000          ; Base (bits 0-15)
    db 0x00            ; Base (bits 16-23)
    db 0x9A            ; Access Byte: Present, Ring 0, Executable, Readable
    db 0xCF            ; Flags (4-bit limit high + Granularity=4KB + 32-bit)
    db 0x00            ; Base (bits 24-31)

    ; Data Segment Descriptor (Base=0, Limit=4GB, Writable, Readable)
    dw 0xFFFF          ; Limit (bits 0-15)
    dw 0x0000          ; Base (bits 0-15)
    db 0x00            ; Base (bits 16-23)
    db 0x92            ; Access Byte: Present, Ring 0, Writable
    db 0xCF            ; Flags (4-bit limit high + Granularity=4KB + 32-bit)
    db 0x00            ; Base (bits 24-31)

UNREAL_PROTECTED_GDT_END:

UNREAL_PROTECTED_GDT_POINTER:
    dw UNREAL_PROTECTED_GDT_END - UNREAL_PROTECTED_GDT - 1
    dd UNREAL_PROTECTED_GDT
