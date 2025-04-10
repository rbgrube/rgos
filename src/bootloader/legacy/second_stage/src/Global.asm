[BITS 16]


section .data

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

