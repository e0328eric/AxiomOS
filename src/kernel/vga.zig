const std = @import("std");
const port = @import("./port.zig");

const VGA_BUFFER_WIDTH = 80;
const VGA_BUFFER_HEIGHT = 25;

pub const VgaColorCode = enum(u4) {
    Black = 0,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGrey,
    DarkGrey,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    LightMagenta,
    LightBrown,
    White,
};

pub const VgaColor = packed struct {
    fg: VgaColorCode,
    bg: VgaColorCode,

    pub fn init(fg: VgaColorCode, bg: VgaColorCode) @This() {
        return .{ .fg = fg, .bg = bg };
    }
};

const VgaChar = struct {
    char: u8,
    color: VgaColor,
};

const Vga = struct {
    cursor_x: u16,
    cursor_y: u16,
    color: VgaColor,
    buffer: [*]volatile VgaChar,
};

var vga = Vga{
    .cursor_x = 0,
    .cursor_y = 0,
    .color = undefined,
    .buffer = @as([*]volatile VgaChar, @ptrFromInt(0x000B8000)),
};

pub fn vgaInit(fg: VgaColorCode, bg: VgaColorCode) void {
    vga.color = VgaColor.init(fg, bg);
}

fn moveCursor() void {
    const cursor_location = vga.cursor_y * VGA_BUFFER_WIDTH + vga.cursor_x;
    port.outb(0x3D4, 14);
    port.outb(0x3D5, @intCast(cursor_location >> 8 & 0xFF));
    port.outb(0x3D4, 15);
    port.outb(0x3D5, @intCast(cursor_location & 0xFF));
}

fn scroll() void {
    const blank = VgaChar{ .char = ' ', .color = VgaColor.init(.White, .Black) };

    if (vga.cursor_y >= VGA_BUFFER_HEIGHT) {
        var i: usize = 0;
        while (i < (VGA_BUFFER_HEIGHT - 1) * VGA_BUFFER_WIDTH) : (i += 1) {
            vga.buffer[i] = vga.buffer[i + VGA_BUFFER_WIDTH];
        }

        while (i < VGA_BUFFER_HEIGHT * VGA_BUFFER_WIDTH) : (i += 1) {
            vga.buffer[i] = blank;
        }

        vga.cursor_y = VGA_BUFFER_HEIGHT - 1;
    }
}

pub fn writeChar(chr: u8) void {
    // Handle a backspace, by moving the cursor back one space
    if (chr == 0x08 and vga.cursor_x > 0) {
        vga.cursor_x -= 1;
    }
    // Handle a tab by increasing the cursor's X, but only to a point where it is divisible by 4
    else if (chr == 0x09) {
        vga.cursor_x = (vga.cursor_x + 4) & ~@as(u8, 4 - 1);
    }
    // Handle carriage return
    else if (chr == '\r') {
        vga.cursor_x = 0;
    }
    // Handle newline by moving cursor back to left and increasing the row
    else if (chr == '\n') {
        vga.cursor_x = 0;
        vga.cursor_y += 1;
    }
    // Handle any other printable character.
    else if (chr >= ' ') {
        vga.buffer[vga.cursor_y * VGA_BUFFER_WIDTH + vga.cursor_x] = .{
            .char = chr,
            .color = vga.color,
        };
        vga.cursor_x += 1;
    }

    // Check if we need to insert a new line because we have reached the end
    if (vga.cursor_x >= VGA_BUFFER_WIDTH) {
        vga.cursor_x = 0;
        vga.cursor_y += 1;
    }

    scroll();
    moveCursor();
}

pub fn clearMonitor() void {
    const blank = VgaChar{ .char = ' ', .color = VgaColor.init(.White, .Black) };
    var i: usize = 0;
    while (i < VGA_BUFFER_WIDTH * VGA_BUFFER_HEIGHT) : (i += 1) {
        vga.buffer[i] = blank;
    }

    vga.cursor_x = 0;
    vga.cursor_y = 0;
    moveCursor();
}

pub fn writeString(str: []const u8) void {
    for (str) |chr| {
        writeChar(chr);
    }
}

pub fn print(comptime fmt: []const u8, args: anytype) void {
    writeString(std.fmt.comptimePrint(fmt, args));
}
