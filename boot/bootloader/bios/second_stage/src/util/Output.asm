[BITS 16]

global _print_line

section .text

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

section .data

newline: db 0x0d, 0x0a, 0
signiture: db "<RGOS Stage 2 Bootloader> ", 0