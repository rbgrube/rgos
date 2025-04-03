; RGOS First Stage Bootloader
; Ryan Grube
; March 24, 2025

[BITS 16]                    ; Start in 16-bit real mode

%ifdef RAW_BINARY            ; Dont include ORG directive if assembling to elf32 object
[ORG 0x7C00]                 ; NASM directive to denote bootloader loaded at 0x7c00 by BIOS
%endif 

%define stage2_starting_sector 1    ; Sector where RGOS Second Stage Bootloader starts (0 indexed)
%define stage2_size_sectors 64      ; Size of RGOS Second Stage Bootloader in sectors (1 sector = 512 bytes) so 32Kb
%define stage2_load_offset 0x8000   ; Real mode memory offset to load RGOS Second Stage Bootloader
%define stage2_load_segment 0x0000  ; Real mode memory segment to load RGOS Second Stage Bootloader

; So the second stage bootloader will be loaded at 0x0000:8000 (0x8000)

;ensure cs:ip is 0x0000:7c00 and not 0x07c0:0000
jmp 0:_stage1_start

; Main for stage 1 bootloader
_stage1_start:

    ; Ensure BIOS is in text mode 
    mov ah, 0x00
    mov al, 0x03   ; 80x25 text mode
    int 0x10       ; BIOS video interrupt

    mov si, startmsg
    call _print_line

    ; Setup the stack and segment registers
    ; Cant use 'call' becuase the return directive uses stack so 
    ; modifying the stack inside of call will cause return to break
    jmp _init_seg_stack

    ; Hence this callback to jump to after stack init
    stack_init_callback:

    ; Read the second stage bootloader from disk into memeory
    call _read_stage2

    mov si, jump_msg
    call _print_line
    
    ; Jump to the memory address where the second stage bootloader is loaded
    jmp far [stage2_load_pointer]

    cli
    hlt

; Setup the stack and segment registers
_init_seg_stack:

    mov si, init_seg_stack_msg
    call _print_line

    cli               ; Disable interrupts

    xor ax, ax

    ; These registers are used as segment offsets for various operations
    ; See theory/bootloader/real_mode_memory.md for more details

    mov ds, ax        ; Set data segment to 0
    mov es, ax        ; Set extra segment to 0
    mov ss, ax        ; Set stack segment to 0

    ; The stack is set to 0x7c00, so it will grow downwards below the bootloader
    mov sp, 0x7C00    ; Move stack pointer to safe location

    sti               ; Re-enable interrupts

    jmp stack_init_callback

; Read stage 2 bootloader from disk into memory 
_read_stage2:

    mov si, read_stg2_msg
    call _print_line

    ; Set dl to the boot device id
    mov ah, 0x00    ; Reset disk drive
    int 0x13        ; BIOS interrupt to reset disk drive

    mov ah, 0x42            ; BIOS function for extended read sectors
;   mov dl, dl              ; dl is the device to read from but its already set
    mov si, STAGE2_READ_DAP ; A disk address packet (DAP) that describes what to read and where
    int 0x13                ; Call BIOS to read sectors

    jc _read_stage2_err     ; Error if carry is set

    ret

_read_stage2_err:

    mov si, read_stg2_errmsg
    call _print_line

    cli
    hlt

    jmp $

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

newline: db 0x0d, 0x0a, 0
signiture: db "<RGOS Stage 1 Bootloader> ", 0

startmsg: db "Executing...", 0
init_seg_stack_msg: db "Initiating segments and stack..", 0
detect_boot_msg: db "Detecting boot device...", 0
read_stg2_msg: db "Reading second stage bootloader into memory...", 0
read_stg2_errmsg: db "Error reading stage 2 into memory!", 0
jump_msg: db "Jumping to stage 2!", 0

; Disk address packet that describes what to read using int 13h ah=42h
STAGE2_READ_DAP:
    db 0x10                     ; Size of DAP
    db 0                        ; Unused
    dw stage2_size_sectors      ; How many sectors to read
    stage2_load_pointer:        ; Pointer that holds the segment:offset value of where to load the data (used for jump)
    dw stage2_load_offset       ; 4 byte segment:offset pointer for where to write bytes in memeory
    dw stage2_load_segment      ; Offset first since this is little endian
    dq stage2_starting_sector   ; Sector to start at
    

times 446-($-$$) db 0         ; Pad the remaining bytes (making room for the MBR)
