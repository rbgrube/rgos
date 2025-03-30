# First stage bootloader

The *first stage bootloader* is located in the first 446 bytes of the [MBR](../disk_image/MBR.md), and it the first peice of code executed by the BIOS.

It's job is to load the second stage bootloader from sector 2 of the boot disk into memoery and preform a far jump to it. 

**Why do we need two stages?**

Since the BIOS only loads the first sector of the boot disk for initial execution, we only have 512 bytes of space to implement code that jumps to the kernel. Since we are choosing to put the kernel in a FAT32 file system, the code to load it is actually quite large, and would exceed this 512 (446 with the inclusion of the MBR partition table) byte limit. 

This can be circumvented by using a small *first stage bootloader* that simply loads a much larger section of the disk in order to run our *second stage bootloader,* which will ultimatley load the kernel.

# Procces:

**Initilize segment registers and stack**

The first stage bootloader begins in 16 bit real mode, and uses [Real mode memory addressing](real_mode_memory.md)

The code segment register is set by the bios, but the bootloader has to make sure the data segment, extra segment, and stack segment registers are all properly initilized. 

In the RGOS first stage bootloader, `DS`, `ES`, and `SS` are all initlized to `0x0000`

The stack is setup growing down from the start of the bootloader, so SP is set to `0x7C00`

Note: The same stack is attainable by setting `SS` to `0x7C0` and `SP` to `0x0000`

**Read second stage bootloader from disk**

The RGOS image reserves 32 kB of space for the second stage bootloader starting at the second sector.

The bootloader reads sectors using BIOS int13h and a disk addres packet (DAP) describing what to read and where.

The first stage bootloader will then read sectors of the boot device starting at the second into a buffer at `0x1000:0000` after wchih it will preform a far jump to this location and begin executing the code of the sseocnd stage.


