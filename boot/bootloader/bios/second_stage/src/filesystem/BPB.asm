[BITS 16]

%include "status_msgs.inc"
%include "Global.inc"
%include "Output.inc"
%include "Disk.inc"
%include "Partition.inc"
%include "Error.inc"

; Offsets from the FAT32 boot sector for paramters in the BIOS Parameter Block (BPB)
%define BPB_NumFATs_offset 16 ; Offset for Number of FATs in the BIOS Parameter Block (BPB)
%define BPB_FATSz32_offset 36 ; Offset for Size of each FAT in sectors in the BIOS Parameter Block (BPB)
%define BPB_RootClus_offset 44 ; Offset for First cluster of the root directory in the BIOS Parameter Block (BPB)
%define BPB_SecPerClus_offset 13 ; Offset for Sectors per cluster in the BIOS Parameter Block (BPB)
%define BPB_RsvdSecCnt_offset 14 ; Offset for Reserved sectors count in the BIOS Parameter Block (BPB)
%define BPB_BytsPerSec_offset 11 ; Offset for bytes per sector in the BIOS Parameter Block (BPB)

section .text

; Load the FAT32 boot sector into memory

global _load_FAT32_boot_sector

_load_FAT32_boot_sector:

    mov si, read_FAT32_boot_msg
    call _print_line

    mov eax, dword [fat_partition_start_lba]  ; EAX = Low dword of LBA to read from
    mov edx, 0                          ; EDX = High dword of LBA to read from
                        
    mov bx, FAT_boot_loading_segment    ; BX:DI = Memory location to store data in
    mov di, FAT_boot_loading_offset
    
    call _read_sector ; Read FAT32 boot sector from disk into memeory

    mov si, read_FAT32_boot_successmsg
    call _print_line ; Print success message

    break:
    ; TODO Check validity of the FAT32 boot sector (0xAA55, 512 bytes per sector, and )
    ret

_load_FAT32_boot_sector_err:
    ; Error reading FAT32 boot sector
    mov si, read_FAT32_boot_errmsg
    call _print_line

    call _error ; Call error handler


global _populate_BPB_info

; Populate BPB info table for later use

_populate_BPB_info:

    mov si, load_BPB_info_msg
    call _print_line ; Print message indicating populating BPB info

    push es
    mov ax, FAT_boot_loading_segment ; Segment where FAT32 boot sector is loaded
    mov es, ax ; Set data segment to FAT32 boot sector segment

    ; Set BPB_NumFATs
    mov al, es:[FAT_boot_loading_offset + BPB_NumFATs_offset]
    mov byte [BPB_NumFATs], al

    ; Set BPB_FATSz32
    mov eax, es:[FAT_boot_loading_offset + BPB_FATSz32_offset]
    mov dword [BPB_FATSz32], eax

    ; Set BPB_RootClus lower
    mov eax, es:[FAT_boot_loading_offset + BPB_RootClus_offset]
    mov dword [BPB_RootClus], eax

    ; Set BPB_SecPerClus
    mov al, es:[FAT_boot_loading_offset + BPB_SecPerClus_offset]
    mov byte [BPB_SecPerClus], al

    ; Set BPB_RsvdSecCnt
    mov ax, es:[FAT_boot_loading_offset + BPB_RsvdSecCnt_offset]
    mov word [BPB_RsvdSecCnt], ax

    ; Set BPB_RsvdSecCnt
    mov ax, es:[FAT_boot_loading_offset + BPB_BytsPerSec_offset]
    mov word [BPB_BytsPerSec], ax

    pop es

    ret




