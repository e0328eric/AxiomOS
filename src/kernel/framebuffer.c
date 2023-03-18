#include "framebuffer.h"
#include "io.h"
#include "utility.h"

// The I/O ports for framebuffer
enum {
    FB_COMMAND_PORT = 0x3D4,
    FB_DATA_PORT = 0x3D5,
};

// The I/O port commands
enum {
    FB_HIGH_BYTE_COMMAND = 14,
    FB_LOW_BYTE_COMMAND = 15,
};

static volatile char* frame_buffer = (char*)0x000B8000;

void fb_write_cell(unsigned int i, char c, unsigned char fg, unsigned char bg) {
    ASSERT(i < FB_WIDTH * FB_HEIGHT, 'F');

    i <<= 1;
    frame_buffer[i] = c;
    frame_buffer[i + 1] = ((bg & 0x0F) << 4) | (fg & 0x0F);
}

void fb_move_cursor(unsigned short pos) {
    outb(FB_COMMAND_PORT, FB_HIGH_BYTE_COMMAND);
    outb(FB_DATA_PORT, ((pos >> 8) & 0x00FF));
    outb(FB_COMMAND_PORT, FB_LOW_BYTE_COMMAND);
    outb(FB_DATA_PORT, pos & 0x00FF);
}

void fb_nwrite(unsigned int pos,
               const char* buf,
               unsigned int len,
               unsigned char fg,
               unsigned char bg) {
    ASSERT(pos < FB_WIDTH * FB_HEIGHT, 'F');

    pos <<= 1;
    for (unsigned int i = 0; i < len; ++i) {
        frame_buffer[pos + (i << 1)] = buf[i];
        frame_buffer[pos + (i << 1) + 1] = ((bg & 0x0F) << 4) | (fg & 0x0F);
    }
}

void fb_write(unsigned int pos, const char* buf, unsigned char fg, unsigned char bg) {
    ASSERT(pos < FB_WIDTH * FB_HEIGHT, 'F');

    pos <<= 1;
    for (unsigned int i = 0; buf[i]; ++i) {
        frame_buffer[pos + (i << 1)] = buf[i];
        frame_buffer[pos + (i << 1) + 1] = ((bg & 0x0F) << 4) | (fg & 0x0F);
    }
}
