/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2020-2021 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 * Author: David Cobas <david.cobas@cern.ch>
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

#ifndef __COMMON_UART_LINK_H
#define __COMMON_UART_LINK_H

#include <stdint.h>

/* maximum packet payload size. choose to meet your memory footprint. */
/* fixme: get config from board.h */
#define UART_LINK_MAX_PAYLOAD 512

#define LINK_STATE_IDLE 0
#define LINK_STATE_SYNC 1
#define LINK_STATE_PTYPE 2
#define LINK_STATE_LEN0 3
#define LINK_STATE_LEN1 4
#define LINK_STATE_PAYLOAD 5
#define LINK_STATE_CRC0 6
#define LINK_STATE_CRC1 7

#define RX_FSM_TIMEOUT 1000 /* ms */

#ifndef DEBUG
#define ulink_dbg(...)
#else
#ifdef __linux__
#define ulink_dbg(...) fprintf(stderr,__VA_ARGS__)
#else
#define ulink_dbg(...)
#endif
#endif

struct simple_uart_device;

struct uart_packet
{
    uint8_t ptype;
    uint16_t length;
    uint8_t payload[ UART_LINK_MAX_PAYLOAD ];
};

struct uart_link
{
    int (*send_byte)(struct uart_link *link, uint8_t byte );
    int (*recv_byte)(struct uart_link *link );
    uint32_t (*get_ms_tics)( struct uart_link *link );
    int (*poll)(struct uart_link *link);
    void *priv;
    int state;
    int rx_count;
    uint16_t rx_crc, check_crc;
    uint32_t rx_last_tics;
    struct uart_packet rx_packet;
    int ts;
    int extra_verbose;
    int rx_next_timeout_ms;
};

#define RX_FSM_PACKET_ERROR -2
#define RX_FSM_NO_DATA -1
#define RX_FSM_NEED_DATA 0
#define RX_FSM_GOT_PACKET 1

#ifdef __linux__
#include <unistd.h>
#define linux_usleep(u)		usleep(u)
#else
#define	linux_usleep(u)		do {} while (0)
#endif

#ifdef __linux__
int uart_link_create_linux( struct uart_link *link, const char* dev_name, int speed );
int uart_link_close_linux( struct uart_link *link );
#endif

#ifdef CONFIG_TARGET_ERTM14
int uart_link_create_wrpc_console( struct uart_link *link );
int uart_link_create_wrpc_suart( struct uart_link *link, struct simple_uart_device *uart_dev );
#endif

int uart_link_reset( struct uart_link *link );
int uart_link_send( struct uart_link* link, struct uart_packet* pkt );
int uart_link_recv( struct uart_link* link, struct uart_packet **pkt, int timeout_ms );

#endif
