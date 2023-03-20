.extern kmain
.globl start
.globl halt

.set KERNEL_STACK_SIZE, 4096

.section .bss
.align 4
kernel_stack_bottom:
    .fill KERNEL_STACK_SIZE, 1, 0
kernel_stack_top:

.section .text
.code32
.type start, @function
start:
    mov $kernel_stack_top, %esp
    call kmain

halt:
    hlt
    jmp halt
