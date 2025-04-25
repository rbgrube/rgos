#ifndef GDT_H
#define GDT_H

#include <stdint.h>

typedef struct __attribute__((packed)) {
    uint16_t limit_low;      // Lower 16 bits of limit
    uint16_t base_low;       // Lower 16 bits of base
    uint8_t  base_mid;       // Bits 16-23 of base
    uint8_t  access;         // Access flags
    uint8_t  granularity;    // Granularity + high 4 bits of limit
    uint8_t  base_high;      // Upper 8 bits of base
} GDT_entry;

void init_GDT(void);
GDT_entry create_GDT_entry(uint32_t base, uint32_t limit, uint8_t access, uint8_t granularity);

#endif