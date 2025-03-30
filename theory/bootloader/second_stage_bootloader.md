# Bootloader

The bootloader is the first program that is run by the computor, and it is executed by the BIOS. Its primary job is to read the kernel from disk and begin its execution. The steps to do that are as follows:

# Procces:

**Re-initialize segment registers**

**Pass information to boot_info struct**

C) Read the partition table MBR to locate the FAT32 partition

D) Read the FAT32 reserved sector to gather data about the FAT tables

E) Traverse the fat tables to find "kernel.bin"

F) Switch to protected mode

G) Follow the cluster chain of kernel.bin and read it into memeory

H) Preform far jump to kernel_main



