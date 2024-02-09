const std = @import("std");
const port = @import("./port.zig");

const io = std.io;

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

cursor_x: u16,
cursor_y: u16,
color: VgaColor,
buffer: [*]volatile VgaChar,

const Self = @This();
const WriteError = error{};
const Writer = io.GenericWriter(*Self, WriteError, write);
const VGA_BUFFER_ADDR = 0xB8000;

pub fn init(fg: VgaColorCode, bg: VgaColorCode) Self {
    return Self{
        .cursor_x = 0,
        .cursor_y = 0,
        .color = VgaColor.init(fg, bg),
        .buffer = @as([*]volatile VgaChar, @ptrFromInt(VGA_BUFFER_ADDR)),
    };
}

fn moveCursor(self: Self) void {
    const cursor_location = self.cursor_y * VGA_BUFFER_WIDTH + self.cursor_x;
    port.outb(0x3D4, 14);
    port.outb(0x3D5, @intCast(cursor_location >> 8 & 0xFF));
    port.outb(0x3D4, 15);
    port.outb(0x3D5, @intCast(cursor_location & 0xFF));
}

fn scroll(self: *Self) void {
    const blank = VgaChar{ .char = ' ', .color = VgaColor.init(.White, .Black) };

    if (self.cursor_y >= VGA_BUFFER_HEIGHT) {
        var i: usize = 0;
        while (i < (VGA_BUFFER_HEIGHT - 1) * VGA_BUFFER_WIDTH) : (i += 1) {
            self.buffer[i] = self.buffer[i + VGA_BUFFER_WIDTH];
        }

        while (i < VGA_BUFFER_HEIGHT * VGA_BUFFER_WIDTH) : (i += 1) {
            self.buffer[i] = blank;
        }

        self.cursor_y = VGA_BUFFER_HEIGHT - 1;
    }
}

pub fn writer(self: *Self) Writer {
    return .{ .context = self };
}

pub fn writeChar(self: *Self, chr: u8) void {
    // Handle a backspace, by moving the cursor back one space
    if (chr == 0x08 and self.cursor_x > 0) {
        self.cursor_x -= 1;
    }
    // Handle a tab by increasing the cursor's X, but only to a point where it is divisible by 4
    else if (chr == 0x09) {
        self.cursor_x = (self.cursor_x + 4) & ~@as(u8, 3);
    }
    // Handle carriage return
    else if (chr == '\r') {
        self.cursor_x = 0;
    }
    // Handle newline by moving cursor back to left and increasing the row
    else if (chr == '\n') {
        self.cursor_x = 0;
        self.cursor_y += 1;
    }
    // Handle any other printable character.
    else if (chr >= ' ') {
        self.buffer[self.cursor_y * VGA_BUFFER_WIDTH + self.cursor_x] = .{
            .char = chr,
            .color = self.color,
        };
        self.cursor_x += 1;
    }

    // Check if we need to insert a new line because we have reached the end
    if (self.cursor_x >= VGA_BUFFER_WIDTH) {
        self.cursor_x = 0;
        self.cursor_y += 1;
    }

    self.scroll();
    self.moveCursor();
}

pub fn write(self: *Self, str: []const u8) WriteError!usize {
    var write_len: usize = 0;
    for (str) |chr| {
        self.writeChar(chr);
        write_len += 1;
    }

    return write_len;
}

pub fn clearMonitor(self: *Self) void {
    const blank = VgaChar{ .char = ' ', .color = VgaColor.init(.White, .Black) };
    var i: usize = 0;
    while (i < VGA_BUFFER_WIDTH * VGA_BUFFER_HEIGHT) : (i += 1) {
        self.buffer[i] = blank;
    }

    self.cursor_x = 0;
    self.cursor_y = 0;
    self.moveCursor();
}
