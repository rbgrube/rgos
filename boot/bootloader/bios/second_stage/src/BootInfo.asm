[BITS 16]

global _handle_boot_device

%include "Output.inc"
%include "Error.inc"
%include "status_msgs.inc"
%include "Global.inc"

section .text

; Detect boot device and store in the RGOS_INFO_STRUCT
_handle_boot_device:
    mov si, boot_device_msg
    call _print_line

    mov ah, 0x00    ; Reset disk drive
    int 0x13        ; BIOS interrupt to reset disk drive
    jc _error       ; If carry flag is set, there was an error

    mov byte [rgos_bd], dl ; Store the boot device in boot info struct

    ret



