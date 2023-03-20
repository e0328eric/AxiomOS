const port = @import("./port/port.zig");

const FB_BUFFER_WIDTH = 80;
const FB_BUFFER_HEIGHT = 25;

pub const FBColorCode = enum(u4) {
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

pub const FBColor = packed struct {
    fg: FBColorCode,
    bg: FBColorCode,

    pub fn init(fg: FBColorCode, bg: FBColorCode) @This() {
        return .{ .fg = fg, .bg = bg };
    }
};

const FBChar = struct {
    char: u8,
    color: FBColor,
};

// fields for FrameBuffer
column_pos: u16,
row_pos: u16,
color: FBColor,
buffer: [*]volatile FBChar,
// END OF fields for FrameBuffer

pub const FrameBuffer = @This();
const Self = @This();

var frame_buffer: Self = .{
    .column_pos = 0,
    .row_pos = 0,
    .buffer = @intToPtr([*]volatile FBChar, 0x000B8000),
    .color = undefined,
};

pub fn coord(col: u16, row: u16) u16 {
    return (row * FB_BUFFER_WIDTH) + col;
}

pub fn getColumnPos(pos: u16) u16 {
    return pos % FB_BUFFER_WIDTH;
}

pub fn getRowPos(pos: u16) u16 {
    return pos / FB_BUFFER_WIDTH;
}

pub fn init(color: FBColor) void {
    frame_buffer.color = color;
}

pub fn writeChar(comptime at_cursor: bool, chr: u8) void {
    switch (chr) {
        // TODO: handle the case when write a character in `at_cursor` mode
        '\n' => if (!at_cursor) {
            newline();
        },
        else => {
            if (frame_buffer.column_pos >= FB_BUFFER_WIDTH) {
                newline();
            }

            if (!at_cursor) {
                frame_buffer.row_pos = FB_BUFFER_HEIGHT - 1;
            }
            frame_buffer.buffer[coord(frame_buffer.column_pos, frame_buffer.row_pos)] = .{
                .char = chr,
                .color = frame_buffer.color,
            };
            frame_buffer.column_pos += 1;
        },
    }

    // moveCursor(coord(frame_buffer.column_pos, frame_buffer.row_pos));
}

pub fn writeString(comptime at_cursor: bool, string: []const u8) void {
    for (string) |chr| {
        writeChar(at_cursor, chr);
    }
}

fn clearLine(row: u16) void {
    var i: u16 = 0;
    while (i < FB_BUFFER_WIDTH) : (i += 1) {
        frame_buffer.buffer[coord(i, row)] = .{ .char = ' ', .color = frame_buffer.color };
    }
}

fn newline() void {
    var i: u16 = FB_BUFFER_WIDTH;
    while (i < FB_BUFFER_WIDTH * FB_BUFFER_HEIGHT) : (i += 1) {
        frame_buffer.buffer[i - FB_BUFFER_WIDTH] = frame_buffer.buffer[i];
    }
    clearLine(FB_BUFFER_HEIGHT - 1);
    frame_buffer.column_pos = 0;
}

const FB_COMMAND_PORT = 0x3D4;
const FB_DATA_PORT = 0x3D5;
const FB_HIGH_BYTE_COMMAND = 14;
const FB_LOW_BYTE_COMMAND = 15;

// INFO: Reference: https://wiki.osdev.org/Text_Mode_Cursor
pub fn moveCursor(pos: u16) void {
    port.outb(FB_COMMAND_PORT, FB_LOW_BYTE_COMMAND);
    port.outb(FB_DATA_PORT, pos & 0x00FF);
    port.outb(FB_COMMAND_PORT, FB_HIGH_BYTE_COMMAND);
    port.outb(FB_DATA_PORT, (pos >> 8) & 0x00FF);

    frame_buffer.column_pos = getColumnPos(pos);
    frame_buffer.row_pos = getRowPos(pos);
}

// INFO: Reference: https://wiki.osdev.org/Text_Mode_Cursor
pub fn setCursorPos() void {
    var pos: u16 = 0;

    port.outb(FB_COMMAND_PORT, FB_LOW_BYTE_COMMAND);
    pos |= port.inb(FB_DATA_PORT);
    port.outb(FB_COMMAND_PORT, FB_HIGH_BYTE_COMMAND);
    pos |= port.inb(FB_DATA_PORT) << 8;

    frame_buffer.column_pos = getColumnPos(pos);
    frame_buffer.row_pos = getRowPos(pos);
}
