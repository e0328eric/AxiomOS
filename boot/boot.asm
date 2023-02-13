;;
;; fooOs bootloader
;;
global start

%include "vga.asm"

section .bss
stack_bottom:
    resb 16384
stack_top:

section .text
bits 32
start:
    mov esp, stack_top

    call terminal_initialize

    mov edi, hello
    call terminal_writestring

    hlt
    jmp $

section .data
hello: db "Hello fooOS! Printing works! Yay!!!!!", 0
