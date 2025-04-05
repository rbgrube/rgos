%define stage1_segment 0x0000 ; Segment where stage 1 bootloader is loaded
%define stage1_offset 0x7C00 ; Offset where stage 1 bootloader is loaded

%define stage2_loaded_segment 0x0000 ;  Segment where stage 2 bootloader is loaded

%define part_table_offset 0x7c00 + 0x1BE ; Offset for the partition table from the MBR

%define FAT_boot_loading_segment 0x1000 ; Segment where FAT32 boot sector will be loaded
%define FAT_boot_loading_offset 0x0000 ; Offset where FAT32 boot sector will be loaded

%define FAT_table_loading_segment 0x1000 ; Segment where FAT32 boot sector will be loaded
%define FAT_table_loading_offset 0x0300 ; Offset where FAT32 boot sector will be loaded

%define FAT_cluster_reading_segment 0x1000 ; Segment where FAT32 boot sector will be loaded
%define FAT_cluster_reading_offset 0x0200 ; Offset where FAT32 boot sector will be loaded

extern RGOS_INFO_STRUCT
extern rgos_bd

extern fat_partition_start_lba

extern BPB_NumFATs
extern BPB_FATSz32
extern BPB_RootClus
extern BPB_SecPerClus
extern BPB_RsvdSecCnt
extern BPB_BytsPerSec

extern UNREAL_PROTECTED_GDT_POINTER