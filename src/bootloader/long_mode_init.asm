.global long_mode_start

.extern rust_main

.section .text
.code64
long_mode_start:
    // load 0 into all data segment registers
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    // call the rust main
    call rust_main

    // print `OKAY` to screen
    mov rax, 0x2F592F412F4B2F4F
    mov QWORD PTR [0xB8000], rax
    hlt
