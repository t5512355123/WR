#include <string.h>
#include "dev/console.h"
#include "dev/console-uart.h"
#include "dev/syscon.h"
#include "dev/simple_uart.h"
#include "common-uart-link.h"

static uint32_t wrpc_get_ms_tics( struct uart_link* link )
{
    return timer_get_tics();
}

static int wrpc_console_uart_send_byte( struct uart_link* link, uint8_t b )
{
    return console_binary_send_byte( &console_uart_dev, b );
}

static int wrpc_console_uart_recv_byte( struct uart_link* link )
{
    return console_binary_recv_byte( &console_uart_dev ) ;
}

int uart_link_create_wrpc_console( struct uart_link *link )
{
    memset(link, 0, sizeof(struct uart_link));
    link->priv = NULL;
    link->send_byte = wrpc_console_uart_send_byte;
    link->recv_byte = wrpc_console_uart_recv_byte;
    link->get_ms_tics = wrpc_get_ms_tics;
    link->state = LINK_STATE_IDLE;
    link->rx_last_tics = 0;
    return 0;
};


static int wrpc_suart_send_byte( struct uart_link* link, uint8_t b )
{
    struct simple_uart_device *suart = (struct simple_uart_device* ) link->priv;
    suart_write_byte( suart, b );
    return 1;
}

static int wrpc_suart_recv_byte( struct uart_link* link )
{
    struct simple_uart_device *suart = (struct simple_uart_device* ) link->priv;
    return suart_read_byte( suart );
}

int uart_link_create_wrpc_suart( struct uart_link *link, struct simple_uart_device *uart_dev )
{
    memset(link, 0, sizeof(struct uart_link));
    link->priv = uart_dev;
    link->send_byte = wrpc_suart_send_byte;
    link->recv_byte = wrpc_suart_recv_byte;
    link->get_ms_tics = wrpc_get_ms_tics;
    link->state = LINK_STATE_IDLE;
    link->rx_last_tics = 0;
    return 0;
};
