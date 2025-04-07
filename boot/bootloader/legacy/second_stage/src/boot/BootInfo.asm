[BITS 16]

; This file will handle populating the boot info structure
; with the boot device, memory map, and VBE mode info

; This will be passed to the kernel
; as a pointer to the RGOS_INFO_STRUCT

%include "Output.inc"
%include "Error.inc"
%include "status_msgs.inc"
%include "Global.inc"
%include "VBE.inc"

section .text

; Detect boot device and store in the RGOS_INFO_STRUCT

global _detect_boot_media
_detect_boot_media:

    mov si, detect_boot_media_msg
    call _print_line

    mov ah, 0x00    ; Reset disk drive
    int 0x13        ; BIOS interrupt to reset disk drive
    jc _error       ; If carry flag is set, there was an error

    mov byte [rgos_bd], dl ; Store the boot device in boot info struct

    ret

; Populate the memory map in the RGOS_INFO_STRUCT
; Deliviers a map of memeory regions and their availibility

global _populate_mem_map
_populate_mem_map:
    mov si, mem_map_msg
    call _print_line

    ; mem map function ref http://www.uruk.org/orig-grub/mem64mb.html
    
    push es
    mov ax, stage2_loaded_segment ; ES:DI is buffer to store
    mov es, ax
    
    lea di, [RGOS_MEM_MAP] ; Load the address of the memory map into DI

    mov ebx, 0 ; Continuation, initlized to 0

    _mep_map_loop: 

        ; Call BIOS to get memory map
        mov eax, 0xE820 ; E820h is the BIOS function to get memory map
        mov ecx, 24
        mov edx, 0x534D4150 ; Signature
        int 0x15 ; Call BIOS to get memory map

        jc _mem_map_error ; If carry flag is set, there was an error

        cmp eax, 0x534D4150
        jne _mem_map_error ; If the signature is not "SMAP", there was an error

        mov word es:[di + 10], 1 ; Set ACPI 3.0 Extended Attributes bit 1, ignore entry if clear

        cmp ebx, 0 ; Check if we have reached the end of the memory map
        je _mem_map_finished

        add di, 24 ; Move to the next entry

        jmp _mep_map_loop ; Loop until we get all the memory map entries
    

_mem_map_finished:
    pop es
    
    mov si, mem_map_done_msg
    call _print_line

    ret

_mem_map_error:
    pop es

    mov si, mem_map_err_msg
    call _print_line

    call _error


; Initilizes and populates the VBE info sections of the boot info
; This will be used by the kernel for drawing grpahics

global _init_vbe
_init_vbe:

    mov si, vbe_init_msg
    call _print_line

    ; Call VBE function to get controller info
    call _vbe_get_controller_info

    ; Finds a suitable VBE mode and sets it
    call _vbe_find_suitable_mode

    ; Put mode info into es:di
    push es
    mov ax, stage2_loaded_segment ; ES:DI is buffer to store
    mov es, ax
    mov di, RGOS_VBE_MODE_INFO ; Load the address of the VBE mode info into DI
    call _populate_vbe_mode_info_buffer
    pop es
    
    ret


section .data

detect_boot_media_msg: db "Detecting boot media...", 0

mem_map_msg: db "Populating memory map...", 0
mem_map_err_msg: db "Error populating memory map", 0
mem_map_done_msg: db "Memory map populated!", 0

vbe_init_msg: db "Initializing VBE...", 0

global RGOS_INFO_STRUCT, rgos_bd

RGOS_INFO_STRUCT:
    ; The info struct that will be passed to the kernel
    rgos_bd: db 0x00 ; Boot device (1 byte)
    rgos_mem_map_addr: dd RGOS_MEM_MAP ; Memory map addr
    rgos_mem_map_size: dd RGOS_MEM_MAP_END - RGOS_MEM_MAP ; Size of the memory map (4 bytes)
    rgos_vbe_modeinfo_addr: dd RGOS_VBE_MODE_INFO ; VBE mode info addr
    rgos_vbe_modeinfo_size: dd RGOS_VBE_MODE_INFO_END - RGOS_VBE_MODE_INFO ; Size of the VBE mode info (4 bytes) 

section .bss

RGOS_MEM_MAP:
    resb 0x1000 ; Memory map (4KB)
    RGOS_MEM_MAP_END:

global RGOS_VBE_MODE_INFO
RGOS_VBE_MODE_INFO:
    resb 256 ; VBE mode info (4KB)
    RGOS_VBE_MODE_INFO_END:
