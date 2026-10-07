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

#include <sys/errno.h>
#include <string.h>

#include "common-uart-link.h"

#ifndef __linux__
    #ifdef CONFIG_TARGET_ERTM14
    // hack - -Werror prevents compiling this under WRPC/eRTM14 because we're missing prototypes for pp_printf() and timer_get_tics()
        #include "dev/syscon.h"
        #include "wrc-debug.h"
    #endif
#else
    #include <stdio.h> // for printf()
#endif

static uint16_t crc_xmodem_update(uint16_t crc, uint8_t data)
{
    int i;

    crc = crc ^ (((uint16_t)data) << 8);

    for (i = 0; i < 8; i++)
    {
        if (crc & 0x8000)
        {
            crc = (crc << 1) ^ 0x1021;
        } else {
            crc <<= 1;
        }
    }
    return crc;
}

static uint16_t crc16(unsigned char *buf, int len)
{
    int i;
    uint16_t cksum;
    cksum = 0;

    for (i = 0; i < len; i++) {
        cksum = crc_xmodem_update(cksum, buf[i]);
    }
    return cksum;
}

int uart_link_reset( struct uart_link *link )
{
    link->state = LINK_STATE_IDLE;
    link->rx_last_tics = 0;
    return 0;		/* FIXME: mustn't this be void? */
}

int uart_link_send( struct uart_link* link, struct uart_packet* pkt )
{
    uint8_t  buf[ UART_LINK_MAX_PAYLOAD + 16 ];
    uint16_t crc = 0, i;

    buf[0] = 0x55;
    buf[1] = 0xaa;
    buf[2] = pkt->ptype;
    buf[3] = (pkt->length >> 8) & 0xff;
    buf[4] = (pkt->length & 0xff);

    if(pkt->length > 0)
        memcpy(buf+5, pkt->payload, pkt->length);

    crc = crc16(buf, pkt->length+5);

    buf[pkt->length+5] = (crc >> 8);
    buf[pkt->length+6] = (crc & 0xff);

    for (i = 0; i < pkt->length+7; i++)
    {
        int res = link->send_byte( link, buf[i] );
        if ( res < 0 )
            return res;
    }

    return 0;
}

static int recv_fsm( struct uart_link* link, struct uart_packet **pkt )
{
    int rx_byte = link->recv_byte( link );

    if( rx_byte < 0 )
        return RX_FSM_NEED_DATA;

    ulink_dbg( "Rx %x state %d\n", rx_byte, link->state );
#ifndef __linux__
if(link->state != LINK_STATE_IDLE && link->extra_verbose)
{
            int d = timer_get_tics() - link->ts;
            if( d>=1 )
                pp_printf("Choke @ %d %d\n", d, link->rx_count );
            link->ts = timer_get_tics();
}
#endif

    switch( link->state )
    {
        case LINK_STATE_IDLE:
            if( rx_byte == 0x55 )
            {
                link->state = LINK_STATE_SYNC;
                link->check_crc = crc_xmodem_update( 0, 0x55 );
                #ifndef __linux__
                if( link->extra_verbose )
		    pp_printf("RxS %u\n", (unsigned)timer_get_tics() );

                link->ts = timer_get_tics();
                #endif
            }
            break;

        case LINK_STATE_SYNC:
            if( rx_byte == 0xaa )
            {
                link->state = LINK_STATE_PTYPE;
                link->check_crc = crc_xmodem_update( link->check_crc, 0xaa );
            }
            else if (rx_byte == 0x55)
                link->state = LINK_STATE_SYNC;
            else
                link->state = LINK_STATE_IDLE;
            break;

        case LINK_STATE_PTYPE:
            link->rx_packet.ptype = rx_byte;
            link->check_crc = crc_xmodem_update( link->check_crc, rx_byte);
            link->state = LINK_STATE_LEN0;
            break;

        case LINK_STATE_LEN0:
            link->rx_packet.length = (rx_byte << 8);
            link->check_crc = crc_xmodem_update( link->check_crc, rx_byte);
            link->state = LINK_STATE_LEN1;
            break;

        case LINK_STATE_LEN1:
            link->rx_packet.length |= rx_byte;
            link->check_crc = crc_xmodem_update( link->check_crc, rx_byte);
            link->rx_count = 0;

            if( link->rx_packet.length == 0 )
                link->state = LINK_STATE_CRC0;
            else
                link->state = LINK_STATE_PAYLOAD;

            #ifndef __linux__
                if( link->extra_verbose )
                    pp_printf("RxPL %u\n", (unsigned)timer_get_tics() );

            //    link->ts = timer_get_tics();
                #endif
            break;

        case LINK_STATE_PAYLOAD:
            if( link->rx_count == link->rx_packet.length - 1 )
            {
                link->state = LINK_STATE_CRC0;
            }



            link->check_crc = crc_xmodem_update( link->check_crc, rx_byte);

            if( link->rx_count < UART_LINK_MAX_PAYLOAD )
                link->rx_packet.payload[ link->rx_count++ ] = rx_byte;
            break;

        case LINK_STATE_CRC0:
            link->rx_crc = (rx_byte << 8);
            link->state = LINK_STATE_CRC1;
            break;

        case LINK_STATE_CRC1:
        {
            link->rx_crc |= rx_byte;
            link->state = LINK_STATE_IDLE;

            if (link->rx_count != link->rx_packet.length )
            {   
                return RX_FSM_PACKET_ERROR;
            }
            else if (link->rx_crc != link->check_crc )
            {
                return RX_FSM_PACKET_ERROR;
            }
            else
            {
                *pkt = &link->rx_packet;
                #ifndef __linux__
                if( link->extra_verbose )
                    pp_printf("RxF %u [%u] size %d\n", (unsigned)timer_get_tics(), (unsigned)timer_get_tics()-link->ts, link->rx_count );
                #endif
                return RX_FSM_GOT_PACKET;

            }
            break;
        }
    }

    return RX_FSM_NEED_DATA;
}

int uart_link_recv( struct uart_link* link, struct uart_packet **pkt, int timeout_ms )
{
    uint32_t start_tics = link->get_ms_tics( link );

    for(;;)
    {
        int ret = recv_fsm( link, pkt );
        int delta = link->get_ms_tics( link ) - start_tics;

        /* If we're waiting for more data (which is likely to come in the few next milliseconds),
           don't preempt the loop as the global task scheduler in WRPC may return here with a lag of several milliseconds
           causing a noticeable slowdown in commiunication (few ms accumulated per each byte received).
           It's not the best solution (proper one would be to have polling for the exact number of bytes in the RX FIFO of the UART),
           but works just fine for the control UART API. */

        if( ret == RX_FSM_NEED_DATA && delta < link->rx_next_timeout_ms )
            continue;

        if ( timeout_ms == 0 )
            return ret;
        else if( ret == RX_FSM_PACKET_ERROR || ret == RX_FSM_GOT_PACKET )
            return ret;
        else { // check timeout
            if( delta >= timeout_ms )
            {
                ulink_dbg( "Rx timeout expired\n");
                uart_link_reset( link );
                return -ECANCELED;
            } else {
                if( !link->poll || ! link->poll(link) )
                    linux_usleep(10);
            }
        }
    }

    return 0;
}
