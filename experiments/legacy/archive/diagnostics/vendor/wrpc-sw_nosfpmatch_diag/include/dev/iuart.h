/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: John Gill <jgill@cern.ch>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef __IUART_H
#define __IUART_H

#include <stdint.h>

/* Currently it is the only one supported */
#define IUART_PLATFORM_BARE_METAL

#ifndef IUART_PLATFORM_LINUX
#ifndef IUART_PLATFORM_BARE_METAL
#ifndef IUART_PLATFORM_HOSTED
#error choose IUART code platform
#endif
#endif
#endif

#ifdef IUART_PLATFORM_BARE_METAL
    #include "dev/simple_uart.h"
#endif

#define ESC_CHAR_VAL               (0x24)
// All start chars must have the property:
// start_char & start_mask_en == start_mask
#define START_MASK_EN              (0xf0)
#define START_INSN_CHAR_VAL        (0xf0)
#define START_WRITE_CHAR_VAL       (0xf1)
#define START_READ_CHAR_VAL        (0xf2)
#define START_CPL_CHAR_VAL         (0xf3)
#define START_WRITE_CTRL_CHAR_VAL  (0xf4)
#define START_READ_CTRL_CHAR_VAL   (0xf5)
#define START_CPL_CTRL_CHAR_VAL    (0xf6)
#define END_CHAR_VAL               ('E')  // 0x45

#define IUART_RXBUF_SIZE 128

struct iuart_device {
#ifdef IUART_PLATFORM_HOSTED
    int fd;
    void (*send_byte)(struct iuart_device*, uint8_t b);
    int (*recv_byte)(struct iuart_device*);
#endif
#ifdef IUART_PLATFORM_BARE_METAL
    uint32_t base;
    struct simple_uart_device master_uart;
#endif
    uint8_t rx_buf [ IUART_RXBUF_SIZE ];
    int rx_noc, rx_csize;
};

int iuart_read_byte(struct iuart_device *dev);
void     iuart_write_byte(struct iuart_device *dev, uint8_t val);

int     iuart_init_linux(struct iuart_device *dev, const char *dev_name, uint32_t baud_rate);
int     iuart_init_bare(struct iuart_device *dev, uint32_t base_addr, uint32_t baud_rate);
int     iuart_init_hosted(struct iuart_device *dev);

#ifdef IUART_PLATFORM_BARE_METAL
void     iuart_fifo_cnt(struct iuart_device *dev, uint16_t *rxcnt, uint16_t *txcnt);
uint16_t iuart_fifo_space(struct iuart_device *dev, uint16_t fifo_size, uint16_t fifo_cnt);
uint8_t  iuart_tx_busy(struct iuart_device *dev);
uint8_t  iuart_rx_ready(struct iuart_device *dev);
uint8_t  iuart_rx_err(struct iuart_device *dev);
uint8_t  iuart_read_ctrl(struct iuart_device *dev);
uint8_t  iuart_txdata_valid(struct iuart_device *dev);
uint8_t  iuart_cpls_valid(struct iuart_device *dev);
uint32_t iuart_rx_errcnt(struct iuart_device *dev);
#endif

int iuart_recv_message(struct iuart_device *dev);
int iuart_send_message(struct iuart_device *dev, uint8_t *payload, int length );
void     iuart_insn(struct iuart_device *dev, uint8_t *buf, uint32_t size);
void     iuart_da_write_ctrl(struct iuart_device *dev, uint8_t val);
void     iuart_da_write(struct iuart_device *dev, uint8_t *buf, uint32_t addr, uint32_t size);
void     iuart_da_read(struct iuart_device *dev, uint32_t addr, uint32_t size);
void     iuart_da_cpl(struct iuart_device *dev, uint32_t cpldata);
void     iuart_da_read_ctrl(struct iuart_device *dev);

int iuart_da_wait_completion( struct iuart_device *dev, uint8_t* data, int size );
int iuart_da_read_blocking(struct iuart_device *dev, uint32_t addr, uint8_t *data, uint32_t size);
uint8_t  iuart_parse_raw_byte( uint8_t rxbyte, uint8_t *rxbuf, int *noc, int *csize);

#endif
