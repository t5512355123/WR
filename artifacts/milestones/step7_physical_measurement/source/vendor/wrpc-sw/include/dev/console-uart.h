/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012-2019 CERN (www.cern.ch)
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __CONSOLE_UART_H
#define __CONSOLE_UART_H

#include <stdint.h>

#include "dev/console.h"
#include "dev/simple_uart.h"

/* Add a binary/ascii mode to the uart console.
   Only for ertm14. */
#ifdef CONFIG_TARGET_ERTM14
#define CONFIG_CONSOLE_UART_MODE 1
#endif

#ifdef CONFIG_CONSOLE_UART_MODE
#define CON_STATE_IDLE 0
#define CON_STATE_ESC_PENDING 1 // previous char was escape, waiting for control code
#define CON_STATE_ESC_FLUSH 2  // previous char was an unrecognized escape sequence, pass both to the user
#endif

struct console_uart_priv_data
{
    struct simple_uart_device uart_dev;
#ifdef CONFIG_CONSOLE_UART_MODE
    uint8_t state;
    uint8_t prev_char;
    void (*mode_switch_hook)( int is_binary );
#endif
};

void console_uart_init(struct console_device *dev,
		       struct console_uart_priv_data *priv,
		       unsigned addr,
		       unsigned baudrate);

extern struct console_uart_priv_data console_uart_priv;
extern struct console_device console_uart_dev;


void console_uart_set_crlf_mode(int on);

#ifdef CONFIG_CONSOLE_UART_MODE
void console_force_mode( struct console_device *dev, int mode );
int console_get_mode( struct console_device *dev );

int console_binary_send_byte( struct console_device *dev, uint8_t b );
int console_binary_recv_byte( struct console_device *dev );

void console_set_mode_switch_hook( struct console_device *dev, void (*callback)(int) );
#endif

#endif

