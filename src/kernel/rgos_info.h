#include <stdint.h>

typedef struct __attribute__((packed)){
    uint8_t rgos_bd;
    uint32_t rgos_mem_map_addr;
    uint32_t rgos_mem_map_size;
    uint32_t rgos_vbe_mode_info_addr;
    uint32_t rgos_vbe_mode_info_size;
} rgos_info_t ;

typedef struct __attribute__((packed)) {
    uint16_t ModeAttributes;          // 0x00: Mode attributes (e.g., supported, graphics mode, etc.)
    uint8_t WinAAttributes;           // 0x02: Window A attributes
    uint8_t WinBAttributes;           // 0x03: Window B attributes
    uint16_t WinGranularity;          // 0x04: Granularity of each window (in bytes)
    uint16_t WinSize;                 // 0x06: Size of each window (in bytes)
    uint16_t WinASegment;             // 0x08: Segment of window A
    uint16_t WinBSegment;             // 0x0A: Segment of window B
    uint32_t WinFuncPtr;              // real mode pointer to window function
    uint16_t BytesPerScanLine;        // 0x14: Number of bytes per scanline

    uint16_t XResolution;             // 0x16: X Resolution (width)
    uint16_t YResolution;             // 0x18: Y Resolution (height)
    uint8_t XCharSize;                // 0x1A: Character cell size in X direction (if applicable)
    uint8_t YCharSize;                // 0x1B: Character cell size in Y direction (if applicable)
    uint8_t Planes;                   // 0x1C: Number of memory planes
    uint8_t Bpp;                      // 0x1D: Bits per pixel
    uint8_t Banks;                    // 0x1E: Number of banks
    uint8_t MemoryModel;              // 0x1F: Memory model type
    uint8_t BankSize;                 // 0x20: Size of each bank
    uint8_t ImagePages;               // 0x21: Number of images (pages)
    uint8_t Reserved0;                // 0x22: Reserved for future use

    uint8_t RedMaskSize;             // 0x23: Size of red mask in bits
    uint8_t RedFieldPosition;        // 0x2B: Red field position in bits
    uint8_t GreenMaskSize;           // 0x25: Size of green mask in bits
    uint8_t GreenFieldPosition;      // 0x2D: Green field position in bits
    uint8_t BlueMaskSize;            // 0x27: Size of blue mask in bits
    uint8_t BlueFieldPosition;       // 0x2F: Blue field position in bits
    uint8_t ReservedMaskSize;        // 0x29: Reserved mask size in bits
    uint8_t RsvdFieldPosition;       // 0x31: Reserved field position in bits
    uint8_t DirectColorModeInfo;      // 0x33: Direct color mode info (if applicable)

    uint32_t PhysBasePtr;             // 0x34: Physical base address of the frame buffer
    uint32_t Reserved1;
    uint16_t Reserved2;

    uint16_t LinBytesPerScanLine;
    uint8_t BnkNumberOfImagePages;
    uint8_t LinNumberOfImagePages;
    uint8_t LinRedMaskSize;
    uint8_t LinRedFieldPosition;
    uint8_t LinGreenMaskSize;
    uint8_t LinGreenFieldPosition;
    uint8_t LinBlueMaskSize;
    uint8_t LinBlueFieldPosition;
    uint8_t LinRsvdMaskSize;
    uint8_t LinRsvdFieldPosition;
    uint32_t MaxPixelClock;
    
} vbe_mode_info_t;