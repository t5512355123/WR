/**
 * Author: Federico Vaga <federico.vaga@cern.ch>
 */

#include <string.h>
#include "vuart_lib.h"
#include <hw/wb_uart.h>
#include <stdio.h>

/**
 * It receives a single byte
 * @param[in] vuart token from dev_map()
 *
 *
 */

static uint32_t io_readl(volatile void *addr)
{
#ifdef WR2RF
	/* A 16b VME bus with special circuitery to get an atomic 32b value */
	uint32_t l, h, res;
	l = *(volatile uint16_t *)(addr + 0);
	h = *(volatile uint16_t *)(addr + 2);
	res = (l << 16) | h;
	return res;
#else
	return *(volatile uint32_t *)addr;
#endif
}

static void io_writel(volatile void *addr, uint32_t val)
{
#ifdef WR2RF
	*(volatile uint16_t *)(addr + 2) = val & 0xffff;
	*(volatile uint16_t *)(addr + 0) = val >> 16;
#else
	*(volatile uint32_t *)addr = val;
#endif
}

static uint32_t vuart_readl(struct mapping_desc *vuart, int reg)
{
	uint32_t r = io_readl(vuart->base + reg);

	if(vuart->is_be)
		return ntohl(r);
	else
		return r;
}


static void vuart_writel(struct mapping_desc *vuart, uint32_t value, int reg)
{
	if(vuart->is_be)
		value = htonl(value);

	io_writel(vuart->base + reg, value);
}

int wr_vuart_rx(struct mapping_desc *vuart)
{
	int rdr = vuart_readl( vuart, UART_REG_HOST_RDR );
	return (rdr & UART_HOST_RDR_RDY) ? UART_HOST_RDR_DATA_R(rdr) : -1;
}

/**
 * It transmits a single byte
 * @param[in] vuart token from dev_map()
 */
void wr_vuart_tx(struct mapping_desc *vuart, char data)
{
	int sr = vuart_readl( vuart, UART_REG_SR );

	while(sr & UART_SR_RX_RDY)
		 sr = vuart_readl( vuart, UART_REG_SR );

	vuart_writel( vuart, UART_HOST_TDR_DATA_W(data), UART_REG_HOST_TDR );
}

/**
 * It reads a number of bytes and it stores them in a given buffer
 * @param[in] vuart token from dev_map()
 * @param[out] buf destination for read bytes
 * @param[in] size numeber of bytes to read
 *
 * @return the number of read bytes
 */
size_t wr_vuart_read(struct mapping_desc *vuart, char *buf, size_t size)
{
	size_t s = size, n_rx = 0;
	int8_t c;

	while(s--) {
		c =  wr_vuart_rx(vuart);
		if(c < 0)
			return n_rx;
		*buf++ = c;
		n_rx ++;
	}
	return n_rx;
}

/**
 * It flush vuart buffer.
 *
 * @param[in] vuart token from dev_map()
 *
 */
void wr_vuart_flush(struct mapping_desc *vuart)
{
	char rx;

	while(wr_vuart_read(vuart,&rx,1) == 1) {}
}

/**
 * It writes a number of bytes from a given buffer
 * @param[in] vuart token from dev_map()
 * @param[in] buf buffer to write
 * @param[in] size numeber of bytes to write
 */
void wr_vuart_write(struct mapping_desc *vuart, char *buf, size_t size)
{
	while(size--)
		wr_vuart_tx(vuart, *buf++);
}

void wrpc_vuart_set_tty_raw(struct termios *old_termios)
{
  	struct termios newkey;

	tcgetattr(STDIN_FILENO,old_termios);
	memcpy(&newkey, old_termios, sizeof(struct termios));
	newkey.c_cflag = B9600 | CS8 | CLOCAL | CREAD;
	newkey.c_iflag = IGNPAR;
	newkey.c_oflag = 0;
	newkey.c_lflag = ISIG;  /* Keep C-c, C-z, ... */
	tcflush(STDIN_FILENO, TCIFLUSH);
	tcsetattr(STDIN_FILENO,TCSANOW,&newkey);
}

void wrpc_vuart_restore_tty(struct termios *old_termios)
{
	tcsetattr(STDIN_FILENO, TCSANOW, old_termios);
}

