/** @file array.c
 *  @brief Dynamic memory allocation using an array with fixed record type.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  To keep memory management simple, all dynamic objects occupy the same space.
 *  A free list is maintained of all unoccupied object slots.
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

#ifndef EB_USE_MALLOC

#include "memory.h"

EB_POINTER(eb_memory_item) eb_memory_free = EB_END_OF_FREE;
EB_PRIVATE EB_POINTER(eb_memory_item) eb_memory_used = 0;

static EB_POINTER(eb_new_memory_item) eb_new_memory_item(void) {
  EB_POINTER(eb_memory_item) alloc;
  
  if (eb_memory_free == EB_END_OF_FREE) {
    if (eb_expand_array() < 0)
      return EB_NULL;
  }
  
  alloc = eb_memory_free;
  eb_memory_free = EB_FREE_ITEM(alloc)->next;
  
  ++eb_memory_used;
  return alloc;
}

static void eb_free_memory_item(EB_POINTER(eb_memory_item) item) {
  EB_FREE_ITEM(item)->next = eb_memory_free;
  eb_memory_free = item;
  --eb_memory_used;
}

eb_operation_t        eb_new_operation       (void) { return (eb_operation_t)       eb_new_memory_item(); }
eb_cycle_t            eb_new_cycle           (void) { return (eb_cycle_t)           eb_new_memory_item(); }
eb_device_t           eb_new_device          (void) { return (eb_device_t)          eb_new_memory_item(); }
eb_handler_callback_t eb_new_handler_callback(void) { return (eb_handler_callback_t)eb_new_memory_item(); }
eb_handler_address_t  eb_new_handler_address (void) { return (eb_handler_address_t) eb_new_memory_item(); }
eb_response_t         eb_new_response        (void) { return (eb_response_t)        eb_new_memory_item(); }
eb_socket_t           eb_new_socket          (void) { return (eb_socket_t)          eb_new_memory_item(); }
eb_socket_aux_t       eb_new_socket_aux      (void) { return (eb_socket_aux_t)      eb_new_memory_item(); }
eb_transport_t        eb_new_transport       (void) { return (eb_transport_t)       eb_new_memory_item(); }
eb_link_t             eb_new_link            (void) { return (eb_link_t)            eb_new_memory_item(); }
eb_sdb_scan_t         eb_new_sdb_scan        (void) { return (eb_sdb_scan_t)        eb_new_memory_item(); }
eb_sdb_record_t       eb_new_sdb_record      (void) { return (eb_sdb_record_t)      eb_new_memory_item(); }

void eb_free_operation       (eb_operation_t        x) { eb_free_memory_item(x); }
void eb_free_cycle           (eb_cycle_t            x) { eb_free_memory_item(x); }
void eb_free_device          (eb_device_t           x) { eb_free_memory_item(x); }
void eb_free_handler_callback(eb_handler_callback_t x) { eb_free_memory_item(x); }
void eb_free_handler_address (eb_handler_address_t  x) { eb_free_memory_item(x); }
void eb_free_response        (eb_response_t         x) { eb_free_memory_item(x); }
void eb_free_socket          (eb_socket_t           x) { eb_free_memory_item(x); }
void eb_free_socket_aux      (eb_socket_aux_t       x) { eb_free_memory_item(x); }
void eb_free_transport       (eb_transport_t        x) { eb_free_memory_item(x); }
void eb_free_link            (eb_link_t             x) { eb_free_memory_item(x); }
void eb_free_sdb_scan        (eb_sdb_scan_t         x) { eb_free_memory_item(x); }
void eb_free_sdb_record      (eb_sdb_record_t       x) { eb_free_memory_item(x); }

#endif
