%define MAGIC_NUMBER 0xE85250D6
%define ARCH_NUMBER  0 ;; for i386. If you want to use multiboot2 in MIPS, change this into 4

;; <<A Multiboot2 header>>
;;
;; In the checksum part, there is a trick hidden for compiler to slient.
;; Since the actual checksum formula is -(magic + arch + header_len), and since this number
;; does not fit into 32bit unsigned integer, subtracting from 2^32 makes value unchanged and fit
;; into 32bit unsigned integer.
section .multiboot
header_start:
    dd MAGIC_NUMBER
    dd ARCH_NUMBER
    dd header_end - header_start ; header length
    dd 0x100000000 - (MAGIC_NUMBER + ARCH_NUMBER + (header_end - header_start)) ; checksum

    ; insert optional multiboot header here

    ; required end tag
    dw 0 ; type
    dw 0 ; flags
    dd 8 ; size
header_end:
