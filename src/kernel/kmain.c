
#include "vga.h"

int kmain(void) {
    fb_write_cell(0, 'A', VGA_COLOR_WHITE, VGA_COLOR_BLACK);

    return 0;
}
