#![no_std]
#![no_main]

mod kernel;

#[no_mangle]
extern "C" fn _start() -> ! {
    loop {}
}

#[panic_handler]
fn panic(_info: &panic::PanicInfo) -> ! {
    loop {}
}
