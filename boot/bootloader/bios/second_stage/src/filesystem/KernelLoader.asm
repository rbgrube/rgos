[BITS 16]

%include "status_msgs.inc"
%include "Output.inc"
%include "Error.inc"
%include "FAT32.inc"
%include "BPB.inc"
%include "Global.inc"
%include "ModeSwitch.inc"

section .text

global _locate_kernel
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

        cmp eax, ecx
        je _found_kernel
        
        pop es

        add bx, 0x20 ; Increment entry 32 bytes
        cmp bx, 0x200 ; if goes over sector

        jge _locate_kernel_search_sector_over

        jmp _locate_kernel_search_sector_loop


_locate_kernel_search_sector_over:
    ret

; es = segment of loaded root dir sector
; si = offset of loaded root dir sector
; bx = offset of entry in root dir sector
_found_kernel:

    push si
    mov si, found_kernel_msg
    call _print_line ; Print message indicating locating kernel
    pop si

    push dx
    mov dx, word es:[si + bx + 26] ; Low word of first cluster number of file
    mov word [kernel_first_cluster_num], dx
    mov dx, word es:[si + bx + 20] ; High word of first cluster number of file
    mov word [kernel_first_cluster_num + 2], dx
    pop dx

    mov byte [end_follow_early], 0x1 ; break early from cluster chain

    pop es ; Retsore es before returning bc of JMP

    ret

_locate_kernel_finished_root_chain:
    mov si, locate_kern_finish_chain_msg
    call _print_line

    call _error

    ret

section .data
kernel_target_name: dd "KERN" ; Example kernel target name to locate in the root directory
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