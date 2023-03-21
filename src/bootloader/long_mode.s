.extern kmain
.extern halt
.globl long_mode_start

.section .text
.code64
long_mode_start:
    xor %ax, %ax
    mov %ax, %ss
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    call kmain
    call halt
