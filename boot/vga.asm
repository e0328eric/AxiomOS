;;
;; fooOs vga.asm
;;
;; Utilities for VGA Buffer print
;;

;; VGA Buffer pointer
%define VGA_BUFFER_START_PTR    0xB8000

;; VGA Buffer size
%define VGA_BUFFER_WIDTH        80
%define VGA_BUFFER_HEIGHT       25

;; VGA Buffer colors
%define VGA_COLOR_BLACK         0
%define VGA_COLOR_BLUE          1
%define VGA_COLOR_GREEN         2
%define VGA_COLOR_CYAN          3
%define VGA_COLOR_RED           4
%define VGA_COLOR_MAGENTA       5
%define VGA_COLOR_BROWN         6
%define VGA_COLOR_LIGHTGRAY     7
%define VGA_COLOR_DARKGRAY      8
%define VGA_COLOR_LIGHTBLUE     9
%define VGA_COLOR_LIGHTGREEN    10
%define VGA_COLOR_LIGHTCYAN     11
%define VGA_COLOR_LIGHTRED      12
%define VGA_COLOR_PINK          13
%define VGA_COLOR_YELLOW        14
%define VGA_COLOR_WHITE         15

section .text
bits 32

;; <INPUT>
;; cl: foreground
;; dl: background
;; <OUTPUT>
;; al: color info
vga_entry_color:
    xor ax, ax
    mov al, dl
    shl al, 4
    or  al, cl
    ret

;; <INPUT>
;; di: character
;; si: color
;; <OUTPUT>
;; ax: entry_info
vga_entry:
    xor ax, ax
    mov ax, si
    shl ax, 8
    or  ax, di
    ret

;; <INPUT>
;; edi: string (must be NULL byte ended)
;; <OUTPUT>
;; eax: the length of the string without counting a null byte
cstrlen:
    push ecx
    xor  ecx, ecx
cstrlen.jmp:
    mov  ah, BYTE [edi + ecx]
    test ah, ah
    jz   cstrlen.end
    inc  ecx
    jmp  cstrlen.jmp
cstrlen.end:
    mov  eax, ecx
    pop  ecx
    ret

;; <INPUT>
;; None
;; <OUTPUT>
;; None
terminal_initialize:
    pushad

    mov DWORD [terminal_row], 0
    mov DWORD [terminal_col], 0

    mov cl, VGA_COLOR_LIGHTGRAY
    mov dl, VGA_COLOR_BLACK
    call vga_entry_color
    mov BYTE  [terminal_color], al

    xor ecx, ecx
terminal_initialize.loop1.start:
    cmp ecx, VGA_BUFFER_HEIGHT
    jge terminal_initialize.loop1.end
    xor ebx, ebx
terminal_initialize.loop2.start:
    cmp ebx, VGA_BUFFER_WIDTH
    jge terminal_initialize.loop2.end

    ;; calculate edx <- ecx * VGA_BUFFER_WIDTH + ebx
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
    mov al, BYTE [terminal_color]
    mov si, ax
    call vga_entry
    mov WORD [VGA_BUFFER_START_PTR + edx], ax

    inc ebx
    jmp terminal_initialize.loop2.start
terminal_initialize.loop2.end:
    inc ecx
    jmp terminal_initialize.loop1.start
terminal_initialize.loop1.end:

    popad
    ret

;; <INPUT>
;; cl: terminal color
;; <OUTPUT>
;; None
terminal_setcolor:
    mov BYTE [terminal_color], cl
    ret

;; <INPUT>
;; di:  character
;; si:  color
;; edx: x
;; ecx: y
;; <OUTPUT>
;; None
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
    mov WORD [VGA_BUFFER_START_PTR + ebx], ax
    popad
    ret

;; <INPUT>
;; di: character
;; <OUTPUT>
;; None
terminal_putchar:
    pushad
    xor si, si
    xor ax, ax
    mov al, BYTE [terminal_color]
    mov si, ax
    mov edx, DWORD [terminal_col]
    mov ecx, DWORD [terminal_row]
    call terminal_putentryat

    mov edx, DWORD [terminal_col]
    inc edx
    mov DWORD [terminal_col], edx
    cmp edx, VGA_BUFFER_WIDTH
    jne terminal_putchar.end

    mov DWORD [terminal_col], 0
    mov ecx, DWORD [terminal_row]
    inc ecx
    mov DWORD [terminal_row], ecx
    cmp ecx, VGA_BUFFER_HEIGHT
    jne terminal_putchar.end
    mov DWORD [terminal_row], 0
terminal_putchar.end:
    popad
    ret

;; <INPUT>
;; edi: string (NULL byte end free)
;; esi: length of that string
;; <OUTPUT>
;; None
terminal_write:
    pushad
    xor ecx, ecx
terminal_write.loop.start:
    cmp ecx, esi
    jge terminal_write.loop.end
    push edi
    xor ax, ax
    mov al, BYTE [edi + ecx]
    mov di, ax
    call terminal_putchar
    pop edi
    inc ecx
    jmp terminal_write.loop.start
terminal_write.loop.end:
    popad
    ret

;; <INPUT>
;; edi: string (must be NULL byte ended)
;; <OUTPUT>
;; None
terminal_writestring:
    pushad
    call cstrlen
    mov esi, eax
    call terminal_write
    popad
    ret

section .bss
terminal_row:    resd 1
terminal_col:    resd 1
terminal_color:  resb 1
