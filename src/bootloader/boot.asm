extern kmain
global start

KERNEL_STACK_SIZE equ 4096

section .bss
align 4
kernel_stack:
    resb KERNEL_STACK_SIZE

section .text
bits 32
start:
    mov esp, kernel_stack + KERNEL_STACK_SIZE

    call kmain

    hlt
    jmp $
