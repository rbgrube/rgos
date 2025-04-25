[BITS 16]

%include "status_msgs.inc"
%include "Output.inc"
%include "Error.inc"
%include "FAT32.inc"
%include "BPB.inc"
%include "Global.inc"
%include "BootInfo.inc"
%include "ModeSwitch.inc"
%include "ELF.inc"

section .text

global _locate_kernel
; Locate the kernel in the FAT32 root directory and store its cluster number in kenrel_cluster_num
_locate_kernel:

    mov esi, [BPB_RootClus]
    mov ecx, "BOOT"

    call _find_in_FAT_dir
    jc _no_boot_dir

    ; info returned 
    ; DX:SI pointer to 32 byte fat directory entry
    push es
    mov es, dx
    ; Stored high first into register eax
    mov ax, word es:[si + 20] ; First cluster high word (byte 20)
    shl eax, 16
    mov ax, word es:[si + 26] ; First cluster low word (byte 26)
    pop es

    ; now eax holds BOOT first cluster
    mov esi, eax ; BOOT directory first cluster
    mov ecx, "KERN" ; check for kernel

    call _find_in_FAT_dir
    jc _no_kern

    push es
    mov es, dx
    
    ; Stored low first for little endian of kernel_first_cluster_num
    mov ax, word es:[si + 26] ; First cluster low (byte 26)
    mov word [kernel_first_cluster_num], ax
    mov ax, word es:[si + 20] ; First cluster high (byte 20)
    mov word [kernel_first_cluster_num + 2], ax
    pop es
    
    ret

    _no_boot_dir:

        mov si, no_boot_dir_errmsg
        call _print_line

        call _error

    _no_kern:

        mov si, no_kern_errmsg
        call _print_line

        call _error


section .text

global _load_kernel

_load_kernel:
    mov si, loading_kernel_msg
    call _print_line

    mov eax, dword [kernel_first_cluster_num]

;;;;
    mov edx, 0
    mov ebx, 2
    mov esi, eax
    push es
    mov ax, 0x1000
    mov es, ax
    mov di, 0x400
    call _read_sectors_from_file

    break:

    pop es
;;;;;

    call _load_elf_file_from_cluster

    ret 


global _jump_to_kernel_entry
_jump_to_kernel_entry:
    ret

section .data

kernel_first_cluster_num: dd 0 ; This will store the cluster number of the kernel if found

loading_kernel_msg: db "Loading kernel into memeory...", 0
kernel_loaded_msg: db "Kernel successfully loaded!", 0
no_boot_dir_errmsg: db "No boot directory found!", 0
no_kern_errmsg: db "No kernel (KERN) file found in /boot/", 0