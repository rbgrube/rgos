[BITS 16]

%include "Global.inc"
%include "status_msgs.inc"
%include "Output.inc"

section .text

global _enter_unreal

_enter_unreal:

    ; Save state

    push ax
    shr eax, 16
    push ax 

    lgdt [UNREAL_PROTECTED_GDT_POINTER] ; Load GDT

    cli

    mov eax, cr0    ; Store control 0 register
    or eax, 1       ; Set PE bit (Protected enable)
    mov cr0, eax

    ; Move back to real mode but maintin segment limits
    mov eax, cr0    ; Store control 0 register
    and eax, 0xFFFFFFFE      ; Set PE bit (Protected enable)
    mov cr0, eax

    sti

    pop ax
    shl eax, 16
    pop ax 

    ret

global _reset_real_segments

_reset_real_segments:


    ; ax should be same as stage2_load_segment from
    ; the stage one bootloader
    mov ax, stage2_loaded_segment

    mov ds, ax  ; Set data segment to stage2_load_segment
    mov es, ax  ; Set extra segment to stage2_load_segment
    mov fs, ax  ; Set fs segment to stage2_load_segment
    mov gs, ax  ; Set gs segment to stage2_load_segment

    ret ; Can use return, no modification to the stack

global _enter_protected_mode

; returns at eax in portected mode
_enter_protected_mode:
    mov dword [protected_entrypoint_ptr], eax

    lgdt [UNREAL_PROTECTED_GDT_POINTER] ; Load GDT

    cli

    mov eax, cr0    ; Store control 0 register
    or eax, 1       ; Set PE bit (Protected enable)
    mov cr0, eax

    jmp 0x08:_protected_mode_entry ; Jump to protected mode code segment

[BITS 32]

_protected_mode_entry:

    ; Set segments, not stack or code segment
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    jmp far [protected_entrypoint_ptr] ; Jump to protected mode code segment


[BITS 16]

section .data

protected_entrypoint_ptr:
    dd 0              ; Offset (lower 4 bytes)
    dw 0x08           ; Segment (code segment descriptor)