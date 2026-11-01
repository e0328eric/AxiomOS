; Multiboot2 enters in protected mode. Glosso's function-level inline asm
; cannot provide a naked 32-bit entry in a 64-bit translation unit, so only
; the Multiboot header and mode transition live in this fasm ELF64 object.
format ELF64
public _start
extrn glo_kmain

section '.multiboot_header' align 8
header_start:
    dd 0xE85250D6, 0
    dd header_end - header_start
    dd -(0xE85250D6 + header_end - header_start)
    dw 0, 0
    dd 8
header_end:

section '.bss' writeable align 4096
p4_table: rb 4096
p3_table: rb 4096
p2_table: rb 4096
stack_bottom: rb 65536
stack_top:

section '.text.boot' executable align 16
use32
_start:
    cli
    cld
    mov esp, stack_top
    cmp eax, 0x36D76289
    jne bad_multiboot

    ; Test CPUID availability without assuming the ID bit starts clear.
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 shl 21
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    cmp eax, ecx
    je bad_cpuid

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb bad_long_mode
    mov eax, 0x80000001
    cpuid
    test edx, 1 shl 29
    jz bad_long_mode

    ; Identity-map the first GiB with 512 two-MiB pages. Explicitly clear
    ; all high halves and unused entries before enabling paging.
    mov edi, p4_table
    xor eax, eax
    mov ecx, 3 * 4096 / 4
    rep stosd
    mov eax, p3_table
    or eax, 3
    mov [p4_table], eax
    mov eax, p2_table
    or eax, 3
    mov [p3_table], eax
    xor ecx, ecx
.map_page:
    mov eax, ecx
    shl eax, 21
    or eax, 0x83
    mov [p2_table + ecx * 8], eax
    inc ecx
    cmp ecx, 512
    jne .map_page

    mov eax, p4_table
    mov cr3, eax
    mov eax, cr4
    ; PAE, OSFXSR and OSXMMEXCPT: LLVM may use baseline SSE2 for copies.
    or eax, (1 shl 5) or (1 shl 9) or (1 shl 10)
    mov cr4, eax
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 shl 8
    wrmsr
    mov eax, cr0
    and eax, not ((1 shl 2) or (1 shl 3)) ; clear EM and TS
    or eax, (1 shl 31) or (1 shl 1)      ; paging and MP
    mov cr0, eax
    lgdt [gdt64_pointer]
    jmp 0x08:long_mode_start

bad_multiboot:
    mov al, '0'
    jmp boot_error
bad_cpuid:
    mov al, '1'
    jmp boot_error
bad_long_mode:
    mov al, '2'
boot_error:
    mov dword [0xB8000], 0x4F524F45
    mov dword [0xB8004], 0x4F3A4F52
    mov word [0xB8008], 0x4F20
    mov byte [0xB800A], al
    mov byte [0xB800B], 0x4F
    out 0xE9, al
.halt:
    hlt
    jmp .halt

use64
long_mode_start:
    mov ax, 0x10
    mov ss, ax
    mov ds, ax
    mov es, ax
    xor eax, eax
    mov fs, ax
    mov gs, ax
    mov rsp, stack_top
    xor ebp, ebp
    fninit
    call glo_kmain
.halt:
    cli
    hlt
    jmp .halt

section '.rodata.boot' align 8
gdt64:
    dq 0
    dq 0x00AF9A000000FFFF ; 64-bit code
    dq 0x00CF92000000FFFF ; data
gdt64_end:
gdt64_pointer:
    dw gdt64_end - gdt64 - 1
    dd gdt64

section '.note.GNU-stack'
