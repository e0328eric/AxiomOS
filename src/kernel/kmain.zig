const FrameBuffer = @import("./FrameBuffer.zig");

export fn kmain() callconv(.Naked) c_int {
    FrameBuffer.init(FrameBuffer.FBColor.init(.White, .Black));
    FrameBuffer.writeString(false, "Hello, AxiomOS!\n");
    FrameBuffer.writeString(false, "Newline Works");
    FrameBuffer.moveCursor(FrameBuffer.coord(40, 12));

    return 0;
}
