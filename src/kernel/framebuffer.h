#pragma once

#include "numtypes.h"

enum {
    FB_WIDTH = 80,
    FB_HEIGHT = 25,
};

// framebuffer colors
enum {
    FB_COLOR_BLACK = 0,
    FB_COLOR_BLUE,
    FB_COLOR_GREEN,
    FB_COLOR_CYAN,
    FB_COLOR_RED,
    FB_COLOR_MAGENTA,
    FB_COLOR_BROWN,
    FB_COLOR_LIGHT_GREY,
    FB_COLOR_DARK_GREY,
    FB_COLOR_LIGHT_BLUE,
    FB_COLOR_LIGHT_GREEN,
    FB_COLOR_LIGHT_CYAN,
    FB_COLOR_LIGHT_RED,
    FB_COLOR_LIGHT_MAGENTA,
    FB_COLOR_LIGHT_BROWN,
    FB_COLOR_WHITE,
};

#define COORDINATE(_x, _y) ((_y)*FB_WIDTH + (_x))

void fb_write_cell(uint32_t i, char c, uint8_t fg, uint8_t bg);
void fb_move_cursor(uint16_t pos);
uint16_t fb_get_cursor_pos(void);

void fb_nwrite(uint32_t pos, const char* buf, uint32_t len, uint8_t fg, uint8_t bg);
void fb_write(uint32_t pos, const char* buf, uint8_t fg, uint8_t bg);
