const Vga = @import("./Vga.zig");

extern fn halt() noreturn;

export fn kmain() noreturn {
    main() catch unreachable;
    halt();
}

fn main() !void {
    var vga = Vga.init(.White, .Black);
    vga.clearMonitor();

    const vga_writer = vga.writer();
    try vga_writer.print("Hello, AxiomOS!\n", .{});

    for (0..10000) |i| {
        try vga_writer.print("Here is a number {}, and the next is {}.\n", .{
            i,
            i + 1,
        });
        sleep(1000);
    }
}

fn sleep(tick: usize) void {
    const tickk = tick * 25000;
    for (0..tickk) |_| {}
}
