pub fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [port] "{dx}" (port),
          [value] "{al}" (value),
    );
}

pub fn inb(port: u16) u8 {
    return asm volatile ("inb %[ret], %[port]"
        : [ret] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

pub fn inw(port: u16) u16 {
    return asm volatile ("inw %[ret], %[port]"
        : [ret] "={ax}" (-> u16),
        : [port] "{dx}" (port),
    );
}
