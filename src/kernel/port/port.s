.globl outb
.globl inb

.section .text
outb:
    mov 8(%esp), %al
    mov 4(%esp), %dx
    out %al, %dx
    ret

inb:
    mov 4(%esp), %dx
    in %dx, %al
    ret
