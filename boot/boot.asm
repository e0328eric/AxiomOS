;; The MIT License (MIT)
;;
;; Copyright (c) 2023 Sungbae Jeong
;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.
;;
;;
;; AxiomOS bootloader
;;
;; This code is almost stolen from follow links:
;; 1. https://os.phil-opp.com/multiboot-kernel/
;; 2. https://os.phil-opp.com/entering-longmode/

global start

%include "vga.asm"

%define MULTIBOOT_CHECK_MAGIC 0x36d76289

section .bss
stack_bottom:
    resb 16384
stack_top:

section .text
bits 32
start:
    mov esp, stack_top

    ;; Initialize VGA Terminal
    call terminal_initialize

    call check_multiboot
    call check_cpuid
    call check_long_mode

    ;; Printing a greet message
    mov edi, hello_msg
    call terminal_writestring
    call terminal_newline
    mov edi, successfully_enter_long_mode
    call terminal_writestring

    hlt
    jmp $

;; <INPUT>
;; al: error character
;; <NO OUTPUT>
error:
    push ax
    ;; set color to pink
    mov cl, VGA_COLOR_PINK
    mov dl, VGA_COLOR_BLACK
    call vga_entry_color
    mov cl, al
    call terminal_setcolor
    xor edi, edi
    mov esi, VGA_BUFFER_HEIGHT - 1
    call terminal_movecursor
    pop ax
    mov BYTE [error_msg + 5], al
    mov edi, error_msg
    call terminal_writestring
    hlt
    jmp $

;; <NO INPUT>
;; <NO OUTPUT>
check_multiboot:
    cmp eax, MULTIBOOT_CHECK_MAGIC
    jne check_multiboot.failed
    ret
check_multiboot.failed:
    mov al, '0'
    jmp error

;; stolen from https://wiki.osdev.org/Setting_Up_Long_Mode#Detection_of_CPUID
check_cpuid:
    ; Check if CPUID is supported by attempting to flip the ID bit (bit 21) in
    ; the FLAGS register. If we can flip it, CPUID is available.

    ; Copy FLAGS in to EAX via stack
    pushfd
    pop eax

    ; Copy to ECX as well for comparing later on
    mov ecx, eax

    ; Flip the ID bit
    xor eax, 1 << 21

    ; Copy EAX to FLAGS via the stack
    push eax
    popfd

    ; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
    pushfd
    pop eax

    ; Restore FLAGS from the old version stored in ECX (i.e. flipping the ID bit
    ; back if it was ever flipped).
    push ecx
    popfd

    ; Compare EAX and ECX. If they are equal then that means the bit wasn't
    ; flipped, and CPUID isn't supported.
    xor eax, ecx
    jz check_cpuid.failed
    ret
check_cpuid.failed:
    mov al, '1'
    jmp error

;; stolen from https://os.phil-opp.com/entering-longmode/
check_long_mode:
    ; test if extended processor info in available
    mov eax, 0x80000000             ; implicit argument for cpuid
    cpuid                           ; get highest supported argument
    cmp eax, 0x80000001             ; it needs to be at least 0x80000001
    jb check_long_mode.failed       ; if it's less, the CPU is too old for long mode

    ; use extended info to test if long mode is available
    mov eax, 0x80000001             ; argument for extended processor info
    cpuid                           ; returns various feature bits in ecx and edx
    test edx, 1 << 29               ; test if the LM-bit is set in the D-register
    jz check_long_mode.failed       ; If it's not set, there is no long mode
    ret
check_long_mode.failed:
    mov al, "2"
    jmp error


section .data
hello_msg: db "Hello to the AxiomOS.", 0
successfully_enter_long_mode:
    db "If this message was shown, this means that you are in the long mode!", 0
error_msg: db "ERR: ", 0, 0
