[BITS 16]

%include "Global.inc"
%include "Output.inc"
%include "status_msgs.inc"
%include "Error.inc"


section .text

global _read_sector

; Read 1 sector from disk into memeory

; EAX = Low dword of LBA to read from
; EDX = High dword of LBA to read from
; BX:DI = Memory location to store data in

_read_sector:
    
    mov word [sector_offset], di
    mov word [sector_segment], bx

    mov dword [sectors_start_lba], eax
    mov dword [sectors_start_lba + 4], edx

    mov ah, 0x42                ; BIOS function for extended read sectors
    mov dl, [rgos_bd]           ; dl is the device to read from (boot drive)
    mov si, SECTOR_DAP          ; A disk address packet (DAP) that describes what to read and where
    int 0x13                    ; Call BIOS to read sectors

    jc _read_sector_err

    ret

_read_sector_err:

    mov si, read_sector_errmsg
    call _print_line

    call _error

section .data

SECTOR_DAP:
    db 0x10                     ; Size of DAP
    db 0                        ; Unused
    dw 0x01                     ; How many sectors to read
    sector_offset: dw 0         ; 4 byte segment:offset pointer for where to write bytes in memeory
    sector_segment: dw 0        ; Offset first since this is little endian
    sectors_start_lba: dd 0     ; Sector to start at, quad word, but only first double will be filled
    dd 0                        ; Hence this extra double