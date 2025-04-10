; FAT HELPERS
[BITS 16]

%include "status_msgs.inc"
%include "BPB.inc"
%include "Global.inc"
%include "BootInfo.inc"
%include "Error.inc"
%include "Output.inc"
%include "Disk.inc"

global _calc_cluster_lba, _fetch_next_FAT_cluster, end_follow_early, _follow_FAT_cluster_chain, _read_FAT_cluster_sectors

section .text

; Takes cluster number in eax and calculates the logical block address (LBA) for that cluster
; Relative to begining of FAT partition
; Stores lba back in eax
_calc_cluster_lba:

    ; BPB_RsvdSecCnt + (BPB_NumFATs * BPB_FATSz32) + ((CLUSTER_NUM - 2) * BPB_SecPerClus)
    break6:
    ; Save cluster num
    mov edx, eax
    push ax
    shr eax, 16
    push ax 
    mov eax, edx

    ; Accumulator

    movzx ecx, word [BPB_RsvdSecCnt] ; Value will be finally stored in edx for calculation

    ; Multiply FATs

    movzx eax, byte [BPB_NumFATs] ; Number of FATs
    mov ebx, dword [BPB_FATSz32] ; Size of each FAT in sectors
    mul   ebx ; Multiply by size of each FAT in sectors to get total sectors for all FATs - stored in edx:eax

    add ecx, eax

    ; Restore cluster num
    pop ax
    shl eax, 16
    pop ax 

    sub eax, 2 ; Clusters are indexed at 2

    movzx ebx, byte [BPB_SecPerClus] ; Sectors per cluster

    mul ebx ; Multiply by sectors per cluster to get total sectors for clusters

    add ecx, eax ; Add the reserved sectors count to the total sectors for FATs

    ; Final value now in eax

    mov dword eax, ecx ; Store the calculated root directory start in sectors
    
    ret

; Takes cluster number in esi and reads the next cluster from the FAT table
; Returns next cluster num back in esi
; End of cluster chain, returns 0xFFFFFFFF in esi
_fetch_next_FAT_cluster:
    ; Read the FAT entry for the current cluster in ESI

    ; First find out which sector its in 
    ; (Cluster Number * 4) = Bytes count of the next cluster number in the FAT table (each entry 4 bytes)
    ; So divde by bytes per sector to get setcor number
    ; Sector = Reserved Sectors + (Cluster Number * 4) / (bytes per sector)
    
    mov eax, esi ; Cluster number
    shl eax, 2 ; Multiply by 4 to get the byte offset in the FAT table for the cluster number

    ; Now divide by bytes per sector to get the sector number
    xor edx, edx ; Clear EDX before division, since we will be dividing EAX by a 16 bit value
    movzx ebx, word [BPB_BytsPerSec]
    div ebx ; divde edx:eax by ebx 

    ; NOTE: edx also now has the remainder of this division, or the modulo, which will be uysed later
    ; push edx - Save EDX for later use, since we will need it after division
    push dx
    shr edx, 16
    push dx 

    ; EAX now has the sector number (relative to begining of FAT tables) in it, and EDX has the remainder
    movzx ecx, word [BPB_RsvdSecCnt]
    add eax, ecx ; Add reserved sectors count to get the actual sector number from begining of PARTITION

    ; EAX now has the sector number to read from relative to begnging of PARTITIOn
    ; add the FAT table offset from the begning of the DISK, not just the partition
    
    mov ebx, dword [fat_partition_start_lba] 
    add eax, ebx 
    mov edx, 0 ; Clear carry
    adc edx, 0 ; Handle carry from addition, if any

    ; Now EDX:EAX has the absolute sector number to read from
    
    mov bx, FAT_table_loading_segment   ; BX = segment to read to
    mov di, FAT_table_loading_offset    ; DI = offset to read to

    call _read_sector                  ; Reads 1 sector from EDX:EAX LBA on disk into BX:DI in memeory
    
    ; Now the sector that we need to read is in FAT_table_loading_segment:FAT_table_loading_offset
    jc _fetch_next_FAT_cluster_err ; If carry is set, there was an error reading the FAT table

    ; Now read the next cluster number from the FAT table
    ; We need the next cluster number address offset within the sectopr we are reading 
    ; (Cluster Number * 4) % bytes per sector 

    ; Restore EDX (32-bit)
    pop dx         
    shl edx, 16    
    pop dx         

    ; EDX still has remainder of the division from before, which is the offset within the sector to read

    ; So now [FAT_table_loading_segment:FAT_table_loading_offset + edx] is a double word with the next cluster number
    push es ; Preserve ES since we are going to access memory
    mov ax, FAT_table_loading_segment
    mov es, ax ; Set ES to the segment where the FAT table was loaded
    mov eax, es:[FAT_table_loading_offset + edx] ; Read the next cluster number from the FAT table
    pop es ; Restore ES

    ; EAX now has the next cluster number
    cmp eax, 0x0FFFFFF8
    jge _fetch_next_FAT_cluster_EOF
    
    ret 

_fetch_next_FAT_cluster_EOF:
    mov esi, 0xFFFFFFFF ; End of cluster chain, set ESI to 0xFFFFFFFF to indicate end of chain

    ret

_fetch_next_FAT_cluster_err:
    mov si, read_fat_table_sector_eemsg
    call _print_line ; Print error message for reading FAT table sector

    call _error ; Call error handler if we couldn't read the FAT table

section .data

; Follows a cluster chain starting at esi
; Calls function at ax on each cluster, with esi as the cluster number
; Calls bx when finished
end_follow_early: db 0 ; Returns imeaditley if this is not 0 and resets it

section .text
_follow_FAT_cluster_chain:

    ; Preserve AX
    push ax        
    
    ; Preserve BX 
    push bx      
    
    mov edx, esi
    ; Preserve ESI (32-bit)
    push si        ; Push lower 16 bits of ESI
    shr esi, 16    ; Shift upper 16 bits into SI
    push si        ; Push upper 16 bits of ESI
    mov esi, edx
    
    call ax

    ; Restore ESI (32-bit)
    pop si         ; Pop upper 16 bits into SI
    shl esi, 16    ; Shift upper 16 bits into the high part of ESI
    pop si         ; Pop lower 16 bits into SI

    call _fetch_next_FAT_cluster ; Find next cluster and store in ESI

    ; Restore BX 
    pop bx

    ; Restore AX
    pop ax

    cmp byte [end_follow_early], 0
    jne _follow_FAT_cluster_chain_return ; If break ealry set, return

    ; Check if we reached the end of the cluster chain
    cmp esi, 0xFFFFFFFF
    je _follow_FAT_cluster_chain_finished ; If ESI is 0xFFFFFFFF, we reached the end of the chain
    
    jmp _follow_FAT_cluster_chain

_follow_FAT_cluster_chain_finished:
    call bx
    jmp _follow_FAT_cluster_chain_return

_follow_FAT_cluster_chain_return:
    mov byte [end_follow_early], 0
    ret

; Reads the FAT cluster number in esi to memory sector by sector
; Calls function at ax on each sector, with DX:SI as the segment offset pointer to the first byte of the sector in memeory 
_read_FAT_cluster_sectors:
    mov ecx, 0 ; Amount of sectors read

    _read_FAT_cluster_sectors_loop:

        ; push ax
        push ax

        ; push ecx
        push cx
        shr ecx, 16
        push cx

        mov eax, esi
        break4:
        call _calc_cluster_lba ; eax now holds cluster LBA
        break5:
        add eax, dword [fat_partition_start_lba] ; add offset from begging of partition

        ; pop ecx
        pop cx
        shl ecx, 16
        pop cx

        add eax, ecx ; Add the number of sectors read so far to the current LBA
        mov dword [read_cluster_sectors_start], eax ; Set the starting sector for the read operation
        
        break3:

        mov eax, 0
        mov esi, 0

        mov ah, 0x42                     ; BIOS function for extended read sectors
        mov dl, [rgos_bd]                ; dl is the device to read from (boot drive)
        mov si, read_cluster_sectors_DAP ; A disk address packet (DAP) that describes what to read and where
        int 0x13                         ; Call BIOS to read sectors
        
        ; pop ax
        pop ax

        jc _read_FAT_cluster_sectors_err ; If carry is set, there was an error reading the sector

        mov dx, FAT_cluster_reading_segment

        push cx
        shr ecx, 16
        push cx

        mov si, FAT_cluster_reading_offset

        call ax ; Call to process entries in the root directory for the current sector

        pop cx
        shl ecx, 16
        pop cx

        add ecx, 1 ; Increment the number of sectors read
        movzx edx, byte [BPB_SecPerClus]
        cmp ecx, edx  ; Check if we've read all sectors for this cluster

        jge _read_FAT_cluster_sectors_return ; Finished sectors

        jmp _read_FAT_cluster_sectors_loop

    
    _read_FAT_cluster_sectors_return:

        ret

    _read_FAT_cluster_sectors_err:
        mov si, read_FAT_cluster_sectors_errmsg
        call _print_line

        call _error

    section .data
    read_cluster_sectors_DAP:
        db 0x10                         ; Size of DAP
        db 0                            ; Unused
        dw 0x01                         ; How many sectors to read
        dw FAT_cluster_reading_offset   ; 4 byte segment:offset pointer for where to write bytes in memory (to be filled in)
        dw FAT_cluster_reading_segment  ; Offset first since this is little endian 
        read_cluster_sectors_start: 
        dd 0                            ; Sector to start at, quad word, but only first double will be filled
        dd 0


section .text
; Finds a file or directory in a FAT directory

; Starts at cluster number in esi
; Takes first 4 bytes of name in ecx
; Returns address of a 32 byte diretory entry in DX:SI
; Sets carry if couldnt find anything
global _find_in_FAT_dir
_find_in_FAT_dir:

    mov dword [find_target_name], ecx ; store target name

    mov esi, esi ; Starting cluster num
    mov ax, _entry_find_cluster_modifier
    mov bx, _entry_find_clusters_finished  

    call _follow_FAT_cluster_chain

    mov dx, stage2_loaded_segment
    mov si, found_dir_entry

    ret

    _entry_find_cluster_modifier:

        mov esi, esi ; each cluster Num
        mov ax, _entry_find_sector_modifier

        break2:

        call _read_FAT_cluster_sectors

        ret

        ; DX:SI as the segment offset pointer to the first byte of the sector in memeory 
        ; Ran on every sector of cluster
        ; 32 Byte entries
        _entry_find_sector_modifier:

            mov bx, 0

            _sector_entry_loop:

                push es

                mov eax, dword [find_target_name]

                mov es, dx

                mov ecx, dword es:[si + bx] ; in FAT directory entry name offset is 0

                cmp eax, ecx
                je _found_target

                pop es

                add bx, 0x20 ; Increment entry 32 bytes
                cmp bx, 0x200 ; if goes over sector

                jge _sector_over

                jmp _sector_entry_loop
            
            _sector_over:

                ret

            _found_target:
    
                mov ax, 0

                _copy_entry_to_buffer_loop:

                    ; copy byte
                    push bx
                    add bx, ax
                    mov cl, byte es:[si + bx]

                    lea bx, found_dir_entry
                    add bx, ax
                    mov byte [bx], cl

                    pop bx

                    add ax, 1
                    cmp ax, 32

                    jl _copy_entry_to_buffer_loop ; Copy all 32 bytes

                mov byte [end_follow_early], 0x1 ; break early from cluster chain

                pop es ; Retsore es before returning bc of JMP

                ret

    _entry_find_clusters_finished:

        ; Did not find the file

        stc ; Set carry bit
        ret


section .bss

find_target_name:
    resb 4

found_dir_entry:
    resb 32
; End of FAT helpers