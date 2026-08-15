/** @file run.c
 *  @brief A mostly-portable implementation of eb_socket_run.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Implement eb_socket_block using select().
 *  This should work on any POSIX operating system.
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
#include "../glue/socket.h"
#include "../glue/device.h"
#include "../memory/memory.h"

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

long eb_socket_run(eb_socket_t socketp, long timeout_us) {
  struct eb_block_sets sets;
  struct timeval timeout, start, stop;
  long eb_deadline;
  long eb_timeout_us;
  int done;
  
  /* Find all descriptors */
  FD_ZERO(&sets.rfds);
  FD_ZERO(&sets.wfds);
  sets.nfd = 0;
  
  /* Determine the deadline */
  gettimeofday(&start, 0);
  
  /* !!! hack starts: until we fix sender flow control */
  done = eb_socket_check(socketp, start.tv_sec, &sets, &eb_check_sets);
  if (done > 0) return 0;
  /* !!! hack ends */
  
  eb_deadline = eb_socket_timeout(socketp);
  
  if (timeout_us == -1)
    timeout_us = 600*1000000; /* 10 minutes */
  
  if (eb_deadline != 0) {
    eb_timeout_us = (eb_deadline - start.tv_sec)*1000000;
    if (timeout_us > eb_timeout_us)
      timeout_us = eb_timeout_us;
  }
  
  if (timeout_us < 0) timeout_us = 0;
  
  /* This use of division is ok, because it will never be done on an LM32 */
  timeout.tv_sec  = timeout_us / 1000000;
  timeout.tv_usec = timeout_us % 1000000;
  
  eb_socket_descriptors(socketp, &sets, &eb_update_sets);
  
  select(sets.nfd+1, &sets.rfds, &sets.wfds, 0, &timeout);
  gettimeofday(&stop, 0);
  
  /* Update the timestamp cache */
  eb_socket_check(socketp, stop.tv_sec, &sets, &eb_check_sets);
  
  return (stop.tv_sec - start.tv_sec)*1000000 + (stop.tv_usec - start.tv_usec);
}
