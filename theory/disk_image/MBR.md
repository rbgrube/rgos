# MBR (Master boot record)

The first sector of the boot disk is called the MBR, and it's structure is as follows:

| Offset          | Bytes | Description                           |
| --------------- | ----- | ------------------------------------- |
| `0x0000` - `0x01BD` | 446   | Bootloader code                       |
| `0x01BE` - `0x01FD` | 64    | Partition Table (4 x 16 byte entries) |
| `0x01FE` - `0x01FF` | 2     | Boot signiture (0x55AA)               |

The boot signiture tells the bios to load and run the MBR at 0x7C00. This causes the bootloader code to be the first thing ran by the BIOS. The partition table consists of entries that have iunformation about the partitions on the disk. 

Each entry in the partition table is structured as follows:

| **Offset (Hex)** | **Size (Bytes)** | **Field** | **Description** |
|-----------------|----------------|----------|----------------|
| `0x00` | 1 | Boot Indicator | `0x80` = Bootable, `0x00` = Non-bootable |
| `0x01` | 3 | CHS Address of First Sector | Cylinder-Head-Sector format (Legacy BIOS) 
| `0x04` | 1 | Partition Type | Identifies filesystem (`0x0B` = FAT32) |
| `0x05` | 3 | CHS Address of Last Sector | Last sector in CHS format |
| `0x08` | 4 | LBA of First Sector | Logical Block Address (start of partition) |
| `0x0C` | 4 | Total Sectors in Partition | Size of the partition in sectors |

In the case of RGOS, the partition table will be traversed, looking for a FAT32 filesystem partitoin, and it will try to load the kernel from that partition when found.
