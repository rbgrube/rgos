#include <stdint.h>
#include "rgos_info.h"

void kernel_main(void) {
    unsigned int ebx_value;

    // Read the value of the EAX register using inline assembly
    __asm__ volatile (
        "mov %%ebx, %0"  // Move the value of ebx into ebx_value
        : "=r"(ebx_value)  // Output operand: ebx_value will hold the value
        :                   // No input operands
        : "%ebx"            // Clobbered register (ebx will be modified)
    );

    rgos_info_t *rgos_info = (rgos_info_t *) ebx_value;

    vbe_mode_info_t *vbe_mode_info = (vbe_mode_info_t *) rgos_info->rgos_vbe_mode_info_addr;

    uint32_t frame_buffer = vbe_mode_info->PhysBasePtr;

    // Calculate the total size of the screen in bytes
    uint32_t screen_size = vbe_mode_info->YResolution * vbe_mode_info->BytesPerScanLine;

    // Fill the screen with red color (0x00FF0000)
    uint32_t pixel_value = 0x00FF00FF;  // Red color in RGB format

    // Use memcpy or memset to fill the screen efficiently
    for (int j = 0; j < vbe_mode_info->YResolution; j++) {
        uint32_t *line_start = (uint32_t *)(frame_buffer + j * vbe_mode_info->BytesPerScanLine);
        for (int i = 0; i < vbe_mode_info->XResolution; i++) {
            line_start[i] = pixel_value; // Set pixel in this row
        }
    }

    // Hang forever
    while (1) {
        __asm__ __volatile__("hlt");
    }
}