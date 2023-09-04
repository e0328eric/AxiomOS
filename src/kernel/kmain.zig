const vga = @import("./vga.zig");

extern fn halt() noreturn;

export fn kmain() noreturn {
    main();
    halt();
}

fn main() void {
    vga.vgaInit(.White, .Black);
    vga.clearMonitor();
    vga.writeString("Hello, AxiomOS!");
}
