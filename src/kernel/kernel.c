// Define VGA text mode memory location
#define VGA_ADDRESS 0xB8000
#define WHITE_ON_BLACK 0x0F  // White text, black background

void kernel_main() {
    volatile char *video = (volatile char *)VGA_ADDRESS;
    const char *message = "Hello Kernel";

    for (int i = 0; message[i] != '\0'; i++) {
        video[i * 2] = message[i];       // Character
        video[i * 2 + 1] = WHITE_ON_BLACK; // Attribute (color)
    }

    while (1); // Loop to prevent CPU from continuing execution into garbage
}