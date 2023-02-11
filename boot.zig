const std = @import("std");

comptime {
    asm (
        \\.set ALIGN,    1 << 0
        \\.set MEMINFO,  1 << 1
        \\.set FLAGS,    ALIGN | MEMINFO
        \\.set MAGIC,    0x1BADB002
        \\.set CHECKSUM, -(MAGIC + FLAGS)
        \\
        \\.section .multiboot
        \\.align 4
        \\.long MAGIC
        \\.long FLAGS
        \\.long CHECKSUM
        \\
        \\.section .bss
        \\.align 16
        \\stack_bottom:
        \\.skip 16384
        \\stack_top:
    );
}

export fn _start() callconv(.Naked) noreturn {
    asm volatile ("mov $stack_top, %esp");

    kernelMain();

    fail();
}

fn fail() noreturn {
    asm volatile (
        \\    cli
        \\spin:
        \\    hlt
        \\    jmp spin
    );
    unreachable;
}

fn kernelMain() void {
    terminalInitialize();
    terminalWriteString("Hello, World!\x00");
}

const VgaColor = enum(u8) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_grey = 7,
    dark_grey = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    light_brown = 14,
    white = 15,
};

inline fn vgaEntryColor(fg: VgaColor, bg: VgaColor) u8 {
    return @enumToInt(fg) | @enumToInt(bg) << 4;
}

inline fn vgaEntry(uc: u8, color: u8) u16 {
    return @intCast(u16, uc) | @intCast(u16, color) << 8;
}

const VGA_WIDTH: usize = 80;
const VGA_HEIGHT: usize = 25;

const Terminal = packed struct {
    row: usize,
    col: usize,
    color: u8,
    buffer: [*]u16,
};

var terminal: Terminal = undefined;

fn terminalInitialize() void {
    terminal.row = 0;
    terminal.col = 0;
    terminal.color = vgaEntryColor(.light_grey, .black);
    terminal.buffer = @intToPtr([*]u16, 0xB8000);

    var y: usize = 0;
    while (y < VGA_HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            const index = y * VGA_WIDTH + x;
            terminal.buffer[index] = vgaEntry(' ', terminal.color);
        }
    }
}

fn terminalSetColor(color: u8) void {
    terminal.color = color;
}

fn terminalPutEntryAt(c: u8, color: u8, x: usize, y: usize) void {
    const index = y * VGA_WIDTH + x;
    terminal.buffer[index] = vgaEntry(c, color);
}

fn terminalPutChar(c: u8) void {
    terminalPutEntryAt(c, terminal.color, terminal.col, terminal.row);

    terminal.col += 1;
    if (terminal.col == VGA_WIDTH) {
        terminal.col = 0;
        terminal.row += 1;
        if (terminal.row == VGA_HEIGHT) {
            terminal.row = 0;
        }
    }
}

fn terminalWriteString(data: [*:0]const u8) void {
    const data_len = std.mem.len(data);

    var i: usize = 0;
    while (i < data_len) : (i += 1) {
        terminalPutChar(data[i]);
    }
}
