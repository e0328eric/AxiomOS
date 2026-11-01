OUTPUT_FORMAT(elf64-x86-64)
ENTRY(_start)

PHDRS {
    text PT_LOAD FLAGS(5);
    rodata PT_LOAD FLAGS(4);
    data PT_LOAD FLAGS(6);
}

SECTIONS {
    . = 1M;
    .multiboot_header : ALIGN(8) {
        KEEP(*(.multiboot_header))
    } :text
    .text : ALIGN(16) {
        *(.text.boot)
        *(.text .text.*)
    } :text
    .rodata : ALIGN(4K) {
        *(.rodata .rodata.*)
    } :rodata
    .data : ALIGN(4K) {
        *(.data .data.*)
        *(.got .got.*)
    } :data
    .bss (NOLOAD) : ALIGN(4K) {
        *(COMMON)
        *(.bss .bss.*)
    } :data
    ASSERT(. < 0x40000000, "kernel exceeds the bootstrap identity mapping")
    /DISCARD/ : { *(.eh_frame*) *(.comment) *(.note*) }
}
