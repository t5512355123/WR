/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012-2020 CERN (www.cern.ch)
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include "../../include/board.h"
#include "dev/simple_uart.h"
#include "dev/console-uart.h"
#include "pp-printf.h"

static struct console_uart_priv_data console_uart_priv_2nd;
static struct console_device console_uart_2nd;

void console_ertm14_init(void)
{
    // hack: there's a second UART attached to the console available on the J11 pins 2 & 3.
    // This is meant to help debugging the UART link (which uses the primary front panel USB console uart...)
    console_uart_init(&console_uart_2nd, &console_uart_priv_2nd,
		      BASE_ERTM14_DEBUG_UART, CONSOLE_UART_BAUDRATE );

    pp_printf("Console UART FIFO:: %d\n", suart_is_fifo_supported( &console_uart_priv.uart_dev ) );
    pp_printf("Debug UART FIFO:: %d\n", suart_is_fifo_supported( &console_uart_priv_2nd.uart_dev ) );
}

