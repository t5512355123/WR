/** @file posix-udp.c
 *  @brief This implements a UDP binding using posix sockets.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  UDP links all share the same socket, only recording the target address.
 *  At the moment the target address is dynamically allocated. (!!! fixme)
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

/* #define PACKET_DEBUG 1 */

#include "posix-ip.h"
#include "posix-udp.h"
#include "transport.h"
#include "../glue/socket.h"
#include "../glue/device.h"

#include <stdlib.h>
#include <string.h>
#ifdef PACKET_DEBUG
#include <stdio.h>
#endif

eb_status_t eb_posix_udp_open(struct eb_transport* transportp, const char* port) {
  struct eb_posix_udp_transport* transport;
  eb_posix_sock_t sock4, sock6;
  
  sock4 = eb_posix_ip_open(PF_INET, SOCK_DGRAM, port);
#ifdef EB_DISABLE_IPV6    
  sock6 = -1;
#else
  sock6 = eb_posix_ip_open(PF_INET6, SOCK_DGRAM, port);
#endif

  /* Failure if we can't get either protocol */
  if (sock4 == -1 && sock6 == -1) 
    return EB_BUSY;
  
  transport = (struct eb_posix_udp_transport*)transportp;
  transport->socket4 = sock4;
  transport->socket6 = sock6;
  
  return EB_OK;
}

void eb_posix_udp_close(struct eb_transport* transportp) {
  struct eb_posix_udp_transport* transport;
  
  transport = (struct eb_posix_udp_transport*)transportp;
  eb_posix_ip_close(transport->socket4);
  eb_posix_ip_close(transport->socket6);
}

eb_status_t eb_posix_udp_connect(struct eb_transport* transportp, struct eb_link* linkp, const char* address, int passive) {
  struct eb_posix_udp_transport* transport;
  struct eb_posix_udp_link* link;
  struct sockaddr_storage sa;
  socklen_t len;
  
  len = -1;
  if (len == -1) len = eb_posix_ip_resolve("udp4/", address, PF_INET,  SOCK_DGRAM, &sa);
#ifndef EB_DISABLE_IPV6
  if (len == -1) len = eb_posix_ip_resolve("udp6/", address, PF_INET6, SOCK_DGRAM, &sa);
  if (len == -1) len = eb_posix_ip_resolve("udp/",  address, PF_INET6, SOCK_DGRAM, &sa);
#endif
  if (len == -1) len = eb_posix_ip_resolve("udp/",  address, PF_INET,  SOCK_DGRAM, &sa);
  if (len == -1) return EB_ADDRESS;
  
  transport = (struct eb_posix_udp_transport*)transportp;
  link = (struct eb_posix_udp_link*)linkp;

  /* Do we have support for the socket? */
  if (sa.ss_family == PF_INET  && transport->socket4 == -1) return EB_FAIL;
#ifndef EB_DISABLE_IPV6
  if (sa.ss_family == PF_INET6 && transport->socket6 == -1) return EB_FAIL;
#endif

  link->sa = (struct sockaddr_storage*)malloc(sizeof(struct sockaddr_storage));
  link->sa_len = len;
  
  memcpy(link->sa, &sa, len);
  
  return EB_OK;
}

void eb_posix_udp_disconnect(struct eb_transport* transport, struct eb_link* linkp) {
  struct eb_posix_udp_link* link;

  link = (struct eb_posix_udp_link*)linkp;
  free(link->sa);
}

void eb_posix_udp_fdes(struct eb_transport* transportp, struct eb_link* linkp, eb_user_data_t data, eb_descriptor_callback_t cb) {
  struct eb_posix_udp_transport* transport;
  
  transport = (struct eb_posix_udp_transport*)transportp;
  if (linkp == 0) {
    if (transport->socket4 != -1) (*cb)(data, transport->socket4, EB_DESCRIPTOR_IN);
#ifndef EB_DISABLE_IPV6
    if (transport->socket6 != -1) (*cb)(data, transport->socket6, EB_DESCRIPTOR_IN);
#endif
  } else {
    /* no per-link socket */
  }
}

int eb_posix_udp_accept(struct eb_transport* transportp, struct eb_link* result_linkp, eb_user_data_t data, eb_descriptor_callback_t ready) {
  /* UDP does not make child connections */
  return 0;
}

/* !!! global is not the best approach. break multi-threading. */
static struct sockaddr_storage eb_posix_udp_sa;
static socklen_t eb_posix_udp_sa_len;

int eb_posix_udp_poll(struct eb_transport* transportp, struct eb_link* linkp, eb_user_data_t data, eb_descriptor_callback_t ready, uint8_t* buf, int len) {
  struct eb_posix_udp_transport* transport;
  int result;
  
  if (linkp != 0) return 0; /* Only recv top-level */
  
  transport = (struct eb_posix_udp_transport*)transportp;
  
  /* Set non-blocking */
  eb_posix_ip_non_blocking(transport->socket4, 1);
  eb_posix_ip_non_blocking(transport->socket6, 1);
  
  if (transport->socket4 != -1 && (*ready)(data, transport->socket4, EB_DESCRIPTOR_IN)) {
    eb_posix_udp_sa_len = sizeof(eb_posix_udp_sa);
    result = recvfrom(transport->socket4, (char*)buf, len, MSG_DONTWAIT, (struct sockaddr*)&eb_posix_udp_sa, &eb_posix_udp_sa_len);
    if (result == -1 && !eb_posix_ip_ewouldblock()) return -1;
    if (result != -1) return result;
  }
  
  if (transport->socket6 != -1 && (*ready)(data, transport->socket6, EB_DESCRIPTOR_IN)) {
    eb_posix_udp_sa_len = sizeof(eb_posix_udp_sa);
    result = recvfrom(transport->socket6, (char*)buf, len, MSG_DONTWAIT, (struct sockaddr*)&eb_posix_udp_sa, &eb_posix_udp_sa_len);
    if (result == -1 && !eb_posix_ip_ewouldblock()) return -1;
    if (result != -1) return result;
  }
  
  return 0;
}

int eb_posix_udp_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  /* Should never happen on a non-stream socket */
  return -1;
}

void eb_posix_udp_send(struct eb_transport* transportp, struct eb_link* linkp, const uint8_t* buf, int len) {
  struct eb_posix_udp_transport* transport;
  struct eb_posix_udp_link* link;
  
#ifdef PACKET_DEBUG
  int i;
  fprintf(stderr, "<---- ");
  for (i = 0; i < len; ++i) fprintf(stderr, "%02x", buf[i]);
  fprintf(stderr, "\n");
#endif

  transport = (struct eb_posix_udp_transport*)transportp;
  link = (struct eb_posix_udp_link*)linkp;
  
  
  if (link == 0) {
    if (eb_posix_udp_sa.ss_family == PF_INET6) {
      eb_posix_ip_non_blocking(transport->socket6, 0);
      sendto(transport->socket6, (const char*)buf, len, 0, (struct sockaddr*)&eb_posix_udp_sa, eb_posix_udp_sa_len);
    } else {
      eb_posix_ip_non_blocking(transport->socket4, 0);
      sendto(transport->socket4, (const char*)buf, len, 0, (struct sockaddr*)&eb_posix_udp_sa, eb_posix_udp_sa_len);
    }
  } else {
    if (link->sa->ss_family == PF_INET6) {
      eb_posix_ip_non_blocking(transport->socket6, 0);
      sendto(transport->socket6, (const char*)buf, len, 0, (struct sockaddr*)link->sa, link->sa_len);
    } else {
      eb_posix_ip_non_blocking(transport->socket4, 0);
      sendto(transport->socket4, (const char*)buf, len, 0, (struct sockaddr*)link->sa, link->sa_len);
    }
  }
}

void eb_posix_udp_send_buffer(struct eb_transport* transportp, struct eb_link* linkp, int on) {
  /* no-op */
}
