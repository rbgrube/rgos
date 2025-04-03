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

; ORG 0x8000 set in linkerscript

section .main

global _stage2_start

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

    call _load_kernel

    jmp $

section .text

; Initilize ds and es for second stage
_init_segments:

    ; ax should be same as stage2_load_segment from
    ; the stage one bootloader
    mov ax, stage2_loaded_segment

    mov ds, ax  ; Set data segment to stage2_load_segment
    mov es, ax  ; Set extra segment to stage2_load_segment

    ret ; Can use return, no modification to the stack


; Locate the kernel in the FAT32 root directory and store its cluster number in kenrel_cluster_num
_locate_kernel:
    mov si, locate_kern_msg
    call _print_line ; Print message indicating locating kernel

    mov esi, [BPB_RootClus]
    mov ax, _locate_kernel_cluster_modifier
    mov bx, _locate_kernel_finished_root_chain

    call _follow_FAT_cluster_chain

    ret

; Called on each cluster
; ESI = cluster num
_locate_kernel_cluster_modifier:

    mov esi, esi ; Cluster Num
    mov ax, _locate_kernel_search_sector
    call _read_FAT_cluster_sectors

    ret

; Called on each sector
; DX:SI is segment offset pointer to the first byte of the sector in memeory 
_locate_kernel_search_sector:

    mov bx, 0

    _locate_kernel_search_sector_loop:

        push es

        mov eax, dword [kernel_target_name]

        mov es, dx

        mov ecx, dword es:[si + bx] ; in FAT directory entry name offset is 0

        push dx
        mov dx, word es:[si + bx + 26] ; Low word of first cluster number of file
        mov word [kernel_first_cluster_num], dx
        mov dx, word es:[si + bx + 20] ; High word of first cluster number of file
        mov word [kernel_first_cluster_num + 2], dx
        pop dx

        pop es

        cmp eax, ecx

        je _found_kernel

        add bx, 0x20 ; Increment entry 32 bytes
        cmp bx, 0x200 ; if goes over sector

        jge _locate_kernel_search_sector_over

        jmp _locate_kernel_search_sector_loop


_locate_kernel_search_sector_over:
    ret

_found_kernel:
    ; dx contains segment
    mov si, found_kernel_msg
    call _print_line ; Print message indicating locating kernel


    mov byte [end_follow_early], 0x1 ; break early from cluster chain
    ret

_locate_kernel_finished_root_chain:
    mov si, locate_kern_finish_chain_msg
    call _print_line

    call _error

    ret

kernel_target_name: dd "KERN" ; Example kernel target name to locate in the root directory
kernel_first_cluster_num: dd 0 ; This will store the cluster number of the kernel if found

_load_kernel:
    mov si, loading_kernel_msg
    call _print_line

    ret





