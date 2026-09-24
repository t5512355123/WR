/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __SIMPLE_UART_H
#define __SIMPLE_UART_H

struct simple_uart_device {
	void* base;
};

#define SUART_CALC_BAUD(baudrate) \
    ( ((( (unsigned long long)baudrate * 8ULL) << (16 - 7)) + \
      (CPU_CLOCK >> 8)) / (CPU_CLOCK >> 7) )

void suart_init(struct simple_uart_device *dev, uint32_t base_addr, int baudrate);
void suart_init_default_baudrate(struct simple_uart_device *dev, uint32_t base_addr);
void suart_write_byte(struct simple_uart_device *dev, int b);
int suart_write_string(struct simple_uart_device *dev, const char *s);
int suart_read_byte(struct simple_uart_device *dev);
int suart_poll(struct simple_uart_device *dev);
int suart_is_fifo_supported( struct simple_uart_device *dev );

#endif
