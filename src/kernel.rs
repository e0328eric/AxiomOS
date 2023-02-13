use core::mem::MaybeUninit;
use core::ptr::addr_of_mut;

#[allow(dead_code)]
#[repr(u8)]
#[derive(Clone, Copy, PartialEq, Eq)]
enum VgaColor {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGrey = 7,
    DarkGrey = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    LightBrown = 14,
    White = 15,
}

#[inline]
fn vga_entry_color(fg: VgaColor, bg: VgaColor) -> u8 {
    fg as u8 | (bg as u8) << 4
}

#[inline]
fn vga_entry(uc: u8, color: u8) -> u16 {
    uc as u16 | (color as u16) << 8
}

const VGA_WIDTH: usize = 80;
const VGA_HEIGHT: usize = 25;

#[repr(C)]
#[derive(Clone, Copy)]
pub struct Terminal {
    row: usize,
    col: usize,
    color: u8,
    buffer: *mut u16,
}

impl Terminal {
    pub fn new() -> Self {
        let mut terminal = unsafe {
            let mut terminal = MaybeUninit::<Terminal>::uninit();
            let ptr = terminal.as_mut_ptr();

            addr_of_mut!((*ptr).row).write(0);
            addr_of_mut!((*ptr).col).write(0);
            addr_of_mut!((*ptr).color).write(vga_entry_color(VgaColor::LightGrey, VgaColor::Black));
            addr_of_mut!((*ptr).buffer).write(0xB8000 as *mut _);

            terminal.assume_init()
        };

        for y in 0..VGA_HEIGHT {
            for x in 0..VGA_WIDTH {
                let index = y * VGA_WIDTH + x;
                unsafe {
                    *terminal.buffer.add(index) = vga_entry(b' ', terminal.color);
                }
            }
        }

        terminal
    }

    #[inline]
    fn set_color(&mut self, color: u8) {
        self.color = color;
    }

    fn put_entry_at(&self, c: u8, color: u8, x: usize, y: usize) {
        let index = y * VGA_WIDTH + x;
        unsafe {
            *self.buffer.add(index) = vga_entry(c, color);
        }
    }

    fn put_char(&mut self, c: u8) {
        self.put_entry_at(c, self.color, self.col, self.row);

        self.col += 1;
        if self.col == VGA_WIDTH {
            self.col = 0;
            self.row += 1;
            if self.row == VGA_HEIGHT {
                self.row = 0;
            }
        }
    }

    pub fn write_string(&mut self, s: &[u8]) {
        for i in 0..s.len() {
            self.put_char(s[i]);
        }
    }
}
