const vga = @import("./vga.zig");

extern fn halt() noreturn;

export fn kmain() noreturn {
    main();
    halt();
}

fn main() void {
    vga.vgaInit(.White, .Black);
    vga.clearMonitor();
    vga.print("Hello, AxiomOS!\nHere is a number {}.", .{32});
}
