# Real Mode Address Space (The First MiB)

| Start        | End          | Size       | Description                                               |
| ------------ | ------------ | -----------| ----------------------------------------------------------|
| `0x00000000` | `0x000003FF` | 1 KiB      | Real Mode IVT (Interrupt Vector Table)                    |
| `0x00000400` | `0x000004FF` | 256 bytes  | BDA (BIOS Data Area)                                      |
| `0x00000500` | `0x00006BFF` | 26.14 KiB  | Conventional memory                                       |
| `0x00006C00` | `0x00007C00` | 4 KiB      | **RGOS bootloader stack**                                 |  
| `0x00007C00` | `0x00007DFF` | 512 bytes  | **RGOS First stage bootloader and MBR partition table**   |
| `0x00007E00` | `0x00007FFF` | 512 bytes  | Conventional memory                                       |
| `0x00008000` | `0x0000FFFF` | 32 KiB     | **Reserved area for RGOS second stage bootloader**        |
| `0x00010000` | `0x000101FF` | 512 bytes  | **Reserved area for FAT32 partition boot sector and BPB** |
| `0x00010200` | `0x000102FF` | 512 bytes  | **Reserved area for reading FAT root dir**                |
| `0x00010300` | `0x000103FF` | 512 bytes  | **Reserved area for reading FAT tables**                  |
| `0x00010400` | `0x0007FFFF` | 449 KiB    | Conventional memory                                       |
| `0x00080000` | `0x0009FFFF` | 128 KiB    | EBDA (Extended BIOS Data Area) (partially used)           |
| `0x000A0000` | `0x000BFFFF` | 128 KiB    | Video display memory (hardware mapped)                    |
| `0x000C0000` | `0x000C7FFF` | 32 KiB     | Video BIOS                                                |
| `0x000C8000` | `0x000EFFFF` | 160 KiB    | BIOS Expansions (ROM, hardware mapped, Shadow RAM)        |
| `0x000F0000` | `0x000FFFFF` | 64 KiB     | Motherboard BIOS                                          |