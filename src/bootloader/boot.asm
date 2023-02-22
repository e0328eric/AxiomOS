// The MIT License (MIT)
//
// Copyright (c) 2023 Sungbae Jeong
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
//
// AxiomOS bootloader
//
// This code is almost stolen from follow links:
// 1. https://os.phil-opp.com/multiboot-kernel/
// 2. https://os.phil-opp.com/entering-longmode/

.intel_syntax noprefix

.global _start
.extern long_mode_start

.set MULTIBOOT_CHECK_MAGIC,   0x36D76289
.set CODE_SEGMENT_NUMBER,     0x20980000000000
.set GDT_DATA_NUMBER,         0x900000000000
.set CHECK_LONG_MODE_MAGIC_1, 0x80000000
.set CHECK_LONG_MODE_MAGIC_2, 0x80000001

.section .bss
.align 4096
p4_table:
    .skip 4096
p3_table:
    .skip 4096
p2_table:
    .skip 4096
.align 16
stack_bottom:
    .skip 16384
stack_top:

.section .text
.code32
_start:
    mov esp, offset stack_top

    call check_multiboot
    call check_cpuid
    call check_long_mode

    // setting up page tables
    call set_up_page_tables
    call enable_paging

    // load the 64-bit GDT
    lgdt [gdt64pointer]

.att_syntax
    jmp $CODE64_SEL,$long_mode_start
.intel_syntax noprefix

1:  hlt
    jmp 1b

// <INPUT>
// al: error character
// <NO OUTPUT>
// It prints `ERR: _` at the bottom left of the screen with pink background, black foreground
// If you want to change the color, change the value `D0` into something else.
error:
    mov DWORD PTR [0xB8F00], 0xD052D045
    mov DWORD PTR [0xB8F04], 0xD03AD052
    mov WORD PTR  [0xB8F08], 0xD020
    mov BYTE PTR  [0xB8F0A], al
    mov BYTE PTR  [0xB8F0B], 0xD0
1:  hlt
    jmp 1b

// <NO INPUT>
// <NO OUTPUT>
check_multiboot:
    cmp eax, MULTIBOOT_CHECK_MAGIC
    jne check_multiboot.failed
    ret
check_multiboot.failed:
    mov al, '0'
    jmp error

// stolen from https://wiki.osdev.org/Setting_Up_Long_Mode/Detection_of_CPUID
check_cpuid:
    // Check if CPUID is supported by attempting to flip the ID bit (bit 21) in
    // the FLAGS register. If we can flip it, CPUID is available.

    // Copy FLAGS in to EAX via stack
    pushfd
    pop eax

    // Copy to ECX as well for comparing later on
    mov ecx, eax

    // Flip the ID bit
    xor eax, 1 << 21

    // Copy EAX to FLAGS via the stack
    push eax
    popfd

    // Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
    pushfd
    pop eax

    // Restore FLAGS from the old version stored in ECX (i.e. flipping the ID bit
    // back if it was ever flipped).
    push ecx
    popfd

    // Compare EAX and ECX. If they are equal then that means the bit wasn't
    // flipped, and CPUID isn't supported.
    xor eax, ecx
    jz check_cpuid.failed
    ret
check_cpuid.failed:
    mov al, '1'
    jmp error

// stolen from https://os.phil-opp.com/entering-longmode/
check_long_mode:
    // test if extended processor info in available
    mov eax, CHECK_LONG_MODE_MAGIC_1    // implicit argument for cpuid
    cpuid                               // get highest supported argument
    cmp eax, CHECK_LONG_MODE_MAGIC_2    // it needs to be at least 0x80000001
    jb check_long_mode.failed           // if it's less, the CPU is too old for long mode

    // use extended info to test if     long mode is available
    mov eax, CHECK_LONG_MODE_MAGIC_2    // argument for extended processor info
    cpuid                               // returns various feature bits in ecx and edx
    test edx, 1 << 29                   // test if the LM-bit is set in the D-register
    jz check_long_mode.failed           // If it's not set, there is no long mode
    ret
check_long_mode.failed:
    mov al, '2'
    jmp error

set_up_page_tables:
    // map first P4 entry to P3 table
    mov eax, offset p3_table
    or eax, 0b11 // present + writable
    mov [p4_table], eax

    // map first P3 entry to P2 table
    mov eax, offset p2_table
    or eax, 0b11 // present + writable
    mov [p3_table], eax

    // map each P2 entry to a huge 2MiB page
    xor ecx, ecx
set_up_page_tables.map_p2_table:
    mov eax, 0x200000
    mul ecx
    or eax, 0b10000011 // present + writable + huge
    mov [p2_table + ecx * 8], eax // map ecx-th entry

    inc ecx                              // increase counter
    cmp ecx, 512                         // if counter == 512, the whole P2 table is mapped
    jne set_up_page_tables.map_p2_table  // else map the next entry
    ret

enable_paging:
    // load P4 to cr3 register (cpu uses this to access the P4 table)
    mov eax, p4_table
    mov cr3, eax

    // enable PAE-flag in cr4 (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    // set the long mode bit in the EFER MSR (model specific register)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    // enable paging in the cr0 register
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ret

.section .rodata
gdt64:
    .quad 0 // zero entry
gdt64code:
    .quad CODE_SEGMENT_NUMBER // code segment
gdt64data:
    .quad GDT_DATA_NUMBER
gdt64pointer:
    .word . - gdt64 - 1
    .quad gdt64

CODE64_SEL = gdt64code - gdt64
DATA64_SEL = gdt64data - gdt64
