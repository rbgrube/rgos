; RGOS Second Stage Bootloader
; Ryan Grube
; March 29, 2025

[BITS 16]

;--NOTE--
; In real mode, any use of 32 bit registers is done using the Address Size Override Prefix, 
; which does not bypass the addressing limits of real mode
;--------

%include "status_msgs.inc"
%include "Output.inc"
%include "Error.inc"
%include "FAT32.inc"
%include "BPB.inc"
%include "BootInfo.inc"
%include "Global.inc"
%include "Partition.inc"
%include "ModeSwitch.inc"
%include "KernelLoader.inc"

; ORG 0x8000 set in linkerscript

section .main

global _stage2_start

_stage2_start:

    ; Since the second stage bootloader is now loaded at stage2_load_segment
    ; we need to set the segment registers to point to this address
    call _reset_real_segments

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

    call _load_kernel

    jmp $






