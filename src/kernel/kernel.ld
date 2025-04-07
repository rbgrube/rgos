ENTRY(_bootstub)

SECTIONS
{
  . = 0x100000; /* Start of the kernel in memory */
  .text : {
    *(.text) /* All text sections from all object files */
  }
  .data : {
    *(.data) /* All data sections from all object files */
  }
  .bss : {
    *(.bss) /* All bss sections from all object files */
  }

  .stack ALIGN(16) :
    {
        _kernel_stack_bottom = .;
        . = . + 0x4000;  /* 16 KB stack */
        _kernel_stack_top = .;
    }
}