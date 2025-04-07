[BITS 16]

%include "Global.inc"
%include "Output.inc"
%include "status_msgs.inc"
%include "Error.inc"

global _read_partiton_table

; Read partition table and locate fat32 partition
_read_partiton_table:

    mov si, read_partition_table_msg
    call _print_line

    ; Traverse the partition table

    mov bx, part_table_offset ; Offset for the partition table in the MBR
    mov si, 0 ; offset of entry from partition table

    push ds ; preserve data segment since reading from segment 0x0000
    mov ax, stage1_segment
    mov ds, ax

_read_partiton_table_loop:
    ; Read each partition entry

    cmp byte [bx + si + 0x04], 0x0B  ; Check if partition type (0x04 offset in entry) is FAT32 (0x0b or 0x0c)
    je _found_partition         ; If FAT32, jump to found partition
    cmp byte [bx + si + 0x04], 0x0C
    je _found_partition


    add si, 0x10 ; Add 16 to offset (move to next entry)

    cmp si, 0x40 ; Check if we've read all 4 entries (4 * 16 = 64 bytes)
    jg _no_partition_found; If bx > 64, no partitooin, looped through all entries

    jmp _read_partiton_table_loop ; Continue loop until all entries are checked

_found_partition:
    pop ds ; Restore the original data segment  

    mov eax, [bx + si + 0x08] ; Get the starting LBA of the partition (0x08 offset in entry)
    mov dword [fat_partition_start_lba], eax

    ; Found a FAT32 partition
    mov si, found_partition_msg
    call _print_line 

    ret ; Return to caller, FAT32 partition found

_no_partition_found:
    pop ds ; Restore the original data segment

    ; Did not find a FAT32 partition
    mov si, no_part_errmsg
    call _print_line 

    call _error
