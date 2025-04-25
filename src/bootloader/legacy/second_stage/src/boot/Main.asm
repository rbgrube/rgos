; RGOS Second Stage Bootloader
; Ryan Grube
; March 29, 2025

[BITS 16]

%include "Output.inc"
%include "Error.inc"
%include "FAT32.inc"
%include "BPB.inc"
%include "BootInfo.inc"
%include "Global.inc"
%include "Partition.inc"
%include "ModeSwitch.inc"
%include "KernelLoader.inc"

section .main

global _stage2_start

_stage2_start:

    ; Since the second stage bootloader is now loaded at stage2_load_segment
    ; We need to set the segment registers to point to this address
    call _reset_real_segments

    mov si, startmsg
    call _print_line 

    ; Detect boot deivce and store in RGOS boot info structure
    call _detect_boot_media

    ; Find the first fat32 partition and store its starting LBA in FAT_partition_info
    call _read_partiton_table

    ; Load fat32 boot sector into memory
    call _load_FAT32_boot_sector

    ; Populate the BIOS Parameter Block (BPB) info from the FAT32 boot sector
    call _populate_BPB_info 
    
    ; Locate the kernel on the FAT32 partition 
    call _locate_kernel 

    ; Give the boot info a memeory map
    call _populate_mem_map

    call _load_kernel

    call _init_vbe

    call _jump_to_kernel_entry


    jmp $



section .data
startmsg: db "Executing...", 0