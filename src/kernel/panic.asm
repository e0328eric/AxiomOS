global raise_error

section .text
raise_error:
    mov al, [esp + 4]
    mov DWORD [0xB8F00], 0xD052D045
    mov DWORD [0xB8F04], 0xD03AD052
    mov WORD  [0xB8F08], 0xD020
    mov BYTE  [0xB8F0A], al
    mov BYTE  [0xB8F0B], 0xD0
    hlt
    jmp $
