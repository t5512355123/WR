/** @file eb-tunnel.c
 *  @brief A gateway which bridges Etherbone from streams to UDP.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  A complete skeleton of an application using the Etherbone library.
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

#include "../transport/posix-ip.h"
#include "../transport/posix-udp.h"
#include "../transport/posix-tcp.h"
#include "../transport/transport.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef __WIN32
#include <winsock2.h>
#endif

#define MAX_MTU 4096

struct eb_client {
  struct eb_transport udp_transport;
  struct eb_link udp_slave;
  struct eb_link tcp_master;
  struct eb_client* next;
};

static struct eb_client* eb_new_client(struct eb_transport* tcp_transport, struct eb_client* next) {
  struct eb_client* first;
  char address[128];
  int x;
  
  /* Allocate a new head pointer */
  if ((first = (struct eb_client*)malloc(sizeof(struct eb_client))) == 0) goto fail_mem;
  first->next = next;
  
  /* Extract the target hostname */
  strcpy(address, "udp/"); /* We only tunnel udp */
  for (x = strlen(address);
       eb_posix_tcp_recv(tcp_transport, &next->tcp_master, (uint8_t*)&address[x], 1) == 1;
       ++x) {
    if (address[x] == 0) break;
    if (x == sizeof(address)-1) break;
  }
  
  if (address[x] != 0) goto fail_address;
  
  if (eb_posix_udp_open(&next->udp_transport, 0) != EB_OK) goto fail_transport;
  if (eb_posix_udp_connect(&next->udp_transport, &next->udp_slave, address, 0) != EB_OK) goto fail_link;
  
  return first;

fail_link:
  eb_posix_udp_close(&next->udp_transport);
fail_transport:
  free(first);
fail_address:
fail_mem:
  eb_posix_tcp_disconnect(tcp_transport, &next->tcp_master);
  return next;
}  

struct eb_block_sets {
  int nfd;
  fd_set rfds;
  fd_set wfds;
};

static int eb_update_sets(eb_user_data_t data, eb_descriptor_t fd, uint8_t mode) {
  struct eb_block_sets* set = (struct eb_block_sets*)data;
  
  if (fd > set->nfd) set->nfd = fd;
  
  if ((mode & EB_DESCRIPTOR_IN)  != 0) FD_SET(fd, &set->rfds);
  if ((mode & EB_DESCRIPTOR_OUT) != 0) FD_SET(fd, &set->wfds);
  
  return 0;
}

static int eb_check_sets(eb_user_data_t data, eb_descriptor_t fd, uint8_t mode) {
  struct eb_block_sets* set = (struct eb_block_sets*)data;
  
  return 
    (((mode & EB_DESCRIPTOR_IN)  != 0) && FD_ISSET(fd, &set->rfds)) ||
    (((mode & EB_DESCRIPTOR_OUT) != 0) && FD_ISSET(fd, &set->wfds));
}

int main(int argc, const char** argv) {
  struct eb_block_sets sets;
  struct eb_transport tcp_transport;
  struct eb_client* first;
  struct eb_client* client;
  struct eb_client* next;
  struct eb_client* prev;
  int len, fail;
  eb_status_t err;
  uint8_t buffer[MAX_MTU+2];
  uint8_t len_buf[2];
#ifdef  __WIN32
  WORD wVersionRequested;
  WSADATA wsaData;
#endif
  
  if (argc != 2) {
    fprintf(stderr, "Syntax: %s <proxy-port>\n", argv[0]);
    return 1;
  }
  
#ifdef __WIN32
  wVersionRequested = MAKEWORD(2, 2);
  if (WSAStartup(wVersionRequested, &wsaData) != 0) {
    perror("Cannot initialize winsock");
    return 1;
  }
#endif
  
  if ((err = eb_posix_tcp_open(&tcp_transport, argv[1])) != EB_OK) {
    perror("Cannot open TCP port");
    return 1;
  }
  
  first = (struct eb_client*)malloc(sizeof(struct eb_client));
  if (first == 0) {
    perror("Allocating initial link");
    return 1;
  }
  first->next = 0;
  
  while (1) {
    /* Block for a link to go active: */
    FD_ZERO(&sets.rfds);
    FD_ZERO(&sets.wfds);
    sets.nfd = 0;
    
    /* All all descriptors to blocking list */
    eb_posix_tcp_fdes(&tcp_transport, 0, &sets, &eb_update_sets);
    
    for (client = first->next; client != 0; client = client->next) {
      eb_posix_tcp_fdes(&tcp_transport, &client->tcp_master, &sets, &eb_update_sets);
      eb_posix_udp_fdes(&client->udp_transport, 0, &sets, &eb_update_sets);
    }
    
    /* Wait for one to go active: */
    select(sets.nfd+1, &sets.rfds, &sets.wfds, 0, 0);
    
    /* Now poll all links: */
    
    /* TCP accept? */
    len = 0;
    while ((len = eb_posix_tcp_accept(&tcp_transport, &first->tcp_master, &sets, &eb_check_sets)) > 0) {
      first = eb_new_client(&tcp_transport, first);
    }
    if (len < 0) {
      perror("Failed to accept a connection");
      break;
    }
    
    prev = first;
    for (client = prev->next; client != 0; client = next) {
      next = client->next;
      
      fail = 0;
      
      len = 0;
      while ((len = eb_posix_udp_poll(&client->udp_transport, 0, &sets, &eb_check_sets, &buffer[2], MAX_MTU)) > 0) {
        buffer[0] = (len >> 8) & 0xFF;
        buffer[1] = len & 0xFF;
      
        eb_posix_tcp_send(&tcp_transport, &client->tcp_master, &buffer[0], len+2);
      }
      if (len < 0) fail = 1;
      
      len = 0;
      while ((len = eb_posix_tcp_poll(&tcp_transport, &client->tcp_master, &sets, &eb_check_sets, &len_buf[0], 2)) > 0) {
        if (len == 1)
          len += eb_posix_tcp_recv(&tcp_transport, &client->tcp_master, &len_buf[1], 1);
        
        if (len != 2) {
          fail = 1;
          break;
        }
        
        len = ((unsigned int)len_buf[0]) << 8 | len_buf[1];
        if (len > MAX_MTU) {
          fail = 1;
          break;
        } 
        
        if (eb_posix_tcp_recv(&tcp_transport, &client->tcp_master, &buffer[0], len) != len) {
          fail = 1;
          break;
        }
        
        eb_posix_udp_send(&client->udp_transport, &client->udp_slave, &buffer[0], len);
      }
      if (len < 0) fail = 1;
      
      if (fail) {
        eb_posix_tcp_disconnect(&tcp_transport, &client->tcp_master);
        eb_posix_udp_disconnect(&client->udp_transport, &client->udp_slave);
        eb_posix_udp_close(&client->udp_transport);
        prev->next = client->next;
        free(client);
      } else {
        prev = client;
      }
    }
  }
  
  return 1;
}
