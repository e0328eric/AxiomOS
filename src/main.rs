#![feature(custom_test_frameworks)]
#![test_runner(crate::test_runner)]
#![reexport_test_harness_main = "test_main"]
#![allow(unused, bad_asm_style, clippy::empty_loop)]
#![warn(unsafe_op_in_unsafe_fn)]
#![no_std]
#![no_main]

mod error;
mod vga;

use core::arch::{asm, global_asm};
use core::fmt::{write, Write};
use core::panic;

use error::AxiomOsErr;

global_asm!(include_str!("./bootloader/multiboot2_header.asm"));
global_asm!(include_str!("./bootloader/boot.asm"));
global_asm!(include_str!("./bootloader/long_mode_init.asm"));

// actual main function of the OS
fn main(multiboot_info_addr: usize) -> error::Result<()> {
    let boot_info = unsafe { multiboot2::load(multiboot_info_addr)? };
    let memory_map_tag = boot_info
        .memory_map_tag()
        .ok_or(AxiomOsErr::CannotGetMemoryMapTag)?;

    println!("memory address:");
    for area in memory_map_tag.memory_areas() {
        println!(
            "    start: 0x{:x}, length: 0x{:x}",
            area.start_address(),
            area.size()
        );
    }

    let elf_sections_tag = boot_info
        .elf_sections_tag()
        .ok_or(AxiomOsErr::CannotGetElfSectionTag)?;

    println!("kernel sections:");
    for section in elf_sections_tag.sections() {
        println!(
            "    addr: 0x{:x}, size: 0x{:x}, flags: 0x{:x}",
            section.start_address(),
            section.size(),
            section.flags()
        );
    }

    println!("Hello, AxiomOS!");
    Ok(())
}

// entry point of the rust program from the bootloader
#[no_mangle]
extern "C" fn rust_start(multiboot_info_addr: usize) {
    let result = main(multiboot_info_addr);

    match result {
        Ok(()) => {}
        Err(err) => panic!("{err}"),
    }

    #[cfg(test)]
    test_main();

    loop {}
}

#[panic_handler]
fn panic(info: &panic::PanicInfo) -> ! {
    println!("\n{info}");
    loop {}
}

#[cfg(test)]
fn test_runner(tests: &[&dyn Fn()]) {
    println!("Running {} tests", tests.len());
    for test in tests {
        test();
    }
}

#[test_case]
fn trivial_assertion() {
    print!("trivial assertion... ");
    assert_eq!(1, 2);
    println!("[ok]");
}
