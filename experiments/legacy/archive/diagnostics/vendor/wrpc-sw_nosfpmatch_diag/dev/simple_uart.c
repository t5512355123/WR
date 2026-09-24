/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include <stdint.h>

#include "wrc.h"
#include "board.h"
#include "dev/simple_uart.h"
#include "hw/rawmem.h"
#include "hw/wb_uart.h"

#define SUART_CALC_BAUD(baudrate) \
    ( ((( (unsigned long long)baudrate * 8ULL) << (16 - 7)) + \
      (CPU_CLOCK >> 8)) / (CPU_CLOCK >> 7) )

static inline uint32_t suart_calc_baud( int baudrate )
{
	uint64_t n = (((uint64_t) (baudrate)) << 12 ) + (CPU_CLOCK >> 8);
	__div64_32(&n, CPU_CLOCK >> 7);
	return (uint32_t) n;
}

void suart_init(struct simple_uart_device *dev, uint32_t base_addr, int baudrate)
{
	dev->base = (void*) base_addr;
	writel( suart_calc_baud(baudrate), dev->base + UART_REG_BCR );
}

void suart_init_default_baudrate(struct simple_uart_device *dev, uint32_t base_addr)
{
	dev->base = (void*) base_addr;
	writel( SUART_CALC_BAUD(CONSOLE_UART_BAUDRATE), dev->base + UART_REG_BCR );
}

void suart_write_byte(struct simple_uart_device *dev, int b)
{
	while (readl(dev->base + UART_REG_SR) & UART_SR_TX_BUSY)
		;

	writel( b, dev->base + UART_REG_TDR );
}

int suart_write_string(struct simple_uart_device *dev, const char *s)
{
	const char *t = s;

	while (*s)
		suart_write_byte(dev, *(s++));
	return s - t;
}

int suart_get_rx_fifo_count( struct simple_uart_device *dev )
{
	uint32_t r = readl( dev->base + UART_REG_SR );
	int n = UART_SR_RX_FIFO_BYTES_R(r);

	if ( r & UART_SR_RX_RDY ) // another byte in the output register?
		n++;

	return n;
}


int suart_poll(struct simple_uart_device *dev)
{
	if( suart_is_fifo_supported( dev ) )
	{
		return suart_get_rx_fifo_count( dev );
	}
	
	return readl( dev->base + UART_REG_SR) & UART_SR_RX_RDY ? 1 : 0;
}

int suart_read_byte(struct simple_uart_device *dev)
{
	if (!suart_poll(dev))
		return -1;

	return readl(dev->base + UART_REG_RDR) & 0xff;
}

int suart_get_tx_fifo_count( struct simple_uart_device *dev )
{
	// fixme
	return -1;
}

int suart_purge_tx_fifo( struct simple_uart_device *dev )
{
	// fixme
	return -1;
}

int suart_purge_rx_fifo( struct simple_uart_device *dev )
{
	// fixme
	return -1;
}

int suart_is_fifo_supported( struct simple_uart_device *dev )
{
	return (readl( dev->base + UART_REG_SR) & UART_SR_TX_FIFO_SUPPORTED) ? 1 : 0 ;
}
