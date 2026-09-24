/** @file transport.c
 *  @brief Bind all supported transports into one table.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  All supported transports are included in the global eb_transports[].
 *
 *  @author Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 *  @bug None!
 *
 *******************************************************************************
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *  
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library. If not, see <http://www.gnu.org/licenses/>.
 *******************************************************************************
 */

#define ETHERBONE_IMPL

#include "posix-ip.h"
#include "transport.h"
#include "posix-udp.h"
#include "posix-tcp.h"
#include "tunnel.h"
#include "dev.h"

struct eb_transport_ops eb_transports[] = {
#ifndef __WIN32
  {
    EB_DEV_MTU,
    eb_dev_open,
    eb_dev_close,
    eb_dev_connect,
    eb_dev_disconnect,
    eb_dev_fdes,
    eb_dev_accept,
    eb_dev_poll,
    eb_dev_recv,
    eb_dev_send,
    eb_dev_send_buffer
  },
#endif
  {
    EB_POSIX_UDP_MTU,
    eb_posix_udp_open,
    eb_posix_udp_close,
    eb_posix_udp_connect,
    eb_posix_udp_disconnect,
    eb_posix_udp_fdes,
    eb_posix_udp_accept,
    eb_posix_udp_poll,
    eb_posix_udp_recv,
    eb_posix_udp_send,
    eb_posix_udp_send_buffer
  },
  {
    EB_POSIX_TCP_MTU,
    eb_posix_tcp_open,
    eb_posix_tcp_close,
    eb_posix_tcp_connect,
    eb_posix_tcp_disconnect,
    eb_posix_tcp_fdes,
    eb_posix_tcp_accept,
    eb_posix_tcp_poll,
    eb_posix_tcp_recv,
    eb_posix_tcp_send,
    eb_posix_tcp_send_buffer
  },
  {
    EB_TUNNEL_MTU,
    eb_tunnel_open,
    eb_tunnel_close,
    eb_tunnel_connect,
    eb_tunnel_disconnect,
    eb_tunnel_fdes,
    eb_tunnel_accept,
    eb_tunnel_poll,
    eb_tunnel_recv,
    eb_tunnel_send,
    eb_tunnel_send_buffer
  }
};

const unsigned int eb_transport_size = sizeof(eb_transports) / sizeof(struct eb_transport_ops);
