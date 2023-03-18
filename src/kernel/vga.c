#include "vga.h"

static volatile char* vga_buffer = (char*)0x000B8000;

void fb_write_cell(unsigned int i, char c, unsigned char fg, unsigned char bg) {
    vga_buffer[i] = c;
    vga_buffer[i + 1] = ((bg & 0x0F) << 4) | (fg & 0x0F);
}
