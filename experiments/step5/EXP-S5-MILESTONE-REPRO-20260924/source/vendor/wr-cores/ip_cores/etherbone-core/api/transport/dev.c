/** @file dev.c
 *  @brief This implements a charcter device interface.
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

#ifndef __WIN32

#include "dev.h"
#include "transport.h"
#include "../glue/strncasecmp.h"

#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <termios.h>

#ifndef O_BINARY
#define O_BINARY 0
#endif

static void eb_dev_set_blocking(struct eb_dev_link* link, int block) {
  int flags;
  
  flags = (link->flags & ~O_NONBLOCK) | (block?0:O_NONBLOCK);
  if (flags != link->flags) {
    fcntl(link->fdes, F_SETFL, flags);
    link->flags = flags;
  }
}

static int eb_dev_ewouldblock() {
  return (errno == EAGAIN || errno == EWOULDBLOCK);
}

eb_status_t eb_dev_open(struct eb_transport* transportp, const char* port) {
  /* noop */
  return EB_OK;
}

void eb_dev_close(struct eb_transport* transportp) {
  /* noop */
}

eb_status_t eb_dev_connect(struct eb_transport* transportp, struct eb_link* linkp, const char* address, int passive) {
  struct eb_dev_link* link;
  struct termios ios;
  const char* devname;
  char devpath[256];
  char junk[256];
  int fdes;
  
  link = (struct eb_dev_link*)linkp;
  
  if (eb_strncasecmp(address, "dev/", 4))
    return EB_ADDRESS;
  
  devname = address + 4;
  if (strlen(devname) > 200)
    return EB_ADDRESS;
  
  strcpy(devpath, "/dev/");
  strncat(devpath, devname, sizeof(devpath)-8);
  
  if ((fdes = open(devpath, O_BINARY | O_RDWR)) == -1) {
    return EB_FAIL;
  }
  
  link->fdes = fdes;
  link->flags = fcntl(fdes, F_GETFL, 0);

  // If this is a serial device, enter raw mode
  if (tcgetattr(fdes, &ios) == 0) {
    cfmakeraw(&ios);
    cfsetispeed(&ios, B115200);
    cfsetospeed(&ios, B115200);
    tcsetattr(fdes, TCSANOW, &ios);
  }
  
  eb_dev_set_blocking(link, 0);
  /* Discard any data unread by last user */
  if (!passive) {
    usleep(10000); /* 10 ms */
    while (read(fdes, junk, sizeof(junk)) > 0) { }
  }
  
  return EB_OK;
}

void eb_dev_disconnect(struct eb_transport* transport, struct eb_link* linkp) {
  struct eb_dev_link* link;
  
  link = (struct eb_dev_link*)linkp;
  close(link->fdes);
}

void eb_dev_fdes(struct eb_transport* transportp, struct eb_link* linkp, eb_user_data_t data, eb_descriptor_callback_t cb) {
  struct eb_dev_link* link;
  
  if (linkp) {
    link = (struct eb_dev_link*)linkp;
    (*cb)(data, link->fdes, EB_DESCRIPTOR_IN);
  }
}

int eb_dev_accept(struct eb_transport* transportp, struct eb_link* result_linkp, eb_user_data_t data, eb_descriptor_callback_t ready) {
  /* Dev does not make child connections */
  return 0;
}

int eb_dev_poll(struct eb_transport* transportp, struct eb_link* linkp, eb_user_data_t data, eb_descriptor_callback_t ready, uint8_t* buf, int len) {
  struct eb_dev_link* link;
  int result;
  
  if (linkp == 0) return 0;
  
  link = (struct eb_dev_link*)linkp;
  
  /* Should we check? */
  if (!(*ready)(data, link->fdes, EB_DESCRIPTOR_IN))
    return 0;
  
  /* Set non-blocking */
  eb_dev_set_blocking(link, 0);
  result = read(link->fdes, (char*)buf, len);
  
  if (result == -1 && eb_dev_ewouldblock()) return 0;
  if (result == 0) return -1;
  return result;
}

int eb_dev_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_dev_link* link;
  int result;
  
  if (linkp == 0) return 0;
  
  link = (struct eb_dev_link*)linkp;

  /* Set blocking */
  eb_dev_set_blocking(link, 1);

  result = read(link->fdes, buf, len);
  
  /* EAGAIN impossible on blocking read */
  if (result == 0) return -1;
  return result;
}

void eb_dev_send(struct eb_transport* transportp, struct eb_link* linkp, const uint8_t* buf, int len) {
  struct eb_dev_link* link;
  
  /* linkp == 0 impossible if poll == 0 returns 0 */
  
  link = (struct eb_dev_link*)linkp;
  
  /* Set blocking */
  eb_dev_set_blocking(link, 1);

  write(link->fdes, buf, len);
}

void eb_dev_send_buffer(struct eb_transport* transportp, struct eb_link* linkp, int on) {
  /* noop */
}

#endif
