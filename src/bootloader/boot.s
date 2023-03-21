.extern long_mode_start
.globl start
.globl halt

.set KERNEL_STACK_SIZE, 4096

.section .bss
.align 4096
p4_table:
    .skip 4096
p3_table:
    .skip 4096
p2_table:
    .skip 4096
stack_bottom:
    .skip 16384
stack_top:

.section .text
.code32
.type start, @function
start:
    mov $stack_top, %esp

    call check_multiboot
    call check_cpuid
    call check_long_mode

    call set_up_page_tables
    call enable_paging

    lgdtl gdt64_pointer
    jmp $gdt64_code, $long_mode_start

    call halt

check_multiboot:
    cmp $0x36D76289, %eax
    jne _multiboot_check_failed
    ret
_multiboot_check_failed:
    mov $'0', %al
    jmp _print_error

check_cpuid:
    pushfd
    pop %eax
    mov %eax, %ecx

    // Flip the ID bit
    xor $(1 << 21), %eax
    push %eax
    popfd

    pushfd
    pop %eax

    push %ecx
    popfd

    cmp %ecx, %eax
    je _no_cpuid
    ret
_no_cpuid:
    mov $'1', %al
    jmp _print_error

check_long_mode:
    mov $0x80000000, %eax
    cpuid
    cmp $0x80000001, %eax
    jb _no_long_mode

    mov $0x80000001, %eax
    cpuid
    test $(1 << 29), %edx
    jz _no_long_mode
    ret
_no_long_mode:
    mov $'2', %al
    jmp _print_error

set_up_page_tables:
    mov $p3_table, %eax
    or $0b11, %eax // present + writable
    mov %eax, p4_table

    mov $p2_table, %eax
    or $0b11, %eax // present + writable
    mov %eax, p3_table

    xor %ecx, %ecx
_map_p2_table:
    mov $0x200000, %eax
    mul %ecx
    or $0b10000011, %eax // present + writable + huge
    mov %eax, p2_table(, %ecx, 8)
    inc %ecx
    cmp $512, %ecx
    jne _map_p2_table

    ret

enable_paging:
    mov $p4_table, %eax
    mov %eax, %cr3

    mov %cr4, %eax
    or $(1 << 5), %eax
    mov %eax, %cr4

    mov $0xC0000080, %ecx
    rdmsr
    or $(1 << 8), %eax
    wrmsr

    mov %cr0, %eax
    or $(1 << 31), %eax
    mov %eax, %cr0

    ret

_print_error:
    movl $0x4F524F45, 0xB8000
    movl $0x4F3A4F52, 0xB8004
    movl $0x4F204F20, 0xB8008
    movb %al, 0xB800A

halt:
    hlt
    jmp halt

.section .rodata
gdt64:
    .quad 0
.equ gdt64_code, . - gdt64
    .quad 0x20980000000000
gdt64_pointer:
    .word . - gdt64 - 1
    .quad gdt64
