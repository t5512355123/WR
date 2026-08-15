/** @file tunnel.c
 *  @brief This implements a UDP tunnel over TCP.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Etherbone over tunnel is implemented using a helper process.
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
#include "posix-tcp.h"
#include "tunnel.h"
#include "../glue/strncasecmp.h"

#include <string.h>

eb_status_t eb_tunnel_open(struct eb_transport* transportp, const char* port) {
  /* noop */
  return EB_OK;
}

void eb_tunnel_close(struct eb_transport* transportp) {
  /* noop */
}

eb_status_t eb_tunnel_connect(struct eb_transport* transportp, struct eb_link* linkp, const char* address, int passive) {
  const char* slash;
  const char* host;
  const char* service;
  char tcpname[250];
  eb_status_t err;
  int len;
  
  if      (!eb_strncasecmp(address, "tunnel/",  7)) host = address + 7;
  else if (!eb_strncasecmp(address, "tunnel6/", 8)) host = address + 8;
  else if (!eb_strncasecmp(address, "tunnel4/", 8)) host = address + 8;
  else return EB_ADDRESS;
  
  if ((slash = strchr(host, '/')) == 0)
    return EB_ADDRESS;
  
  if ((slash = strchr(slash+1, '/')) == 0)
    return EB_ADDRESS;
  service = slash + 1;
  
  len = slash - host;
  if (len + 7 >= sizeof(tcpname))
    return EB_ADDRESS;
  
  strcpy(tcpname, "tcp");
  strncat(tcpname, address + 6, host-(address+6));
  strncat(tcpname, host, slash-host);
  
  if ((err = eb_posix_tcp_connect(0, linkp, tcpname, passive)) != EB_OK) return err;
  
  eb_posix_tcp_send(0, linkp, (const uint8_t*)service, strlen(service)+1);
  return EB_OK;
}

void eb_tunnel_disconnect(struct eb_transport* transportp, struct eb_link* linkp) {
  eb_posix_tcp_disconnect(0, linkp);
}

void eb_tunnel_fdes(struct eb_transport* transportp, struct eb_link* linkp, eb_user_data_t data, eb_descriptor_callback_t cb) {
  if (linkp == 0) return;
  return eb_posix_tcp_fdes(0, linkp, data, cb);
}

int eb_tunnel_accept(struct eb_transport* transportp, struct eb_link* result_linkp, eb_user_data_t data, eb_descriptor_callback_t ready) {
  /* Tunnel does not make child connections */
  return 0;
}

int eb_tunnel_poll(struct eb_transport* transportp, struct eb_link* linkp, eb_user_data_t data, eb_descriptor_callback_t ready, uint8_t* buf, int maxlen) {
  int len;
  uint8_t len_buf[2];
  
  /* No top-level to poll */
  if (linkp == 0) return 0;
  
  if ((len = eb_posix_tcp_poll(0, linkp, data, ready, &len_buf[0], 2)) <= 0)
    return len;
  
  if (len == 1) {
    if (eb_posix_tcp_recv(0, linkp, &len_buf[1], 1) != 1)
      return -1;
  }
  
  len = ((unsigned int)len_buf[0]) << 8 | len_buf[1];
  if (len > maxlen) return -1;
  
  if (eb_posix_tcp_recv(0, linkp, buf, len) != len)
    return -1;
  
  return len;
}

int eb_tunnel_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  /* Should never happen on a non-stream socket */
  return -1;
}

void eb_tunnel_send(struct eb_transport* transportp, struct eb_link* linkp, const uint8_t* buf, int len) {
  uint8_t len_buf[2];
  len_buf[0] = (len >> 8) & 0xFF;
  len_buf[1] = len & 0xFF;
  
  /* Not super efficient, but it will get the job done */
  eb_posix_tcp_send_buffer(0, linkp, 1);
  eb_posix_tcp_send(0, linkp, &len_buf[0], 2);
  eb_posix_tcp_send(0, linkp, buf, len);
  eb_posix_tcp_send_buffer(0, linkp, 0);
}

void eb_tunnel_send_buffer(struct eb_transport* transportp, struct eb_link* linkp, int on) {
  /* no-op */
}
