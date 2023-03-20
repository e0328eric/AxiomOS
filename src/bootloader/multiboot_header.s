.section .multiboot_header
header_start:
    .long 0xE85250D6
    .long 0
    .long header_end - header_start
    .long 0x100000000 - (0XE85250D6 + 0 + (header_end - header_start))

    // insert optional multiboot tags here

    // required end tag
    .short 0 // tag
    .short 0 // flags
    .long  8 // size
header_end:
