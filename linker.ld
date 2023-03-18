ENTRY(start)

SECTIONS {
    . = 1M; /* the code should be loaded at 1MB */

    .boot : {
        KEEP(*(.multiboot_header))
    }

    .text ALIGN (0x1000) : { /* align at 4KB */
        *(.text)
    }

    .rodata ALIGN (0x1000) : {
        *(.rodata*)
    }

    .data ALIGN (0x1000) : {
        *(.data)
    }

    .bss ALIGN (0x1000) : {
        *(COMMON)
        *(.bss)
    }
}
