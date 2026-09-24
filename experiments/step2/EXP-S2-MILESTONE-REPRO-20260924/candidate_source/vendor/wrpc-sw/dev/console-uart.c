/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012-2020 CERN (www.cern.ch)
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include <stdint.h>
#include <errno.h>
#include <stddef.h>

#include "util.h"
#include "pp-printf.h"
#include "board.h"
#include "dev/simple_uart.h"
#include "dev/console.h"
#include "dev/console-uart.h"

struct console_uart_priv_data console_uart_priv;
struct console_device console_uart_dev;

#define CON_ESCAPE_CODE 0x1b
#define CON_SWITCH_BINARY_CODE 'B'
#define CON_SWITCH_TEXT_CODE 'T'

static int con_rx_internal(struct console_device* dev)
{
    struct console_uart_priv_data* priv = (struct console_uart_priv_data*) dev->priv;

#ifdef CONFIG_CONSOLE_UART_MODE
    if ( priv->state == CON_STATE_ESC_FLUSH )
    {
        priv->state = CON_STATE_IDLE;
        return priv->prev_char;
    }
#endif
    int rx_char = suart_read_byte( &priv->uart_dev );

#ifdef CONFIG_CONSOLE_UART_MODE
    if( rx_char < 0 )
        return rx_char;

    if( priv->state == CON_STATE_IDLE )
    {
        if( rx_char == CON_ESCAPE_CODE )
        {
            priv->state = CON_STATE_ESC_PENDING;
            return -1;
        } else {
            return rx_char;
        }
    }
    else if( priv->state == CON_STATE_ESC_PENDING )
    {
        switch( rx_char )
        {
            case CON_ESCAPE_CODE: // double escape = actual esc
                return CON_ESCAPE_CODE;
            case CON_SWITCH_TEXT_CODE: // switch to tty mode
                dev->flags &= ~CONSOLE_FLAGS_MODE_BINARY;
                dev->flags |= CONSOLE_FLAGS_MODE_TTY;
                if( priv->mode_switch_hook )
                    priv->mode_switch_hook( 0 );
                return -1;
            case CON_SWITCH_BINARY_CODE: // switch to binary mode
                dev->flags &= ~CONSOLE_FLAGS_MODE_TTY;
                dev->flags |= CONSOLE_FLAGS_MODE_BINARY;
                if( priv->mode_switch_hook )
                    priv->mode_switch_hook( 1 );
                return -1;
            default:
                priv->state = CON_STATE_ESC_FLUSH;
                priv->prev_char = rx_char;
                return -1;
        }
        priv->state = CON_STATE_IDLE;
    }
#endif
    return rx_char;
}

static int con_uart_put_string(struct console_device* dev, const char *s)
{
    struct console_uart_priv_data* priv = (struct console_uart_priv_data*) dev->priv;
    char c;
    int count = 0;

#ifdef CONFIG_CONSOLE_UART_MODE
    // binary mode uses different API
    if( dev->flags & CONSOLE_FLAGS_MODE_BINARY )
        return 0;
#endif

    while ( (c = *s++) != 0 )
    {
	if( (dev->flags & CONSOLE_FLAGS_INSERT_CRLF) &&  c == '\n')
	    suart_write_byte(&priv->uart_dev, '\r');

        suart_write_byte(&priv->uart_dev, c);
        count++;
    }

    return count;
}

static int con_uart_getc(struct console_device* dev)
{
#ifdef CONFIG_CONSOLE_UART_MODE
    if( dev->flags & CONSOLE_FLAGS_MODE_BINARY )
        return 0;
#endif

    return con_rx_internal( dev );
}

void console_uart_set_crlf_mode(int on)
{
    if(on)
        console_uart_dev.flags |= CONSOLE_FLAGS_INSERT_CRLF;
    else
        console_uart_dev.flags &= ~CONSOLE_FLAGS_INSERT_CRLF;
}

void console_uart_init(struct console_device *dev,
		       struct console_uart_priv_data *priv,
		       unsigned addr,
		       unsigned baudrate)
{
    suart_init(&priv->uart_dev, addr, baudrate);

    dev->flags = CONSOLE_FLAGS_MODE_TTY | CONSOLE_FLAGS_INSERT_CRLF;
    dev->priv = priv;
    dev->get_char = con_uart_getc;
    dev->put_string = con_uart_put_string;

#ifdef CONFIG_CONSOLE_UART_MODE
    priv->prev_char = 0;
    priv->state = CON_STATE_IDLE;
    priv->mode_switch_hook = NULL;
#endif

    console_register_device(dev);
}

#ifdef CONFIG_CONSOLE_UART_MODE

void console_set_mode_switch_hook( struct console_device *dev, void (*callback)(int) )
{
    struct console_uart_priv_data* priv = (struct console_uart_priv_data*) dev->priv;
    priv->mode_switch_hook = callback;
}

void console_force_mode( struct console_device *dev, int mode )
{
    struct console_uart_priv_data* priv = (struct console_uart_priv_data*) dev->priv;

    dev->flags &= ~( CONSOLE_FLAGS_MODE_BINARY | CONSOLE_FLAGS_MODE_TTY );
    dev->flags |= mode;
#ifdef CONFIG_CONSOLE_UART_MODE
    priv->state = CON_STATE_IDLE;
#endif
}

int console_get_mode( struct console_device *dev )
{
    return dev->flags & ( CONSOLE_FLAGS_MODE_BINARY | CONSOLE_FLAGS_MODE_TTY );
}

int console_binary_send_byte( struct console_device *dev, uint8_t b )
{
    struct console_uart_priv_data* priv = (struct console_uart_priv_data*) dev->priv;

    if( dev->flags & CONSOLE_FLAGS_MODE_TTY )
        return 0;

    int has_fifo = suart_is_fifo_supported( &priv->uart_dev );

    if( !has_fifo )
        return -ENODEV;

    suart_write_byte( &priv->uart_dev, b );

    return 0;
}

int console_binary_recv_byte( struct console_device *dev )
{
    struct console_uart_priv_data* priv = (struct console_uart_priv_data*) dev->priv;

    if( dev->flags & CONSOLE_FLAGS_MODE_TTY )
        return -1;

    int has_fifo = suart_is_fifo_supported( &priv->uart_dev );

    if( !has_fifo )
        return -ENODEV;

    int rx_byte = con_rx_internal( dev );

    return rx_byte;
}
#endif
