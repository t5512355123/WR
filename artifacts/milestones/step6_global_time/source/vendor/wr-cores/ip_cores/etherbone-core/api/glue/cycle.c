/** @file cycle.c
 *  @brief Implement the Etherbone cycle data structure.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  The only fishy business is the use of 'dead' to mark cycles which
 *  run out of memory when enqueueing operations.
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

#include "operation.h"
#include "cycle.h"
#include "device.h"
#include "../memory/memory.h"

static void eb_block_f(eb_user_data_t user, eb_device_t device, eb_operation_t operation, eb_status_t status) {
  eb_status_t* ptr = (eb_status_t*)user;
  *ptr = status;
}

eb_device_t eb_cycle_device(eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  
  cycle = EB_CYCLE(cyclep);
  return cycle->un_link.device;
}

eb_status_t eb_cycle_open(eb_device_t devicep, eb_user_data_t user, eb_callback_t cb, eb_cycle_t* result) {
  eb_cycle_t cyclep;
  struct eb_cycle* cycle;
  struct eb_device* device;
  
  cyclep = eb_new_cycle();
  if (cyclep == EB_NULL) {
    *result = EB_NULL;
    return EB_OOM;
  }
  
  device = EB_DEVICE(devicep);
  
  /* Is the device closing? */
  if (device->un_link.passive == devicep) {
    eb_free_cycle(cyclep);
    *result = EB_NULL;
    return EB_FAIL;
  }
  
  cycle = EB_CYCLE(cyclep);
  cycle->user_data = user;
  cycle->un_ops.first = EB_NULL;
  cycle->un_link.device = devicep;
  
  if (cb) {
    cycle->callback = cb;
  } else {
    cycle->callback = &eb_block_f;
  }
  
  ++device->unready;
    
  *result = cyclep;
  return EB_OK;
}

void eb_cycle_destroy(eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  eb_operation_t i, next;
  
  cycle = EB_CYCLE(cyclep);
  
  if (cycle->un_ops.dead != cyclep) {
    for (i = cycle->un_ops.first; i != EB_NULL; i = next) {
      next = EB_OPERATION(i)->next;
      eb_free_operation(i);
    }
  }
  
  cycle->un_ops.first = EB_NULL;
}

void eb_cycle_abort(eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  struct eb_device* device;
  
  cycle = EB_CYCLE(cyclep);
  device = EB_DEVICE(cycle->un_link.device);
  --device->unready;
  
  eb_cycle_destroy(cyclep);
  eb_free_cycle(cyclep);
}

static void eb_raw_cycle_close(eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  struct eb_operation* op;
  struct eb_device* device;
  eb_operation_t prev, i, next;
  
  cycle = EB_CYCLE(cyclep);
  device = EB_DEVICE(cycle->un_link.device);

  /* Reverse the linked-list so it's FIFO */
  if (cycle->un_ops.dead != cyclep) {
    prev = EB_NULL;
    for (i = cycle->un_ops.first; i != EB_NULL; i = next) {
      op = EB_OPERATION(i);
      next = op->next;
      op->next = prev;
      prev = i;
    }
    cycle->un_ops.first = prev;
  }
  
  /* Queue us to the device */
  cycle->un_link.next = device->un_link.ready;
  device->un_link.ready = cyclep;
  
  /* Remove us from the incomplete cycle counter */
  --device->unready;
}

static eb_status_t eb_cycle_block(eb_device_t devicep, eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  eb_status_t status;
  eb_socket_t socketp;

  cycle = EB_CYCLE(cyclep);
  
  if (cycle->callback == &eb_block_f) {
    status = 1;
    cycle->user_data = &status;
    
    socketp = eb_device_socket(devicep);
    while (status > 0) eb_socket_run(socketp, -1);
    
    return status;
  } else {
    return EB_OK;
  }
}

eb_status_t eb_cycle_close_silently(eb_cycle_t cyclep) {
  eb_device_t devicep;
  
  devicep = eb_cycle_device(cyclep);
  eb_raw_cycle_close(cyclep);
  return eb_cycle_block(devicep, cyclep);
}

eb_status_t eb_cycle_close(eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  struct eb_operation* op;
  eb_operation_t opp;
  eb_device_t devicep;
  
  devicep = eb_cycle_device(cyclep);
  eb_raw_cycle_close(cyclep);
  
  cycle = EB_CYCLE(cyclep);
  opp = cycle->un_ops.first;
  
  if (opp != EB_NULL && cycle->un_ops.dead != cyclep) {
    op = EB_OPERATION(opp);
    op->flags |= EB_OP_CHECKED;
  }
  
  return eb_cycle_block(devicep, cyclep);
}

static struct eb_operation* eb_cycle_doop(eb_cycle_t cyclep) {
  eb_operation_t opp;
  struct eb_cycle* cycle;
  struct eb_operation* op;
  static struct eb_operation crap;
  
  opp = eb_new_operation();
  cycle = EB_CYCLE(cyclep);
  
  if (opp == EB_NULL) {
    /* Record out-of-memory with a self-pointer */
    eb_cycle_destroy(cyclep);
    cycle->un_ops.dead = cyclep;
    return &crap;
  }
  
  if (cycle->un_ops.dead == cyclep) {
    eb_free_operation(opp);
    /* Already ran OOM on this cycle */
    return &crap;
  }
  
  op = EB_OPERATION(opp);
  
  op->next = cycle->un_ops.first;
  cycle->un_ops.first = opp;
  return op;
}

void eb_cycle_read(eb_cycle_t cycle, eb_address_t address, eb_format_t format, eb_data_t* data) {
  struct eb_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->un_value.read_destination = data;
  op->format = format;
  
  if (data) op->flags = EB_OP_READ_PTR;
  else      op->flags = EB_OP_READ_VAL;
}

void eb_cycle_read_config(eb_cycle_t cycle, eb_address_t address, eb_format_t format, eb_data_t* data) {
  struct eb_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->un_value.read_destination = data;
  op->format = format;
  
  if (data) op->flags = EB_OP_READ_PTR | EB_OP_CFG_SPACE;
  else      op->flags = EB_OP_READ_VAL | EB_OP_CFG_SPACE;
}

void eb_cycle_write(eb_cycle_t cycle, eb_address_t address, eb_format_t format, eb_data_t data) {
  struct eb_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->un_value.write_value = data;
  op->format = format;
  op->flags = EB_OP_WRITE;
}

void eb_cycle_write_config(eb_cycle_t cycle, eb_address_t address, eb_format_t format, eb_data_t data) {
  struct eb_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->un_value.write_value = data;
  op->format = format;
  op->flags = EB_OP_WRITE | EB_OP_CFG_SPACE;
}
