#include "boot/GDT.h"
#include <stdint.h>

#define GDT_NUM_ENTRIES 3

void init_GDT(){
    
    GDT_entry GDT[GDT_NUM_ENTRIES];

    GDT[0] = create_GDT_entry(0, 0xFFFFFFFF, 0x9A, 0xC0);

}

GDT_entry create_GDT_entry(uint32_t base, uint32_t limit, uint8_t access, uint8_t granularity){

    GDT_entry entry;

    // Set base of entry 
    entry.base_low = base & 0xFFFF;
    entry.base_mid = (base >>  16) & 0xFF;
    entry.base_high = (base >>  24) & 0xFF;

    // Set limit of entry
    entry.limit_low = limit & 0xFFFF;
    entry.granularity = (granularity & 0xF0) + ((limit >> 16) & 0x0F);

    entry.access = access;

    return entry;
}