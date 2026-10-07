/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012-2020 CERN (www.cern.ch)
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include <stdint.h>
#include <errno.h>

#include "board.h"
#include "dev/console.h"

#ifdef CONFIG_IPMI_CONSOLE

#define IPMI_CON_TX_BUF_SIZE 1024
#define IPMI_CON_RX_BUF_SIZE 128
#define IPMI_CON_RX_TIMEOUT 1000

struct ring_buffer
{
    uint8_t *data;
    int head, tail, size, count;
};

struct console_ipmi_priv_data 
{
    uint8_t tx_buf_mem[IPMI_CON_TX_BUF_SIZE];
    uint8_t rx_buf_mem[IPMI_CON_RX_BUF_SIZE];

    struct ring_buffer rx_buf;
    struct ring_buffer tx_buf;
};

struct console_device console_ipmi_dev;
struct console_ipmi_priv_data console_ipmi_priv;

static inline void rbuf_put( struct ring_buffer* buf, uint8_t c )
{
    if (buf->count >= buf->size)
		return;

    buf->data[buf->head] = c;
	buf->head++;
    buf->count++;

	if (buf->head >= buf->size)
		buf->head = 0;
}

static inline int rbuf_get( struct ring_buffer* buf )
{
    if( !buf->count )
        return -1;

    int rv = buf->data[buf->tail];

    buf->tail++;
    if (buf->tail >= buf->size)
		buf->tail = 0;
    buf->count--;

    return rv;
}

static inline int rbuf_init( struct ring_buffer *buf, int size, uint8_t *mem )
{
    buf->head = buf->tail = buf->count = 0;
    buf->size = size;
    buf->data = mem;
    return 0;
}

static inline int rbuf_full(struct ring_buffer *buf)
{
    return buf->size == buf->count;
}

static inline int rbuf_purge(struct ring_buffer *buf)
{
    buf->head = buf->tail = buf->count = 0;
    return 0;
}

static int con_ipmi_put_string(struct console_device* dev, const char *s)
{
    struct console_ipmi_priv_data* priv = (struct console_ipmi_priv_data*) dev->priv;
    int c, n = 0;
    while( (c = *s++) != 0 )
    {
        rbuf_put( &priv->tx_buf, c );
        n++;
    }

    if( rbuf_full(&priv->tx_buf ) )
        rbuf_purge(&priv->tx_buf);

    return n;
}

static int con_ipmi_getc(struct console_device* dev)
{
    struct console_ipmi_priv_data* priv = (struct console_ipmi_priv_data*) dev->priv;
    return rbuf_get( &priv->rx_buf );
}

int console_ipmi_process_request(struct console_device* dev,  uint8_t *req, int size, uint8_t *rsp, int rsp_size )
{
    struct console_ipmi_priv_data* priv = (struct console_ipmi_priv_data*) dev->priv;

    int i;

    for(i = 0; i < size; i++ )
    {
        rbuf_put( &priv->rx_buf, req[i] );
    }

    for(i = 0; i < rsp_size; i++)
    {
        if ( priv->tx_buf.count == 0 )
            break;
        rsp[i] = rbuf_get( &priv->tx_buf );
    }

    return i;
}

void console_ipmi_init( void )
{
    console_ipmi_dev.priv = &console_ipmi_priv;
    console_ipmi_dev.get_char = con_ipmi_getc;
    console_ipmi_dev.put_string = con_ipmi_put_string;
    rbuf_init(&console_ipmi_priv.rx_buf, IPMI_CON_RX_BUF_SIZE, console_ipmi_priv.rx_buf_mem);
    rbuf_init(&console_ipmi_priv.tx_buf, IPMI_CON_TX_BUF_SIZE, console_ipmi_priv.tx_buf_mem);
    console_register_device( &console_ipmi_dev );
}

#endif
