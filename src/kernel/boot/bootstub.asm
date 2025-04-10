[BITS 32]

global _bootstub
extern kernel_main

extern _kernel_stack_top

section .text
_bootstub:
    
    mov esp, _kernel_stack_top ; Set up the stack pointer
    xor ebp, ebp ; Clear the base pointer

    ; Call the kernel main function
    call kernel_main

    ; Infinite loop to prevent returning from the bootstub
    jmp $
