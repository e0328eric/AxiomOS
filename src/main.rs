#![allow(unused, bad_asm_style, clippy::empty_loop)]
#![no_std]
#![no_main]

mod vga;

use core::arch::{asm, global_asm};
use core::fmt::{write, Write};
use core::panic;

use vga::WRITER;

global_asm!(include_str!("./bootloader/multiboot2_header.asm"));
global_asm!(include_str!("./bootloader/boot.asm"));
global_asm!(include_str!("./bootloader/long_mode_init.asm"));

#[no_mangle]
extern "C" fn rust_main() {
    print!("Hello, AxiomOS!");

    loop {}
}

#[panic_handler]
fn panic(info: &panic::PanicInfo) -> ! {
    println!("\n{info}");
    loop {}
}
