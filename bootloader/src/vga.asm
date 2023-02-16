##
## The MIT License (MIT)
##
## Copyright (c) 2023 Sungbae Jeong
##
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to deal
## in the Software without restriction, including without limitation the rights
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
##
## The above copyright notice and this permission notice shall be included in all
## copies or substantial portions of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
## SOFTWARE.
##
## fooOs vga.asm
##
## Utilities for VGA Buffer print
##
## This code is originally written in C and its code is in OSDev Bare Bone.
## I rewrite that C code into Assembly without using any converter.
##
## Link: https://wiki.osdev.org/Bare_Bones
##

## VGA Buffer pointer
.set VGA_BUFFER_START_PTR,    0xB8000

## VGA Buffer size
.set VGA_BUFFER_WIDTH,        80
.set VGA_BUFFER_HEIGHT,       25

## VGA Buffer colors
.set VGA_COLOR_BLACK,         0
.set VGA_COLOR_BLUE,          1
.set VGA_COLOR_GREEN,         2
.set VGA_COLOR_CYAN,          3
.set VGA_COLOR_RED,           4
.set VGA_COLOR_MAGENTA,       5
.set VGA_COLOR_BROWN,         6
.set VGA_COLOR_LIGHTGRAY,     7
.set VGA_COLOR_DARKGRAY,      8
.set VGA_COLOR_LIGHTBLUE,     9
.set VGA_COLOR_LIGHTGREEN,    10
.set VGA_COLOR_LIGHTCYAN,     11
.set VGA_COLOR_LIGHTRED,      12
.set VGA_COLOR_PINK,          13
.set VGA_COLOR_YELLOW,        14
.set VGA_COLOR_WHITE,         15

.section .text
.code32

## <INPUT>
## cl: foreground
## dl: background
## <OUTPUT>
## al: color info
vga_entry_color:
    xor ax, ax
    mov al, dl
    shl al, 4
    or  al, cl
    ret

## <INPUT>
## di: character
## si: color
## <OUTPUT>
## ax: entry_info
vga_entry:
    xor ax, ax
    mov ax, si
    shl ax, 8
    or  ax, di
    ret

## <INPUT>
## edi: string (must be NULL byte ended)
## <OUTPUT>
## eax: the length of the string without counting a null byte
cstrlen:
    push ecx
    xor  ecx, ecx
cstrlen.jmp:
    mov  ah, BYTE PTR [edi + ecx]
    test ah, ah
    jz   cstrlen.end
    inc  ecx
    jmp  cstrlen.jmp
cstrlen.end:
    mov  eax, ecx
    pop  ecx
    ret

## <INPUT>
## None
## <OUTPUT>
## None
terminal_initialize:
    pushad

    mov DWORD PTR [terminal_row], 0
    mov DWORD PTR [terminal_col], 0

    mov cl, VGA_COLOR_LIGHTGRAY
    mov dl, VGA_COLOR_BLACK
    call vga_entry_color
    mov BYTE PTR  [terminal_color], al

    xor ecx, ecx
    terminal_initialize.loop1.start:
        cmp ecx, VGA_BUFFER_HEIGHT
        jge terminal_initialize.loop1.end
        xor ebx, ebx
        terminal_initialize.loop2.start:
            cmp ebx, VGA_BUFFER_WIDTH
            jge terminal_initialize.loop2.end

            ## calculate edx <- ecx * VGA_BUFFER_WIDTH + ebx
            mov eax, ecx
            mov dx, VGA_BUFFER_WIDTH
            mul dx
            add eax, ebx
            mov dx, 2
            mul dx
            mov edx, eax

            mov di, ' '
            xor si, si
            xor ax, ax
            mov al, BYTE PTR [terminal_color]
            mov si, ax
            call vga_entry
            mov WORD PTR [VGA_BUFFER_START_PTR + edx], ax

            inc ebx
            jmp terminal_initialize.loop2.start
        terminal_initialize.loop2.end:
        inc ecx
        jmp terminal_initialize.loop1.start
    terminal_initialize.loop1.end:

    popad
    ret

## <INPUT>
## cl: terminal color
## <OUTPUT>
## None
terminal_setcolor:
    mov BYTE PTR [terminal_color], cl
    ret

## <INPUT>
## edi: x
## esi: y
## <OUTPUT>
## None
terminal_movecursor:
    mov DWORD PTR [terminal_col], edi
    mov DWORD PTR [terminal_row], esi
    ret

## <NO INPUT>
## <NO OUTPUT>
terminal_newline:
    push eax
    mov eax, DWORD PTR [terminal_row]
    inc eax
    cmp eax, VGA_BUFFER_HEIGHT
    jl terminal_newline.end
    xor eax, eax
terminal_newline.end:
    mov DWORD PTR [terminal_row], eax
    mov DWORD PTR [terminal_col], 0
    pop eax
    ret

## <INPUT>
## di:  character
## si:  color
## edx: x
## ecx: y
## <OUTPUT>
## None
terminal_putentryat:
    pushad
    push edx
    mov eax, ecx
    mov bx, VGA_BUFFER_WIDTH
    mul bx
    pop edx
    add eax, edx
    mov bx, 2
    mul bx
    mov ebx, eax
    call vga_entry
    mov WORD PTR [VGA_BUFFER_START_PTR + ebx], ax
    popad
    ret

## <INPUT>
## di: character
## <OUTPUT>
## None
terminal_putchar:
    pushad
    xor si, si
    xor ax, ax
    mov al, BYTE PTR [terminal_color]
    mov si, ax
    mov edx, DWORD PTR [terminal_col]
    mov ecx, DWORD PTR [terminal_row]
    call terminal_putentryat

    mov edx, DWORD PTR [terminal_col]
    inc edx
    mov DWORD PTR [terminal_col], edx
    cmp edx, VGA_BUFFER_WIDTH
    jne terminal_putchar.end

    mov DWORD PTR [terminal_col], 0
    mov ecx, DWORD PTR [terminal_row]
    inc ecx
    mov DWORD PTR [terminal_row], ecx
    cmp ecx, VGA_BUFFER_HEIGHT
    jne terminal_putchar.end
    mov DWORD PTR [terminal_row], 0
terminal_putchar.end:
    popad
    ret

## <INPUT>
## edi: string (NULL byte end free)
## esi: length of that string
## <OUTPUT>
## None
terminal_write:
    pushad
    xor ecx, ecx
    terminal_write.loop.start:
        cmp ecx, esi
        jge terminal_write.loop.end
        push edi
        xor ax, ax
        mov al, BYTE PTR [edi + ecx]
        mov di, ax
        call terminal_putchar
        pop edi
        inc ecx
        jmp terminal_write.loop.start
    terminal_write.loop.end:
    popad
    ret

## <INPUT>
## edi: string (must be NULL byte ended)
## <OUTPUT>
## None
terminal_writestring:
    pushad
    call cstrlen
    mov esi, eax
    call terminal_write
    popad
    ret

.section .bss
terminal_row:    .skip 4
terminal_col:    .skip 4
terminal_color:  .skip 1
