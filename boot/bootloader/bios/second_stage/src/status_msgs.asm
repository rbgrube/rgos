[BITS 16]

global startmsg, boot_device_msg, read_partition_table_msg, found_partition_msg, no_part_errmsg, \
       read_FAT32_boot_msg, read_FAT32_boot_successmsg, read_FAT32_boot_errmsg, load_BPB_info_msg, \
       read_fat_table_sector_eemsg, read_FAT_cluster_sectors_errmsg, locate_kern_msg, \
       locate_kern_finish_chain_msg, found_kernel_msg, loading_kernel_msg, read_sector_errmsg

section .data

read_sector_errmsg: db "Error reading disk sector!", 0

startmsg: db "Initiated segment registers, executing...", 0

boot_device_msg: db "Identifying boot device...", 0

read_partition_table_msg: db "Reading partition table...", 0
found_partition_msg: db "Found FAT32 partition in partition table!", 0
no_part_errmsg: db "Couldn't find FAT32 partition in partition table!", 0

read_FAT32_boot_msg: db "Loading FAT32 boot sector into memory...", 0
read_FAT32_boot_successmsg: db "FAT32 boot sector loaded!", 0
read_FAT32_boot_errmsg: db "Couldn't read FAT32 boot sector into memory!", 0

load_BPB_info_msg: db "Reading BPB info from FAT32 boot sector...", 0

read_fat_table_sector_eemsg: db "Error reading FAT table sector!", 0

read_FAT_cluster_sectors_errmsg: db "Error reading sectors from FAT cluster to memory!", 0 

locate_kern_msg: db "Locating kernel in FAT32 root directory...", 0
locate_kern_finish_chain_msg: db "No kernel in root directory cluster chain!", 0
found_kernel_msg: db "Found kernel!", 0

loading_kernel_msg: db "Loading kernel into memeory...", 0