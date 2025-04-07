ENTRY(_stage2_start)

SECTIONS
{
    /* Load stage 2 at 0x8000 */
    . = 0x8000;
    start_stage2_bootloader_loc = .;

    .text : {
        *(.main)   /* Start of 2nd bootloader */
        . = ALIGN(8);
        *(.text)      /* Code section */
    }

    .rodata : {
        *(.rodata)    /* Read-only data */
    }
    
    .data : {
        *(.data)      /* Initialized data */
    }

    .bss : {
        *(.bss)       /* Uninitialized data */
        *(COMMON)     /* Common symbols */
    }

    end_stage2_bootloader_loc = .;
    
    ASSERT(end_stage2_bootloader_loc <= 0xFFFF, "Error: Seoncd stage bootloader exceeds allocated 32kb memory limit!")
}