#![allow(unused, bad_asm_style, clippy::empty_loop)]
#![no_std]
#![no_main]

use core::arch::{asm, global_asm};
use core::panic;

global_asm!(include_str!("./bootloader/multiboot2_header.asm"));
global_asm!(include_str!("./bootloader/boot.asm"));
global_asm!(include_str!("./bootloader/long_mode_init.asm"));

#[no_mangle]
extern "C" fn rust_main() {
    // ATTENTION: we have a very small stack and no guard page

    let hello = b"Hello World!";
    let color_byte = 0x1f; // white foreground, blue background

    let mut hello_colored = [color_byte; 24];
    for (i, char_byte) in hello.iter().enumerate() {
        hello_colored[i * 2] = *char_byte;
    }

    // write `Hello World!` to the center of the VGA text buffer
    let buffer_ptr = (0xb8000 + 1988) as *mut _;
    unsafe { *buffer_ptr = hello_colored };

    loop {}
}

#[panic_handler]
fn panic(_info: &panic::PanicInfo) -> ! {
    loop {}
}

