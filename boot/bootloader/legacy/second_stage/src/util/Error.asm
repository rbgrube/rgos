[BITS 16]

%include "Output.inc"

global _error
_error:
    mov si, error_msg
    call _print_line

    cli
    hlt

    jmp $

section .data

error_msg: db "Error!", 0