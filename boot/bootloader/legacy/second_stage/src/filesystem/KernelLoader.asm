[BITS 16]

%include "status_msgs.inc"
%include "Output.inc"
%include "Error.inc"
%include "FAT32.inc"
%include "BPB.inc"
%include "Global.inc"
%include "BootInfo.inc"
%include "ModeSwitch.inc"

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
    break:

    ; now eax holds BOOT first cluster
    mov esi, eax ; BOOT directory first cluster
    mov ecx, "KERN" ; check for kernel

    call _find_in_FAT_dir
    jc _no_kern

    push es
    mov es, dx
    ; Stored low first for little endian of kernel_first_cluster_num
    mov ax, word es:[si + 26] ; First cluster low (byte 26)
    mov [kernel_first_cluster_num], ax
    mov ax, word es:[si + 20] ; First cluster high (byte 20)
    mov [kernel_first_cluster_num + 2], ax
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

section .data
kernel_first_cluster_num: dd 0 ; This will store the cluster number of the kernel if found

section .text

global _load_kernel

_load_kernel:
    mov si, loading_kernel_msg
    call _print_line

    mov esi, dword [kernel_first_cluster_num]
    mov ax, _kernel_cluster_proccess
    mov bx, _kernel_cluster_finished_chain
    call _follow_FAT_cluster_chain

    mov si, kernel_loaded_msg
    call _print_line

    mov eax, kernel_load_target_addr
    mov ebx, RGOS_INFO_STRUCT
    jmp _enter_protected_mode

    ret


; Called on each cluster
; ESI = cluster num
_kernel_cluster_proccess:

    mov esi, esi ; Cluster Num
    mov ax, _kernel_sector_process
    call _read_FAT_cluster_sectors

    ret


section .data

sectors_read: dd 0 ; Amount of sectors read

section .text

; Called on each sector
; DX:SI is segment offset pointer to the first byte of the sector in memory
_kernel_sector_process:

    call _enter_unreal  ; Enter unreal mode

    movzx edx, dx
    shl edx, 4 ; Multiply segment by 16
    movzx esi, si ; Set ESI to the offset of the first byte of the sector in memory
    add esi, edx

    mov ebx, 0 ; Amount of bytes copied

    copy_loop:

        ; Move byte to copy into al
        mov al, byte [esi + ebx]
        push ax

        ; Location to copy into
        mov ecx, kernel_load_target_addr
        add ecx, ebx ; Add byte offset to the target address
        
        mov eax, 0x200 ; 512 bytes per sector
        mul dword [sectors_read] ; Multiply the sector number by 512

        add ecx, eax ; Add the sector offset to the target address

        pop ax
        mov byte [ecx], al ; Copy the byte to the target address

        add ebx, 1 ; Increment the amount of bytes copied
        cmp ebx, 512 ; Check if we reached the end of the sector
        jge copy_finish ; If we reached the end of the sector, finish copying

        jmp copy_loop ; Continue copying 

    copy_finish:

    call _reset_real_segments ; Reset segment registers (back in fully real mode)

    mov eax, dword [sectors_read]
    add eax, 1
    mov dword [sectors_read], eax ; Increment the amount of sectors read

    ret

_kernel_cluster_finished_chain:

    ret

section .data

kernel_loaded_msg: db "Kernel successfully loaded!", 0
no_boot_dir_errmsg: db "No boot directory found!", 0
no_kern_errmsg: db "No kernel (KERN) file found in /boot/", 0