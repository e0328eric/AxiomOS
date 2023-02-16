#![allow(unused)]
#![no_std]
#![no_main]

use core::arch::{asm, global_asm};
use core::panic;

global_asm!(include_str!("./multiboot2_header.asm"));
global_asm!(include_str!("./boot.asm"));

#[no_mangle]
extern "C" fn rust_main() {}

#[panic_handler]
fn panic(_info: &panic::PanicInfo) -> ! {
    loop {}
}
