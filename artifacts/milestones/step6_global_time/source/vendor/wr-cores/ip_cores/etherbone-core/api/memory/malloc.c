/** @file malloc.c
 *  @brief Dynamic memory allocation using traditional malloc/free.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Pointer types are simple C point types.
 *  Allocation uses non-deterministic malloc, typically using a free list.
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

#ifdef EB_USE_MALLOC

#include <stdlib.h>
#include "memory.h"

eb_operation_t        eb_new_operation       (void) { return (eb_operation_t)       malloc(sizeof(struct eb_operation));        }
eb_cycle_t            eb_new_cycle           (void) { return (eb_cycle_t)           malloc(sizeof(struct eb_cycle));            }
eb_device_t           eb_new_device          (void) { return (eb_device_t)          malloc(sizeof(struct eb_device));           }
eb_handler_callback_t eb_new_handler_callback(void) { return (eb_handler_callback_t)malloc(sizeof(struct eb_handler_callback)); }
eb_handler_address_t  eb_new_handler_address (void) { return (eb_handler_address_t) malloc(sizeof(struct eb_handler_address));  }
eb_response_t         eb_new_response        (void) { return (eb_response_t)        malloc(sizeof(struct eb_response));         }
eb_socket_t           eb_new_socket          (void) { return (eb_socket_t)          malloc(sizeof(struct eb_socket));           }
eb_socket_aux_t       eb_new_socket_aux      (void) { return (eb_socket_aux_t)      malloc(sizeof(struct eb_socket_aux));       }
eb_transport_t        eb_new_transport       (void) { return (eb_transport_t)       malloc(sizeof(struct eb_transport));        }
eb_link_t             eb_new_link            (void) { return (eb_link_t)            malloc(sizeof(struct eb_link));             }
eb_sdb_scan_t         eb_new_sdb_scan        (void) { return (eb_sdb_scan_t)        malloc(sizeof(struct eb_sdb_scan));         }
eb_sdb_record_t       eb_new_sdb_record      (void) { return (eb_sdb_record_t)      malloc(sizeof(struct eb_sdb_record));       }

void eb_free_operation       (eb_operation_t        x) { free(x); }
void eb_free_cycle           (eb_cycle_t            x) { free(x); }
void eb_free_device          (eb_device_t           x) { free(x); }
void eb_free_handler_callback(eb_handler_callback_t x) { free(x); }
void eb_free_handler_address (eb_handler_address_t  x) { free(x); }
void eb_free_response        (eb_response_t         x) { free(x); }
void eb_free_socket          (eb_socket_t           x) { free(x); }
void eb_free_socket_aux      (eb_socket_aux_t       x) { free(x); }
void eb_free_transport       (eb_transport_t        x) { free(x); }
void eb_free_link            (eb_link_t             x) { free(x); }
void eb_free_sdb_scan        (eb_sdb_scan_t         x) { free(x); }
void eb_free_sdb_record      (eb_sdb_record_t       x) { free(x); }

#endif
