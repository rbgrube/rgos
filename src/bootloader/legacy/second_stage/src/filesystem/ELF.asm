[BITS 16]

%include "Output.inc"
%include "Error.inc"
%include "Global.inc"
%include "FAT32.inc"
%include "Disk.inc"

section .text

; Takes cluster number in eax
; Loads elf file as defined into memeory

global _load_elf_file_from_cluster

_load_elf_file_from_cluster:

    mov dword [start_cluster], eax

    mov eax, eax           ; Cluster number in eax
    call _calc_cluster_lba  ; Get lba of first cluster of file in EAX

    add eax, dword [fat_partition_start_lba]

    mov edx, 0  ; Clear high word of LBA 
    mov bx, FAT_cluster_reading_segment ; Read to FAT cluster reading sector location
    mov di, FAT_cluster_reading_offset  ; in BX:DI
    call _read_sector

    ; Now first sector of elf file is in FAT_cluster_reading_segment:FAT_cluster_reading_offset
    
    push es

    mov bx, FAT_cluster_reading_segment
    mov es, bx
    mov eax, dword [elf_signiture]
    mov di, FAT_cluster_reading_offset
    mov ecx, dword es:[di]          
    cmp eax, ecx        ; Check for valid elf signiture
    

    jne _invalid_elf

    ; Parse ELF header

    mov eax, dword es:[di + 24] ; Entry adress (offset 24 in elf header)
    mov dword [e_entry], eax

    mov eax, dword es:[di + 28] ; Program header table offset (in bytes from start of elf file)
    mov dword [e_phoff], eax

    mov ax, word es:[di + 42] ; Program header table entry size
    mov word [e_phentsize], ax

    mov ax, word es:[di + 44] ; Program header count
    mov word [e_phnum], ax

    pop es

    ; Load program headers

    ret

_invalid_elf:

    mov si, invalid_elf_msg
    call _print_line

    call _error

section .data

elf_info:

    start_cluster: dd 0 ; Starting cluster of file

    e_entry: dd 0

    e_phoff: dd 0       ; Program header table file offset
    e_phentsize: dw 0   ; Program header table entry size
    e_phnum: dw 0       ; Program header table entry count

elf_signiture: db 0x7F, "ELF"
invalid_elf_msg: db "Kernel file (KERN...) is not a valid ELF file!"
