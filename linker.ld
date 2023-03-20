ENTRY(start)

SECTIONS {
    . = 1M; /* the code should be loaded at 1MB */

    .text : ALIGN(4K) {
        KEEP(*(.multiboot_header))
        *(.debug*)
        *(.comment)
        *(.text, .text*)
    }

    .rodata : {
        *(.rodata*)
    }

    .data : {
        *(.data)
    }

    .bss : {
        *(COMMON)
        *(.bss)
    }
}
