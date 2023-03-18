#pragma once

/** outb:
 *  Sends the given data to the given I/O port. Defined in io.asm
 *
 *  @param port The I/O port to send the data to
 *  @param data The data to send to the I/O port
 */
void outb(unsigned short port, unsigned char data);

/** inb:
 *  Sends the given data to the given I/O port. Defined in io.asm
 *
 *  @param port The I/O port to receive the data from
 */
unsigned char inb(unsigned short port);
