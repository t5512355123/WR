/** @file posix-tcp.c
 *  @brief This implements a TCP binding using posix sockets.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  The transport carries a port for accepting inbound connections.
 *  Passive devices are created for inbound connections.
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
#include "posix-tcp.h"
#include "transport.h"

eb_status_t eb_posix_tcp_open(struct eb_transport* transportp, const char* port) {
  struct eb_posix_tcp_transport* transport;
  eb_posix_sock_t sock4, sock6;
  
  if (port) {
    sock4 = eb_posix_ip_open(PF_INET, SOCK_STREAM, port);
#ifdef EB_DISABLE_IPV6    
    sock6 = -1;
#else
    sock6 = eb_posix_ip_open(PF_INET6, SOCK_STREAM, port);
#endif
    if (sock4 == -1 && sock6 == -1) return EB_BUSY;
  
    if ((sock4 != -1 && listen(sock4, 5) != 0) ||
        (sock6 != -1 && listen(sock6, 5) != 0)) {
      eb_posix_ip_close(sock4);
      eb_posix_ip_close(sock6);
      return EB_ADDRESS; 
    }

    eb_posix_ip_force_non_blocking(sock4, 1);
    eb_posix_ip_force_non_blocking(sock6, 1);
  } else {
    /* No port? no TCP */
    sock4 = -1;
    sock6 = -1;
  }
  
  transport = (struct eb_posix_tcp_transport*)transportp;
  transport->port4 = sock4;
  transport->port6 = sock6;

  return EB_OK;
}

void eb_posix_tcp_close(struct eb_transport* transportp) {
  struct eb_posix_tcp_transport* transport;
  
  transport = (struct eb_posix_tcp_transport*)transportp;
  eb_posix_ip_close(transport->port4);
  eb_posix_ip_close(transport->port6);
}

eb_status_t eb_posix_tcp_connect(struct eb_transport* transportp, struct eb_link* linkp, const char* address, int passive) {
  struct eb_posix_tcp_link* link;
  struct sockaddr_storage sa;
  eb_posix_sock_t sock;
  socklen_t len;
  
  link = (struct eb_posix_tcp_link*)linkp;
  
  len = -1;
  if (len == -1) len = eb_posix_ip_resolve("tcp6/", address, PF_INET6, SOCK_STREAM, &sa);
  if (len == -1) len = eb_posix_ip_resolve("tcp4/", address, PF_INET,  SOCK_STREAM, &sa);
  if (len == -1) len = eb_posix_ip_resolve("tcp/",  address, PF_INET6, SOCK_STREAM, &sa);
  if (len == -1) len = eb_posix_ip_resolve("tcp/",  address, PF_INET,  SOCK_STREAM, &sa);
  if (len == -1) return EB_ADDRESS;
  
  sock = socket(sa.ss_family, SOCK_STREAM, IPPROTO_TCP);
  if (sock == -1) return EB_FAIL;
  
  if (connect(sock, (struct sockaddr*)&sa, len) != 0) {
    eb_posix_ip_close(sock);
    return EB_FAIL;
  }
  
  eb_posix_ip_set_buffer(sock, 0); /* Default to off (for fast slave responses) */
  link->socket = sock;
  return EB_OK;
}

void eb_posix_tcp_disconnect(struct eb_transport* transport, struct eb_link* linkp) {
  struct eb_posix_tcp_link* link;
  
  link = (struct eb_posix_tcp_link*)linkp;
  eb_posix_ip_close(link->socket);
}

void eb_posix_tcp_fdes(struct eb_transport* transportp, struct eb_link* linkp, eb_user_data_t data, eb_descriptor_callback_t cb) {
  struct eb_posix_tcp_transport* transport;
  struct eb_posix_tcp_link* link;
  
  if (linkp) {
    link = (struct eb_posix_tcp_link*)linkp;
    (*cb)(data, link->socket, EB_DESCRIPTOR_IN);
  } else {
    transport = (struct eb_posix_tcp_transport*)transportp;
    if (transport->port4 != -1) (*cb)(data, transport->port4, EB_DESCRIPTOR_IN);
    if (transport->port6 != -1) (*cb)(data, transport->port6, EB_DESCRIPTOR_IN);
  }
}

int eb_posix_tcp_accept(struct eb_transport* transportp, struct eb_link* result_linkp, eb_user_data_t data, eb_descriptor_callback_t ready) {
  struct eb_posix_tcp_transport* transport;
  struct eb_posix_tcp_link* result_link;
  eb_posix_sock_t sock;
  
  sock = -1;
  transport = (struct eb_posix_tcp_transport*)transportp;
  
  if (sock == -1 && transport->port4 != -1 && (*ready)(data, transport->port4, EB_DESCRIPTOR_IN)) {
    sock = accept(transport->port4, 0, 0);
    if (sock == -1 && !eb_posix_ip_ewouldblock()) return -1;
  }
  
  if (sock == -1 && transport->port6 != -1 && (*ready)(data, transport->port6, EB_DESCRIPTOR_IN)) {
    sock = accept(transport->port6, 0, 0);
    if (sock == -1 && !eb_posix_ip_ewouldblock()) return -1;
  }
  
  if (sock == -1) 
    return 0;
  
  if (result_linkp != 0) {
    eb_posix_ip_set_buffer(sock, 0); /* Default to off (for fast slave responses) */
    result_link = (struct eb_posix_tcp_link*)result_linkp;
    result_link->socket = sock;
    return 1;
  } else {
    eb_posix_ip_close(sock);
    return 0;
  }
}

int eb_posix_tcp_poll(struct eb_transport* transportp, struct eb_link* linkp, eb_user_data_t data, eb_descriptor_callback_t ready, uint8_t* buf, int len) {
  struct eb_posix_tcp_link* link;
  int result;
  
  if (linkp == 0) return 0;
  
  link = (struct eb_posix_tcp_link*)linkp;
  
  /* Should we check? */
  if (!(*ready)(data, link->socket, EB_DESCRIPTOR_IN))
    return 0;
  
  /* Set non-blocking */
  eb_posix_ip_non_blocking(link->socket, 1);
  
  result = recv(link->socket, (char*)buf, len, MSG_DONTWAIT);
  
  if (result == -1 && eb_posix_ip_ewouldblock()) return 0;
  if (result == 0) return -1;
  return result;
}

int eb_posix_tcp_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_posix_tcp_link* link;
  int result;
  
  if (linkp == 0) return 0;
  
  link = (struct eb_posix_tcp_link*)linkp;

  /* Set blocking */
  eb_posix_ip_non_blocking(link->socket, 0);

  result = recv(link->socket, (char*)buf, len, 0);
  
  /* EAGAIN impossible on blocking read */
  if (result == 0) return -1;
  return result;
}

void eb_posix_tcp_send(struct eb_transport* transportp, struct eb_link* linkp, const uint8_t* buf, int len) {
  struct eb_posix_tcp_link* link;
  
  /* linkp == 0 impossible if poll == 0 returns 0 */
  
  link = (struct eb_posix_tcp_link*)linkp;
  
  /* Set blocking */
  eb_posix_ip_non_blocking(link->socket, 0);

  send(link->socket, (const char*)buf, len, 0);
}

void eb_posix_tcp_send_buffer(struct eb_transport* transportp, struct eb_link* linkp, int on) {
  struct eb_posix_tcp_link* link;
  
  link = (struct eb_posix_tcp_link*)linkp;
  eb_posix_ip_set_buffer(link->socket, on);
}
