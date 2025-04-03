ENTRY(_stage2_start)

SECTIONS
{
    /* Load stage 2 at 0x8000 */
    . = 0x8000;

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

}