[BITS 16]

; Handle VBE functions
; https://pdos.csail.mit.edu/6.828/2004/readings/hardware/vbe3.pdf

%include "Output.inc"
%include "Error.inc"
%include "Global.inc"

section .text


global _vbe_get_controller_info
_vbe_get_controller_info:
    
    mov ax, 0x4F00 ; VBE function to get controller info

    push es

    mov dx, stage2_loaded_segment ; ES:DI is buffer to store
    mov es, dx

    mov di, VBE_INFO_BLOCK ; Address of the VBE info block

    int 0x10 ; Call VBE function

    pop es

    cmp al, 0x4f ; Check if VBE function is supported
    jne _vbe_get_controller_unsupported

    cmp ah, 0 ; Check if VBE function was successful
    jne _vbe_get_controller_error

    ret

_vbe_get_controller_error:
    mov si, vbe_get_controller_unsupported_msg
    call _print_line
    
    call _error

    ret

_vbe_get_controller_unsupported:

    mov si, vbe_get_controller_unsupported_msg
    call _print_line
    
    call _error

    ret


section .bss
target_mode: resw 1 ; Target mode to switch to
section .text
global _vbe_find_suitable_mode

_vbe_find_suitable_mode:
    mov si, vbe_find_suitable_mode_msg
    call _print_line

    mov bx, 0 ; inc for each mode number in list
    mov di, word [VBE_INFO_BLOCK + 0x0E] ; Video mode ptr offset
    push es
    mov dx, word [VBE_INFO_BLOCK + 0x0E + 2] ; Video mode ptr segment
    mov es, dx

    _mode_list_loop:

        mov ax, word es:[di + bx]
        add bx, 2 ; Increment to next mode number

        cmp ax, 0xFFFF ; end of mode list
        je _mode_list_finished ; If we reached the end of the mode list, exit

        ; Now ax has mode number for each mode

        ; Populate mdoe info block by using get mode info VBE function
        push es
        push di

        mov dx, stage2_loaded_segment ; ES:DI is buffer to store
        mov es, dx
        mov di, MODE_INFO_BLOCK ; Address of the VBE mode info block

        mov cx, ax ;  mode number in cx
        push cx
        mov ax, 0x4F01 ; VBE function to get mode info

        int 0x10 ; Call VBE function

        pop cx
        pop di
        pop es

        cmp al, 0x4f ; Check if VBE function is supported
        jne _vbe_get_modeinfo_unsupported

        cmp ah, 0 ; Check if VBE function is supported
        jne _vbe_get_modeinfo_error

        ; Check if the mode meets our requirements
        call check_mode_criteria
        cmp ax, 1 ; Check if the mode meets our requirements
        je _found_suitable_mode

        ; end of mode info func
        jmp _mode_list_loop ; Loop until we get all the mode numbers

    _vbe_get_modeinfo_unsupported:
    _vbe_get_modeinfo_error:
        ;mov si, vbe_get_mode_errmsg
        ;call _print_line 
        
        jmp _mode_list_loop

    _found_suitable_mode:
        mov si, vbe_suitable_mode_found_msg
        call _print_line

        mov word [target_mode], cx ; Store the mode number in target_mode
        jmp _mode_list_finished

    _mode_list_finished:

    pop es

    ; Now we have the target mode number in target_mode
    ; Set mode 

    mov ax, 0x4F02 ; VBE function to set mode
    mov bx, word [target_mode] ; Mode number in bx
    int 10h ; Call VBE function

    cmp al, 0x4f ; Check if VBE function is supported
    jne _vbe_set_mode_unsupported
    cmp ah, 0 ; Check if VBE function was successful
    jne _vbe_set_mode_error

    mov si, vbe_suitable_mode_set_msg
    call _print_line
    ret

_vbe_set_mode_unsupported:
    mov si, vbe_set_mode_unsupported_msg
    call _print_line
    
    call _error

    ret
_vbe_set_mode_error:
    mov si, vbe_set_mode_errmsg
    call _print_line
    
    call _error

    ret

; Returns 1 in ax if mode meets requirements
; Returns 0 in ax if mode does not meet requirements
check_mode_criteria:

    mov al, byte [MODE_INFO_BLOCK] ; Mode Attributes
    test al, 0x10 ; Test bit 4 of attributes
    jz check_mode_bad ; If not set, text mode, not suitable

    cmp word [MODE_INFO_BLOCK + 0x12], min_vbe_xres ; Xresolution
    jl check_mode_bad ; If less than min_vbe_xres, not suitable

    cmp word [MODE_INFO_BLOCK + 0x14], min_vbe_yres ; Xresolution
    jl check_mode_bad ; If less than min_vbe_yres, not suitable

    cmp byte [MODE_INFO_BLOCK + 0x19], vbe_bbp_pref ; Bits per pixel
    jne check_mode_bad ; If not vbe_bbp_pref, not suitable

    mov ax, 1   ; Suitable
    ret

check_mode_bad:
    xor ax, ax ; Set ax to 0
    ret

global _populate_vbe_mode_info_buffer
; Populates es:di with the VBE mode info block
_populate_vbe_mode_info_buffer:

    mov cx, word [target_mode] ; mode number in cx
    mov ax, 0x4F01 ; VBE function to get mode info    
    int 0x10 ; Call VBE function

    cmp al, 0x4f ; Check if VBE function is supported
    jne _vbe_pop_modeinfo_unsupported
    cmp ah, 0 ; Check if VBE function was successful
    jne _vbe_pop_modeinfo_error

    ret

_vbe_pop_modeinfo_unsupported:
    mov si, vbe_get_mode_errmsg
    call _print_line
    
    call _error

    ret

_vbe_pop_modeinfo_error:
    mov si, vbe_pop_modeinfo_error_msg
    call _print_line
    
    call _error

    ret

section .data
vbe_get_controller_unsupported_msg: db "Get controller VBE function not supported!", 0
vbe_get_controller_error_msg: db "Error during get controller VBE function!", 0
vbe_get_mode_errmsg: db "Error or unsupported during get mode VBE function!", 0
vbe_find_suitable_mode_msg: db "Finding suitable VBE mode...", 0
vbe_suitable_mode_found_msg: db "Suitable VBE mode found!", 0
vbe_set_mode_errmsg: db "Couldn't set VBE mode!", 0
vbe_set_mode_unsupported_msg: db "Set VBE mode function not supported!", 0
vbe_pop_modeinfo_error_msg: db "Couldn't populate VBE info!", 0
vbe_suitable_mode_set_msg: db "VBE mode set!", 0

section .bss

VBE_INFO_BLOCK:
    resb 512 ; VBE info block (512 bytes)

MODE_INFO_BLOCK:
    resb 256 ; VBE mode info block (512 bytes)