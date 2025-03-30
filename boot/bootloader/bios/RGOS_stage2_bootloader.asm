; RGOS Second Stage Bootloader
; Ryan Grube
; March 29, 2025

[BITS 16]

; Start in real mode

;--NOTE--
; In real mode, any use of 32 bit registers is done using the Address Size Override Prefix, 
; which does not bypass the addressing limits of real mode
;--------

%ifdef RAW_BINARY    
[ORG 0x8000] ; Stage 2 bootloader loaded at 0x8000 by stage 1
%endif

%define stage1_segment 0x0000 ; Segment where stage 1 bootloader is loaded
%define stage1_offset 0x7C00 ; Offset where stage 1 bootloader is loaded
%define stage2_loaded_segment 0x0000 ;  Segment where stage 2 bootloader is loaded

%define part_table_offset 0x7c00 + 0x1BE ; Offset for the partition table from the MBR

%define FAT_boot_loading_segment 0x1000 ; Segment where FAT32 boot sector will be loaded
%define FAT_boot_loading_offset 0x0000 ; Offset where FAT32 boot sector will be loaded

_stage2_start:


    ; Since the second stage bootloader is now loaded at stage2_load_segment
    ; we need to set the segment registers to point to this address
    call _init_segments

    mov si, startmsg
    call _print_line 

    ; Detect boot deivce and store in info structure
    call _handle_boot_device

    ; Find a fat32 partition and store its starting LBA in FAT_partition_info
    call _read_partiton_table

    ; Load fat32 boot sector into memory
    call _load_FAT32_boot_sector

    ; Populate the BIOS Parameter Block (BPB) info from the FAT32 boot sector
    call _populate_BPB_info 

    ; Locate the kernel on the FAT32 partition 
    call _locate_kernel 
    
    jmp $

; Initilize ds and es for second stage
_init_segments:

    ; ax should be same as stage2_load_segment from
    ; the stage one bootloader
    mov ax, stage2_loaded_segment

    mov ds, ax  ; Set data segment to stage2_load_segment
    mov es, ax  ; Set extra segment to stage2_load_segment

    ret ; Can use return, no modification to the stack

; Detect boot device and store in the RGOS_INFO_STRUCT
_handle_boot_device:
    mov si, boot_device_msg
    call _print_line

    mov ah, 0x00    ; Reset disk drive
    int 0x13        ; BIOS interrupt to reset disk drive
    jc _error       ; If carry flag is set, there was an error

    mov byte [rgos_bd], dl ; Store the boot device in boot info struct

    ret

; Read partition table and locate fat32 partition
_read_partiton_table:

    mov si, read_partition_table_msg
    call _print_line

    ; Traverse the partition table

    mov bx, part_table_offset ; Offset for the partition table in the MBR
    mov si, 0 ; offset of entry from partition table

    push ds ; preserve data segment since reading from segment 0x0000
    mov ax, stage1_segment
    mov ds, ax

_read_partiton_table_loop:
    ; Read each partition entry

    cmp byte [bx + si + 0x04], 0x0B  ; Check if partition type (0x04 offset in entry) is FAT32 (0x0b or 0x0c)
    je _found_partition         ; If FAT32, jump to found partition
    cmp byte [bx + si + 0x04], 0x0C
    je _found_partition


    add si, 0x10 ; Add 16 to offset (move to next entry)

    cmp si, 0x40 ; Check if we've read all 4 entries (4 * 16 = 64 bytes)
    jg _no_partition_found; If bx > 64, no partitooin, looped through all entries

    jmp _read_partiton_table_loop ; Continue loop until all entries are checked

_found_partition:
    pop ds ; Restore the original data segment  

    mov eax, [bx + si + 0x08] ; Get the starting LBA of the partition (0x08 offset in entry)
    mov dword [FAT_starting_lba], eax

    ; Found a FAT32 partition
    mov si, found_partition_msg
    call _print_line 

    ret ; Return to caller, FAT32 partition found

_no_partition_found:
    pop ds ; Restore the original data segment

    ; Did not find a FAT32 partition
    mov si, no_part_errmsg
    call _print_line 

    call _error

; Load the FAT32 boot sector into memory
_load_FAT32_boot_sector:

    mov si, read_FAT32_boot_msg
    call _print_line

    mov ah, 0x42            ; BIOS function for extended read sectors
    mov dl, [rgos_bd]       ; dl is the device to read from (boot drive)
    mov si, FAT32_BOOT_SECTOR_DAP ; A disk address packet (DAP) that describes what to read and where
    int 0x13                ; Call BIOS to read sectors

    jc _load_FAT32_boot_sector_err     ; Error if carry is set

    mov si, read_FAT32_boot_successmsg
    call _print_line ; Print success message

    ; TODO Check validity of the FAT32 boot sector (0xAA55, 512 bytes per sector, and )
    ret

_load_FAT32_boot_sector_err:
    ; Error reading FAT32 boot sector
    mov si, read_FAT32_boot_errmsg
    call _print_line

    call _error ; Call error handler

FAT32_BOOT_SECTOR_DAP:
    db 0x10                     ; Size of DAP
    db 0                        ; Unused
    dw 0x01                     ; How many sectors to read
    dw FAT_boot_loading_offset  ; 4 byte segment:offset pointer for where to write bytes in memeory
    dw FAT_boot_loading_segment ; Offset first since this is little endian
    FAT_starting_lba: 
    dd 0      ; Sector to start at, quad word, but only first double will be filled
    dd 0 
    

; Populate BPB info table for later use
_populate_BPB_info:

    ; Offsets from the FAT32 boot sector for paramters in the BIOS Parameter Block (BPB)
    %define BPB_NumFATs_offset 16 ; Offset for Number of FATs in the BIOS Parameter Block (BPB)
    %define BPB_FATSz32_offset 36 ; Offset for Size of each FAT in sectors in the BIOS Parameter Block (BPB)
    %define BPB_RootClus_offset 44 ; Offset for First cluster of the root directory in the BIOS Parameter Block (BPB)
    %define BPB_SecPerClus_offset 13 ; Offset for Sectors per cluster in the BIOS Parameter Block (BPB)
    %define BPB_RsvdSecCnt_offset 14 ; Offset for Reserved sectors count in the BIOS Parameter Block (BPB)

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

    pop es

    ; Calculated values

    ; Root dir start in sectors
    ; BPB_RsvdSecCnt + ((BPB_RootClus - 2) * BPB_SecPerClus)


    ret

BPB_info:
    ; BPB info from the FAT32 boot sector
    BPB_NumFATs: db 0 ; Number of FATs (1 byte)
    BPB_FATSz32: dd 0 ; Size of each FAT in sectors (4 bytes)
    BPB_RootClus: dd 0 ; First cluster of the root directory (4 bytes)
    BPB_SecPerClus: db 0 ; Sectors per cluster (1 byte)
    BPB_RsvdSecCnt: dw 0 ; Reserved sectors count (2 bytes)
    ; Calculated values used in the bootloader
    FAT_root_dir_start: dq 0 ; Start of the root directory in sectors (calculated)
    FAT_lba: dq 0 ; Logical block address of the FAT tables (calculated)

_locate_kernel:
    ret

; The info struct that will be passed to the kernel
RGOS_INFO_STRUCT:
    rgos_bd: db 0x00 ; Boot device (1 byte)

; Prints a line to the screen using BIOS text mode
_print_line:

    push si
    mov si, signiture
    call _print_loop

    pop si
    call _print_loop

    
    mov si, newline
    call _print_loop

    ret

_print_loop:

    lodsb
    or al, al
    jz _print_return

    mov ah, 0x0e
    int 0x10
    jmp _print_loop

_print_return:
    ret

_error:
    mov si, error_msg
    call _print_line

    cli
    hlt

    jmp $

newline: db 0x0d, 0x0a, 0
signiture: db "<RGOS Stage 2 Bootloader> ", 0
error_msg: db "Error!", 0

startmsg: db "Initiated segment registers, executing...", 0

boot_device_msg: db "Identifying boot device...", 0

read_partition_table_msg: db "Reading partition table...", 0
found_partition_msg: db "Found FAT32 partition in partition table!", 0
no_part_errmsg: db "Couldn't find FAT32 partition in partition table!", 0

read_FAT32_boot_msg: db "Loading FAT32 boot sector into memory...", 0
read_FAT32_boot_successmsg: db "FAT32 boot sector loaded!", 0
read_FAT32_boot_errmsg: db "Couldn't read FAT32 boot sector into memory!", 0

load_BPB_info_msg: db "Reading BPB info from FAT32 boot sector...", 0
