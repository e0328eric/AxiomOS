#pragma once

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

void fb_write_cell(unsigned int i, char c, unsigned char fg, unsigned char bg);
void fb_move_cursor(unsigned short pos);
void fb_nwrite(unsigned int pos,
               const char* buf,
               unsigned int len,
               unsigned char fg,
               unsigned char bg);

void fb_write(unsigned int pos, const char* buf, unsigned char fg, unsigned char bg);
