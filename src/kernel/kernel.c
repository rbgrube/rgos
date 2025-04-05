// kernel.c
// Compile with: i386-elf-gcc -ffreestanding -m32 -nostdlib -c kernel.c -o kernel.o

#include <stdint.h>

#define VGA_ADDRESS 0xB8000
#define WHITE_ON_BLACK 0x0F

static const char* message = "Hello, world!";
static const uint8_t colors[] = {
    0x1F, 0x2F, 0x3F, 0x4F, 0x5F, 0x6F,
    0x7F, 0x8F, 0x9F, 0xAF, 0xBF, 0xCF
};

void kernel_main(void) {
    volatile uint16_t* vga = (uint16_t*)VGA_ADDRESS;
    for (int i = 0; message[i] != 0; i++) {
        uint8_t color = colors[i % (sizeof(colors) / sizeof(colors[0]))];
        vga[i] = (color << 8) | message[i];
    }

    // Hang forever
    while (1) {
        __asm__ __volatile__("hlt");
    }
}