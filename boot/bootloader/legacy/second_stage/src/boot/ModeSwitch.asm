[BITS 16]

; This file will handle switching between real and protected mode
; as well as setting up a minimal GDT, and setting segment registers 
; for the second stage bootloader

%include "Output.inc"
%include "Error.inc"
%include "Global.inc"

section .text

; Enter unreal mode

; This is a pseduo proccsesing mode, where the CPU is in real mode
; but the segment limits are set to 4GB. This allows us to use
; 32-bit addressing in real mode.

global _enter_unreal
_enter_unreal:

    lgdt [UNREAL_PROTECTED_GDT_POINTER] ; Load GDT

    cli     ; Clear BIOS interrupts

    ; Enter protected mode
    mov eax, cr0    ; Store control 0 register
    or eax, 1       ; Set PE bit (Protected enable)
    mov cr0, eax    ; Put new control 0 register (with PE bit) back

    ; Set segment registers to point to the new GDT
    ; This will set the segment limits to 4GB
    call _set_protected_data_segments

    ; Go back to real mode, but with new 4GB segment limits
    mov eax, cr0    ; Store control 0 register
    and eax, 0xFFFFFFFE      ; Set PE bit (Protected enable)
    mov cr0, eax

    sti     ; Restore BIOS interrupts

    ret


; This will enter 32 bit protected mode and then jump to EAX
; 32 bit protected mode can address up to 4GB of memory
; in a flat addressing system (no segments)

global _enter_protected_mode
_enter_protected_mode:

    mov dword [protected_entrypoint_ptr], eax   ; Set the jump target

    lgdt [UNREAL_PROTECTED_GDT_POINTER] ; Load GDT

    cli ; Clear BIOS interrupts

    ; Enter protected mode
    mov eax, cr0    ; Store control 0 register
    or eax, 1       ; Set PE bit (Protected enable)
    mov cr0, eax    ; Put new control 0 register (with PE bit) back

    ; This will set the code segment to point to the new gdt
    jmp 0x08:_protected_mode_entry ; Jump to protected mode code segment (0x08)

    [BITS 32] ; 32 Bit code for new protected mode code

    _protected_mode_entry:

        call _set_protected_data_segments   ; Set data segments to the new GDT

        jmp far [protected_entrypoint_ptr]  ; Jump to adress passed in EAX

    [BITS 16]


; This will set all data segments to
; the data segment descriptor in the GDT

_set_protected_data_segments:
    
    mov ax, 0x10 ; Data segment in the GDT

    mov ds, ax  ; Set data segment 
    mov es, ax  ; Set extra segment
    mov fs, ax  ; Set fs segment
    mov gs, ax  ; Set gs segment

    ret


; This will set all data segments to
; the data segment that the stage 2 bootloader is loaded at
; for using real mode addressing

global _reset_real_segments
_reset_real_segments:

    mov ax, stage2_loaded_segment ; The segment stage2 is loaded at

    mov ds, ax  ; Set data segment 
    mov es, ax  ; Set extra segment
    mov fs, ax  ; Set fs segment
    mov gs, ax  ; Set gs segment

    ret 
    


section .data

protected_entrypoint_ptr:
    dd 0              ; Offset (lower 4 bytes)
    dw 0x08           ; Segment (code segment descriptor)

UNREAL_PROTECTED_GDT:

    ; Null segment descriptor
    dq 0x0000000000000000

    ; Code Segment Descriptor (Base=0, Limit=4GB, Executable, Readable)
    dw 0xFFFF          ; Limit (bits 0-15)
    dw 0x0000          ; Base (bits 0-15)
    db 0x00            ; Base (bits 16-23)
    db 0x9A            ; Access Byte: Present, Ring 0, Executable, Readable
    db 0xCF            ; Flags (4-bit limit high + Granularity=4KB + 32-bit)
    db 0x00            ; Base (bits 24-31)

    ; Data Segment Descriptor (Base=0, Limit=4GB, Writable, Readable)
    dw 0xFFFF          ; Limit (bits 0-15)
    dw 0x0000          ; Base (bits 0-15)
    db 0x00            ; Base (bits 16-23)
    db 0x92            ; Access Byte: Present, Ring 0, Writable
    db 0xCF            ; Flags (4-bit limit high + Granularity=4KB + 32-bit)
    db 0x00            ; Base (bits 24-31)

UNREAL_PROTECTED_GDT_END:

UNREAL_PROTECTED_GDT_POINTER:
    dw UNREAL_PROTECTED_GDT_END - UNREAL_PROTECTED_GDT - 1
    dd UNREAL_PROTECTED_GDT