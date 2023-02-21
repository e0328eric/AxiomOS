.set MAGIC_NUMBER, 0xE85250D6
.set ARCH_NUMBER,  0 // for i386. If you want to use multiboot2 in MIPS, change this into 4

// <<A Multiboot2 header>>
//
// In the checksum part, there is a trick hidden for compiler to slient.
// Since the actual checksum formula is -(magic + arch + header_len), and since this number
// does not fit into 32bit unsigned integer, subtracting from 2^32 makes value unchanged and fit
// into 32bit unsigned integer.
.section .multiboot
.align 8
header_start:
    .long MAGIC_NUMBER
    .long ARCH_NUMBER
    .long header_end - header_start // header length
    .long 0x100000000 - (MAGIC_NUMBER + ARCH_NUMBER + (header_end - header_start)) // checksum

    // insert optional multiboot header here

    // required end tag
    .word  0 // type
    .word  0 // flags
    .long  8 // size
header_end:
