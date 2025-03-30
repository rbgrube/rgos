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

%define FAT_table_loading_segment 0x1000 ; Segment where FAT32 boot sector will be loaded
%define FAT_table_loading_offset 0x0300 ; Offset where FAT32 boot sector will be loaded

%define FAT_rootdir_reading_segment 0x1000 ; Segment where FAT32 boot sector will be loaded
%define FAT_rootdir_reading_offset 0x0200 ; Offset where FAT32 boot sector will be loaded


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
    %define BPB_BytsPerSec_offset 11 ; Offset for bytes per sector in the BIOS Parameter Block (BPB)

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

; Takes cluster number in eax and calculates the logical block address (LBA) for that cluster
; Stores lba back in eax
_calc_cluster_lba:

    ; BPB_RsvdSecCnt + (BPB_NumFATs * BPB_FATSz32) + ((CLUSTER_NUM - 2) * BPB_SecPerClus)

    push eax ; CLUSTER_NUM

    ; Accumulator

    movzx ecx, word [BPB_RsvdSecCnt] ; Value will be finally stored in edx for calculation

    ; Multiply FATs

    movzx eax, byte [BPB_NumFATs] ; Number of FATs
    mov   ebx, dword [BPB_FATSz32] ; Size of each FAT in sectors
    mul   ebx ; Multiply by size of each FAT in sectors to get total sectors for all FATs - stored in edx:eax

    add ecx, eax

    ; Get cluster offsert in sectors

    pop eax ; CLUSTER_NUM
    sub eax, 2 ; Clusters are indexed at 2

    movzx ebx, byte [BPB_SecPerClus] ; Sectors per cluster

    mul ebx ; Multiply by sectors per cluster to get total sectors for clusters

    add ecx, eax ; Add the reserved sectors count to the total sectors for FATs

    ; Final value now in eax

    mov dword eax, ecx ; Store the calculated root directory start in sectors
    
    ret

; Takes cluster number in esi and reads the next cluster from the FAT table
; Returns next cluster num back in esi
; End of cluster chain, returns 0xFFFFFFFF in esi
_read_FAT_next_cluster:
    ; Read the FAT entry for the current cluster in ESI

    ; First find out which sector its in 
    ; (Cluster Number * 4) = Bytes count of the next cluster number in the FAT table (each entry 4 bytes)
    ; So divde by bytes per sector to get setcor number
    ; Sector = Reserved Sectors + (Cluster Number * 4) / (bytes per sector)
    
    mov eax, esi ; Cluster number
    shl eax, 2 ; Multiply by 4 to get the byte offset in the FAT table for the cluster number

    ; Now divide by bytes per sector to get the sector number
    xor edx, edx ; Clear EDX before division, since we will be dividing EAX by a 16 bit value
    movzx ebx, word [BPB_BytsPerSec]
    div ebx ; divde edx:eax by ebx 

    ; NOTE: edx also now has the remainder of this division, or the modulo, which will be uysed later
    push edx ; Save EDX for later use, since we will need it after division

    ; EAX now has the sector number (relative to begining of FAT tables) in it, and EDX has the remainder
    movzx ecx, word [BPB_RsvdSecCnt]
    add eax, ecx ; Add reserved sectors count to get the actual sector number from begining of PARTITION

    ; EAX now has the sector number to read from relative to begnging of PARTITIOn
    ; add the FAT table offset from the begning of the DISK, not just the partition
    
    mov ebx, dword [FAT_starting_lba] 
    add eax, ebx 
    mov edx, 0 ; Clear carry
    adc edx, 0 ; Handle carry from addition, if any

    ; Now EDX:EAX has the absolute sector number to read from
    mov [FAT_TABLE_READ_SECTOR], eax ; Store the sector number to read in FAT_TABLE_READ_SECTOR
    mov [FAT_TABLE_READ_SECTOR + 4], edx 

    ; Now read the sector from the FAT table
    mov eax, 0 ; Clear EAX before reading, since we will be using it 
    mov esi, 0 ; Clear ESI before reading, since we will be using it 

    mov ah, 0x42            ; BIOS function for extended read sectors
    mov dl, [rgos_bd]       ; dl is the device to read from (boot drive)
    mov si, READ_FAT_TABLE_DAP ; A disk address packet (DAP) that describes what to read and where
    int 0x13                ; Call BIOS to read sectors

    ; Now the sector that we need to read is in FAT_table_loading_segment:FAT_table_loading_offset
    jc _read_FAT_next_cluster_err ; If carry is set, there was an error reading the FAT table

    ; Now read the next cluster number from the FAT table
    ; We need the next cluster number address offset within the sectopr we are reading 
    ; (Cluster Number * 4) % bytes per sector 

    pop edx
    ; EDX still has remainder of the division from before, which is the offset within the sector to read

    ; So now [FAT_table_loading_segment:FAT_table_loading_offset + edx] is a double word with the next cluster number
    push es ; Preserve ES since we are going to access memory
    mov ax, FAT_table_loading_segment
    mov es, ax ; Set ES to the segment where the FAT table was loaded
    mov eax, es:[FAT_table_loading_offset + edx] ; Read the next cluster number from the FAT table
    pop es ; Restore ES

    ; EAX now has the next cluster number
    cmp eax, 0x0FFFFFF7 
    jg _read_FAT_next_cluster_EOF
    
    ret 

_read_FAT_next_cluster_EOF:
    mov esi, 0xFFFFFFFF ; End of cluster chain, set ESI to 0xFFFFFFFF to indicate end of chain

    ret

_read_FAT_next_cluster_err:
    mov si, read_fat_table_sector_eemsg
    call _print_line ; Print error message for reading FAT table sector

    call _error ; Call error handler if we couldn't read the FAT table

READ_FAT_TABLE_DAP:
    db 0x10                     ; Size of DAP
    db 0                        ; Unused
    dw 0x01                     ; How many sectors to read
    dw FAT_table_loading_offset  ; 4 byte segment:offset pointer for where to write bytes in memeory
    dw FAT_table_loading_segment ; Offset first since this is little endian
    FAT_TABLE_READ_SECTOR: 
    dd 0      ; Sector to start at, quad word, but only first double will be filled
    dd 0 

BPB_info:
    ; BPB info from the FAT32 boot sector
    BPB_NumFATs: db 0 ; Number of FATs (1 byte)
    BPB_FATSz32: dd 0 ; Size of each FAT in sectors (4 bytes)
    BPB_RootClus: dd 0 ; First cluster of the root directory (4 bytes)
    BPB_SecPerClus: db 0 ; Sectors per cluster (1 byte)
    BPB_RsvdSecCnt: dw 0 ; Reserved sectors count (2 bytes)
    BPB_BytsPerSec: dw 0 ; Bytes per sector in FAT32 system (2 bytes)

; Locate the kernel in the FAT32 root directory and store its cluster number in kenrel_cluster_num
_locate_kernel:
    mov si, locate_kern_msg
    call _print_line ; Print message indicating locating kernel

    call _follow_root_dir_chain

    ; After following the root directory chain, check if kernel was found
    cmp dword [kernel_cluster_num], 0
    je _locate_kernel_not_found ; If kernel cluster number is 0, it means kernel was not found

    mov si, kernel_found_msg
    call _print_line ; Print message indicating kernel was found

    ret

_locate_kernel_not_found:
    mov si, locate_kernel_notfound_msg
    call _print_line ; Print message indicating kernel was not found in the FAT32 root directory

    call _error ; Call error handler if kernel was not found

kernel_target_name: dd "KERN" ; Example kernel target name to locate in the root directory
kernel_cluster_num: dd 0 ; This will store the cluster number of the kernel if found

; Follow the FAT32 root dir cluster chain
_follow_root_dir_chain:

    mov esi, [BPB_RootClus] ; ESI will be used to track the current cluster number

_follow_root_dir_loop:

    ; Read cluster
    mov eax, esi ; EAX now has the current cluster number
    call _calc_cluster_lba ; Calculate the logical block address (LBA) for the current cluster

    push eax ; Preserve EAX - Cluster LBA
    push esi ; Preserve ESI - Cluster number

    call read_root_dir_cluster_sectors_init

    pop eax ; Restore EAX - Cluster LBA
    pop esi ; Restore ESI - Cluster number

    cmp dword [kernel_cluster_num], 0
    jne _follow_root_dir_finished ; If kernel was found in the previous cluster, exit loop

    call _read_FAT_next_cluster

    ; Check if we reached the end of the cluster chain
    cmp esi, 0xFFFFFFFF
    je _follow_root_dir_finished ; If ESI is 0xFFFFFFFF, we reached the end of the chain
    
    jmp _follow_root_dir_loop

read_root_dir_cluster_sectors_init:

    mov ebx, 0 ; Sectors read from the current cluster

read_root_dir_cluster_sectors_loop:
        ; Read the sectors for the current cluster
        
        add eax, ebx ; Add the number of sectors read so far to the current LBA
        mov dword [root_dir_cluster_sectors_start], eax ; Set the starting sector for the read operation
        
        mov eax, 0
        mov esi, 0

        mov ah, 0x42            ; BIOS function for extended read sectors
        mov dl, [rgos_bd]       ; dl is the device to read from (boot drive)
        mov si, root_dir_cluster_sectors_DAP ; A disk address packet (DAP) that describes what to read and where
        int 0x13                ; Call BIOS to read sectors

        jc _read_rootdir_sectors_err ; If carry is set, there was an error reading the sector

        push eax ; Preserve EAX for later use
        push ebx ; Preserve EBX to track the number of sectors read
        call read_root_dir_cluster_entries_loop_init ; Call to process entries in the root directory for the current sector
        pop ebx ; Preserve EBX to track the number of sectors read
        pop eax ; Restore EAX after processing entries

        add ebx, 1 ; Increment the number of sectors read
        cmp ebx, [BPB_SecPerClus] ; Check if we've read all sectors for this cluster
        jl read_root_dir_cluster_sectors_loop ; If not, continue reading the next sector

        ret

root_dir_cluster_sectors_DAP:
    db 0x10                     ; Size of DAP
    db 0                        ; Unused
    dw 0x01                     ; How many sectors to read
    dw FAT_rootdir_reading_offset   ; 4 byte segment:offset pointer for where to write bytes in memory (to be filled in)
    dw FAT_rootdir_reading_segment  ; Offset first since this is little endian 
    root_dir_cluster_sectors_start: 
    dd 0      ; Sector to start at, quad word, but only first double will be filled
    dd 0

read_root_dir_cluster_entries_loop_init:

    mov esi, 0 ; Esi = bytes read from the sector

read_root_dir_cluster_entries_loop:

    push es
    mov ax, FAT_rootdir_reading_segment ; Set ES to the segment where the root directory is loaded
    mov es, ax ; Set ES to the segment where the root directory is loade
    mov eax, dword [kernel_target_name] ; Assuming kernel_target_name is a string to match against
    cmp dword es:[FAT_rootdir_reading_offset + esi], eax ; Compare with the current entry in the root directory
    pop es ; Restore ES after checking the entry

    call set_kernel_cluster ; If it matches, we found the kernel
    
    add esi, 0x20 ; Move to the next entry in the root directory (32 bytes per entry
    cmp esi, 0x200 ; Check if we've processed all entries in the sector (32 bytes per entry)
    jl read_root_dir_cluster_entries_loop ; If not, continue processing the next entr

    ret 
set_kernel_cluster:
    mov ax, word es:[FAT_rootdir_reading_offset + esi + 26]  ; Low word cluster numebr in directory entry
    mov [kernel_cluster_num], ax
    mov ax, word es:[FAT_rootdir_reading_offset + esi + 20]  ; High word cluster numebr in directory entry
    mov [kernel_cluster_num + 2], ax

    ret
    ; 

_read_rootdir_sectors_err:
    ; Error reading root directory sectors
    mov si, read_rootdir_sectors_errmsg
    call _print_line ; Print error message for reading root directory sectors

    call _error ; Call error handler if we couldn't read the root directory sectors

_follow_root_dir_finished:
    mov si, root_dir_finished_msg
    call _print_line ; Print message indicating finished following root directory chain

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

read_fat_table_sector_eemsg: db "Error reading FAT table sector!", 0

locate_kern_msg: db "Locating kernel in FAT32 root directory...", 0

root_dir_finished_msg: db "Finished following root directory chain.", 0
read_rootdir_sectors_errmsg: db "Error reading root directory sectors!", 0

kernel_found_msg: db "Kernel found in FAT32 root directory!", 0
locate_kernel_notfound_msg: db "No kernel found in FAT32 root directory (filename must start with KERN)", 0