#include "framebuffer.h"
#include "utility.h"

int kmain(void) {
    fb_write_cell(0, 'A', FB_COLOR_WHITE, FB_COLOR_BLACK);
    fb_write(COORDINATE(0, 3), "Hello, World!", FB_COLOR_WHITE, FB_COLOR_BLACK);
    fb_move_cursor(COORDINATE(40, 12));

    return 0;
}
