#include "framebuffer.h"
#include "utility.h"

int kmain(void) {
    fb_write_cell(0, 'A', FB_COLOR_WHITE, FB_COLOR_BLACK);
    fb_write(COORDINATE(0, 3), "Hello, World!", FB_COLOR_WHITE, FB_COLOR_BLACK);
    fb_move_cursor(COORDINATE(40, 12));

    uint16_t cursor_pos = fb_get_cursor_pos();
    fb_write_cell(cursor_pos, 'T', FB_COLOR_LIGHT_MAGENTA, FB_COLOR_DARK_GREY);

    return 0;
}
