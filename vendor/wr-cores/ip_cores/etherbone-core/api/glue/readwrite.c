/** @file readwrite.c
 *  @brief Process incoming Etherbone read/writes.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  All methods can assume eb_width_refined.
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

#include "readwrite.h"
#include "socket.h"
#include "cycle.h"
#include "operation.h"
#include "sdb.h"
#include "../memory/memory.h"
#include "../format/bigendian.h"

int eb_socket_write_config(eb_socket_t socketp, eb_width_t widths, eb_address_t addr, eb_data_t value) {
  /* Write to config space => write-back */
  int fail;
  eb_response_t *responsepp;
  eb_response_t responsep;
  eb_operation_t operationp;
  eb_cycle_t cyclep;
  eb_status_t status;
  struct eb_socket* socket;
  struct eb_response* response;
  struct eb_operation* operation;
  struct eb_cycle* cycle;
  
  /* Walk the response queue */
  socket = EB_SOCKET(socketp);
  responsepp = &socket->first_response;
  while (1) {
    if ((responsep = *responsepp) == EB_NULL) {
      *responsepp = responsep = eb_response_flip(socket->last_response);
      socket->last_response = EB_NULL;
      if (responsep == EB_NULL) return 0; /* No matching response record */
    }
    response = EB_RESPONSE(responsep);
    
    if (response->address == (addr & 0xFFFE)) break;
    responsepp = &response->next;
  }
  
  /* Now, process the write */
  if ((addr & 1) == 0) {
    /* A write_cursor update */
    if (response->write_cursor == EB_NULL) {
      fail = 1;
    } else {
      fail = 0;
      
      operation = EB_OPERATION(response->write_cursor);
      
      if ((operation->flags & EB_OP_MASK) == EB_OP_READ_PTR) {
        *operation->un_value.read_destination = value;
      } else {
        operation->un_value.read_value = value;
      }
      
      response->write_cursor = eb_find_read(operation->next);
    }
  } else {
    /* An error status update */
    int i, ops, maxops;
    
    /* Maximum feed-back from this read */
    maxops = (widths & EB_DATAX) * 8;
    
    /* Count how many operations need a status update */
    ops = 0;
    for (operationp = response->status_cursor; operationp != EB_NULL; operationp = operation->next) {
      operation = EB_OPERATION(operationp);
      if ((operation->flags & EB_OP_CFG_SPACE) != 0) continue; /* skip config ops */
      if (++ops == maxops) break;
    }
    
    fail = (ops == 0); /* No reason to get error status if no ops! */
    
    i = ops-1;
    for (operationp = response->status_cursor; i >= 0; operationp = operation->next) {
      operation = EB_OPERATION(operationp);
      if ((operation->flags & EB_OP_CFG_SPACE) != 0) continue;
      operation->flags |= EB_OP_ERROR * ((value >> i) & 1);
      --i;
    }
    
    /* Update the cursor... skipping cfg space operations */
    response->status_cursor = eb_find_bus(operationp);
  }
  
  /* Check for response completion */
  if (fail || (response->write_cursor == EB_NULL && response->status_cursor == EB_NULL)) {
    cyclep = response->cycle;
    cycle = EB_CYCLE(cyclep);

    *responsepp = response->next;
    
    /* Detect segfault */
    status = EB_OK;
    for (operationp = cycle->un_ops.first; operationp != EB_NULL; operationp = operation->next) {
      operation = EB_OPERATION(operationp);
      if ((operation->flags & EB_OP_ERROR) != 0) status = EB_SEGFAULT;
    }
    
    (*cycle->callback)(cycle->user_data, cycle->un_link.device, cycle->un_ops.first, fail?EB_FAIL:status);

    eb_cycle_destroy(cyclep);
    eb_free_cycle(cyclep);
    eb_free_response(responsep);
    return 1;
  } else {
    return 0;
  }
}

void eb_socket_write(eb_socket_t socketp, eb_width_t widths, eb_address_t addr_b, eb_address_t addr_l, eb_data_t value, uint64_t* error) {
  /* Write to local WB bus */
  eb_handler_address_t addressp;
  struct eb_handler_address* address;
  struct eb_socket* socket;
  eb_address_t dev_first, dev_last;
  int fail;
  
  socket = EB_SOCKET(socketp);
  for (addressp = socket->first_handler; addressp != EB_NULL; addressp = address->next) {
    address = EB_HANDLER_ADDRESS(addressp);
    dev_first = address->device->sdb_component.addr_first;
    dev_last  = address->device->sdb_component.addr_last;
    if (dev_first <= addr_b && addr_b <= dev_last) break;
  }
  
  if (addressp == EB_NULL) {
    /* Segfault => shift in an error */
    fail = 1;
  } else {
    struct eb_handler_callback* callback = EB_HANDLER_CALLBACK(address->callback);
    if (callback->write) {
      /* Run the virtual device */
      if ((address->device->bus_specific & SDB_WISHBONE_LITTLE_ENDIAN) != 0)
        fail = (*callback->write)(callback->data, addr_l, widths, value) != EB_OK;
      else
        fail = (*callback->write)(callback->data, addr_b, widths, value) != EB_OK;
    } else {
      /* Not writeable => error */
      fail = 1;
    }
  }
  
  /* Update the error shift status */
  *error = (*error << 1) | fail;
}

eb_data_t eb_socket_read_config(eb_socket_t socketp, eb_width_t widths, eb_address_t addr, uint64_t error) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  eb_address_t sdb;
  
  socket = EB_SOCKET(socketp);
  aux = EB_SOCKET_AUX(socket->aux);
  sdb = aux->sdb_offset;
  
  /* We only support reading from the error shift register and SDB so far */
  eb_data_t out;
  int len;
  uint8_t buf[16] = {
    error >> 56, error >> 48, error >> 40, error >> 32,
    error >> 24, error >> 16, error >>  8, error >>  0,
    sdb   >> 56, sdb   >> 48, sdb   >> 40, sdb   >> 32,
    sdb   >> 24, sdb   >> 16, sdb   >>  8, sdb   >>  0,
  };
  
  len = (widths & EB_DATAX);
  
  /* Read out of bounds */
  if (addr >= 16) return 0;
  
  /* Read memory -- config space always bigendian */
  out = 0;
  while (len--) {
    out <<= 8;
    out |= buf[addr++];
  }
  
  return out;
}

eb_data_t eb_socket_read(eb_socket_t socketp, eb_width_t widths, eb_address_t addr_b, eb_address_t addr_l, uint64_t* error) {
  /* Read to local WB bus */
  eb_data_t out;
  eb_handler_address_t addressp;
  struct eb_handler_address* address;
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  eb_address_t dev_first, dev_last;
  eb_address_t sdb;
  int fail;
  
  socket = EB_SOCKET(socketp);
  aux = EB_SOCKET_AUX(socket->aux);
  sdb = aux->sdb_offset;
  
  /* SDB address? */
  if (addr_b >= sdb && addr_b < sdb + SDB_REQUIRED_SIZE) {
    *error = (*error << 1);
    return eb_sdb(socketp, widths, addr_b-sdb); /* always bigendian */
  }
  
  for (addressp = socket->first_handler; addressp != EB_NULL; addressp = address->next) {
    address = EB_HANDLER_ADDRESS(addressp);
    dev_first = address->device->sdb_component.addr_first;
    dev_last  = address->device->sdb_component.addr_last;
    if (dev_first <= addr_b && addr_b <= dev_last) break;
  }
  
  if (addressp == EB_NULL) {
    /* Segfault => shift in an error */
    out = 0;
    fail = 1;
  } else {
    struct eb_handler_callback* callback = EB_HANDLER_CALLBACK(address->callback);
    if (callback->read) {
      /* Run the virtual device */
      if ((address->device->bus_specific & SDB_WISHBONE_LITTLE_ENDIAN) != 0)
        fail = (*callback->read)(callback->data, addr_l, widths, &out) != EB_OK;
      else
        fail = (*callback->read)(callback->data, addr_b, widths, &out) != EB_OK;
    } else {
      /* Not readable => error */
      out = 0;
      fail = 1;
    }
  }
  
  /* Update the error shift status */
  *error = (*error << 1) | fail;
  return out;
}
