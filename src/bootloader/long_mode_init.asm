.intel_syntax noprefix

.global long_mode_start

.extern rust_start

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

    // call the rust start
    call rust_start

    // print `OKAY` to screen
    mov rax, 0x2F592F412F4B2F4F
    mov QWORD PTR [0xB8000], rax
    hlt
