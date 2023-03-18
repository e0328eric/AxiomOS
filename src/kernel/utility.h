#pragma once

__attribute__((noreturn)) extern void raise_error(unsigned char errcode);

// A NULL pointer
#define NULL ((void*)0)

// assert macro
#define ASSERT(_expr, _errcode)    \
    do {                           \
        if (!(_expr)) {            \
            raise_error(_errcode); \
        }                          \
    } while (0)

// true and false value
typedef unsigned char bool;
#define false 0
#define true 1

typedef unsigned int size_t;
