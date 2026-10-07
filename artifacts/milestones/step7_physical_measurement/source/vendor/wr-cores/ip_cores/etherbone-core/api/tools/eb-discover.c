/** @file eb-discover.c
 *  @brief A tool for discovering Etherbone devices on a network.
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

#include "../transport/posix-udp.h"

#include <unistd.h> /* getopt */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __WIN32
#include <winsock2.h>
#endif

static const char* width_str[16] = {
 /*  0 */ "<null>",
 /*  1 */ "8",
 /*  2 */ "16",
 /*  3 */ "8/16",
 /*  4 */ "32",
 /*  5 */ "8/32",
 /*  6 */ "16/32",
 /*  7 */ "8/16/32",
 /*  8 */ "64",
 /*  9 */ "8/64",
 /* 10 */ "16/64",
 /* 11 */ "8/16/64",
 /* 12 */ "32/64",
 /* 13 */ "8/32/64",
 /* 14 */ "16/32/64",
 /* 15 */ "8/16/32/64"
};

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

static void check(int sock) {
  struct sockaddr_storage ss;
  socklen_t sslen;
  uint8_t buf[8];
  int width;
  char host[256], port[256];
  
  sslen = sizeof(ss);
  eb_posix_ip_non_blocking(sock, 1);
  if (recvfrom(sock, (char*)&buf[0], 8, MSG_DONTWAIT, (struct sockaddr*)&ss, &sslen) != 8) return;
  if (buf[0] != 0x4E || buf[1] != 0x6F) return;
  
  if (getnameinfo((struct sockaddr*)&ss, sslen, host, sizeof(host), port, sizeof(port), NI_DGRAM) != 0) {
    strcpy(host, "unknown");
    strcpy(port, "0");
  }
  
  width = printf("udp%d/%s/%s", (ss.ss_family==PF_INET6)?6:4, host, port);
  if (width < 33) 
    fwrite("                                      ", 1, 33-width, stdout);
  
  printf(" V.%d; data=%s-bit addr=%s-bit\n", 
    buf[2] >> 4, width_str[buf[3] & EB_DATAX], width_str[buf[3] >> 4]);
}

int main(int argc, char** argv) {
  struct eb_posix_udp_transport udp_transport;
  struct eb_link udp_link;
  struct timeval tv;
  struct eb_block_sets sets;
  struct eb_transport* transport;
  uint8_t discover[8];
  eb_status_t status;
#ifdef  __WIN32
  WORD wVersionRequested;
  WSADATA wsaData;
#endif
  
  if (argc != 2) {
    fprintf(stderr, "%s: missing non-optional argument -- <broadcast-address>\n", argv[0]);
    return 1;
  }
  
#ifdef __WIN32
  wVersionRequested = MAKEWORD(2, 2);
  if (WSAStartup(wVersionRequested, &wsaData) != 0) {
    perror("Cannot initialize winsock");
    return 1;
  }
#endif
  
  transport = (struct eb_transport*)&udp_transport;
  
  if ((status = eb_posix_udp_open(transport, 0)) != EB_OK) {
    perror("Cannot open UDP port");
    return 1;
  }
  
  if ((status = eb_posix_udp_connect(transport, &udp_link, argv[1], 0)) != EB_OK) {
    perror("Cannot resolve address");
    return 1;
  }
  
  discover[0] = 0x4E;
  discover[1] = 0x6F;
  discover[2] = 0x11; /* V1 probe */
  discover[3] = 0xFF; /* Any device will do */
  memset(&discover[4], 0, 4);
  
  /* Send the discovery packet */
  eb_posix_udp_send(transport, &udp_link, &discover[0], 8);
  
  while (1) {
    FD_ZERO(&sets.rfds);
    FD_ZERO(&sets.wfds);
    sets.nfd = 0;
    eb_posix_udp_fdes(transport, 0, &sets, &eb_update_sets);
  
    tv.tv_sec = 1;
    tv.tv_usec = 0;
    
    if (select(sets.nfd+1, &sets.rfds, &sets.wfds, 0, &tv) <= 0) break; /* timeout */
    check(udp_transport.socket4);
    check(udp_transport.socket6);
  }
  
  return 0;
}
