[BITS 16]

%include "Global.inc"
%include "status_msgs.inc"
%include "Output.inc"

section .text

global _enter_unreal

; Callback address passed in ax
; Must be jumped to, not called
_enter_unreal:
    mov si, enter_unreal_msg
    call _print_line

    push ax

    cli

    lgdt [UNREAL_PROTECTED_GDT_POINTER] ; Load GDT

    mov eax, cr0    ; Store control 0 register
    or eax, 1       ; Set PE bit (Protected enable)
    mov cr0, eax

    ; Set segments, not stack or code segment
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Move back to real mode but maintin segmetn limits
    mov eax, cr0    ; Store control 0 register
    and eax, 0xFFFFFFFE      ; Set PE bit (Protected enable)
    mov cr0, eax

    pop ax

    mov dword [jump_target], eax ; Location to jump to
    mov dword [jump_target + 4], 0x08 ; Segment descriptor

    jmp far [jump_target]

section .data

jump_target: dq 0