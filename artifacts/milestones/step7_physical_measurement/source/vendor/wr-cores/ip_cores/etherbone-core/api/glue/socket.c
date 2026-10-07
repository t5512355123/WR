/** @file socket.c
 *  @brief Implement the Etherbone socket data structure.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  This data structure does not deal directly with IO.
 *  For actual transport-layer sockets, see transport/.
 *  For reading/writing of payload, see format/.
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

#include "socket.h"
#include "device.h"
#include "cycle.h"
#include "widths.h"
#include "../transport/transport.h"
#include "../memory/memory.h"
#include "../format/format.h"

#ifdef __WIN32
#include <winsock2.h>
#endif

eb_status_t eb_socket_open(uint16_t abi_code, const char* port, eb_width_t supported_widths, eb_socket_t* result) {
  eb_socket_t socketp;
  eb_socket_aux_t auxp;
  eb_transport_t transportp, first_transport;
  struct eb_transport* transport;
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  eb_status_t status;
  uint8_t link_type;
#ifdef  __WIN32
  WORD wVersionRequested;
  WSADATA wsaData;
#endif
  
  /* Does the library support the application? */
  if (abi_code != EB_ABI_CODE)
    return EB_ABI;
  
  /* Constrain widths to those supported by compilation */
  if (sizeof(eb_data_t) < 8) supported_widths &= ~EB_DATA64;
  if (sizeof(eb_data_t) < 4) supported_widths &= ~EB_DATA32;
  if (sizeof(eb_data_t) < 2) supported_widths &= ~EB_DATA16;
  if (sizeof(eb_address_t) < 8) supported_widths &= ~EB_ADDR64;
  if (sizeof(eb_address_t) < 4) supported_widths &= ~EB_ADDR32;
  if (sizeof(eb_address_t) < 2) supported_widths &= ~EB_ADDR16;
  
  /* Is the width choice valid? */
  if (eb_width_possible(supported_widths) == 0) {
    *result = EB_NULL;
    return EB_WIDTH;
  }
  
  /* Allocate the soocket */
  socketp = eb_new_socket();
  if (socketp == EB_NULL) {
    *result = EB_NULL;
    return EB_OOM;
  }
  auxp = eb_new_socket_aux();
  if (auxp == EB_NULL) {
    *result = EB_NULL;
    eb_free_socket(socketp);
    return EB_OOM;
  }
  
#ifdef __WIN32
  wVersionRequested = MAKEWORD(2, 2);
  if (WSAStartup(wVersionRequested, &wsaData) != 0) {
    eb_free_socket(socketp);
    eb_free_socket_aux(auxp);
    return EB_FAIL;
  }
#endif
  
  /* Allocate the transports */
  status = EB_OK;
  first_transport = EB_NULL;
  for (link_type = 0; link_type != eb_transport_size; ++link_type) {
    transportp = eb_new_transport();
    
    /* Stop with OOM error */
    if (transportp == EB_NULL) {
      status = EB_OOM;
      break;
    }
    
    transport = EB_TRANSPORT(transportp);
    status = eb_transports[link_type].open(transport, port);
    
    /* Skip this transport */
    if (status == EB_ADDRESS) {
      eb_free_transport(transportp);
      continue;
    }
    
    /* Stop if some other problem */
    if (status != EB_OK) {
      eb_free_transport(transportp);
      break;
    }
    
    transport->next = first_transport;
    transport->link_type = link_type;
    first_transport = transportp;
  }
  
  /* Allocation is finished, dereference the pointers */
  
  socket = EB_SOCKET(socketp);
  socket->first_device = EB_NULL;
  socket->first_handler = EB_NULL;
  socket->first_response = EB_NULL;
  socket->last_response = EB_NULL;
  socket->widths = supported_widths;
  socket->aux = auxp;
  
  aux = EB_SOCKET_AUX(auxp);
  aux->time_cache = 0;
  aux->rba = 0x8000;
  aux->first_transport = first_transport;
  aux->sdb_offset = 0;
  
  if (link_type != eb_transport_size) {
    eb_socket_close(socketp);
    return status;
  }
  
  /* Update time_cache */
  eb_socket_run(socketp, 0);
  
  *result = socketp;
  return status;
}

eb_response_t eb_response_flip(eb_response_t firstp) {
  struct eb_response* response;
  eb_response_t responsep, prev_responsep, next_responsep;
  
  prev_responsep = EB_NULL;
  for (responsep = firstp; responsep != EB_NULL; responsep = next_responsep) {
    response = EB_RESPONSE(responsep);
    next_responsep = response->next;
    response->next = prev_responsep;
    prev_responsep = responsep;
  }
  
  return prev_responsep;
}

eb_status_t eb_socket_close(eb_socket_t socketp) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  struct eb_handler_address* handler;
  struct eb_transport* transport;
  struct eb_device* device;
  eb_transport_t transportp, next_transportp;
  eb_socket_aux_t auxp;
  eb_handler_address_t i, next;
  eb_status_t status;
  
  socket = EB_SOCKET(socketp);
  
  /* If there are open devices, we can't close */
  while (socket->first_device != EB_NULL) {
    device = EB_DEVICE(socket->first_device);
    /* Only passive devices allowed at this point */
    if (device->un_link.passive != socket->first_device)
      return EB_BUSY;
    /* Release the passive device */
    status = eb_device_close(socket->first_device);
    if (status != EB_OK) return status;
  }
  
  /* All responses must be closed if devices are closed */
  /* assert (socket->first_response == EB_NULL); */
  
  /* Flush handlers */
  for (i = socket->first_handler; i != EB_NULL; i = next) {
    handler = EB_HANDLER_ADDRESS(i);
    next = handler->next;
    
    eb_free_handler_callback(handler->callback);
    eb_free_handler_address(i);
  }
  
  auxp = socket->aux;
  aux = EB_SOCKET_AUX(auxp);
  
  for (transportp = aux->first_transport; transportp != EB_NULL; transportp = next_transportp) {
    transport = EB_TRANSPORT(transportp);
    next_transportp = transport->next;
    eb_transports[transport->link_type].close(transport);
    eb_free_transport(transportp);
  }
  
#ifdef __WIN32
  WSACleanup();
#endif

  eb_free_socket(socketp);
  eb_free_socket_aux(auxp);
  return EB_OK;
}

static void eb_socket_filter_inflight(eb_response_t* goodp, eb_response_t* badp, eb_device_t devicep, eb_response_t firstp) {
  struct eb_response* response;
  struct eb_cycle* cycle;
  eb_response_t good, bad;
  eb_response_t responsep, next_responsep;
  eb_cycle_t cyclep;
  
  good = *goodp;
  bad = *badp;
  
  /* Partiton the list */
  for (responsep = firstp; responsep != EB_NULL; responsep = next_responsep) {
    response = EB_RESPONSE(responsep);
    next_responsep = response->next;
    
    cyclep = response->cycle;
    cycle = EB_CYCLE(cyclep);
   
    if (cycle->un_link.device == devicep) {
      response->next = bad;
      bad = responsep;
    } else {
      response->next = good;
      good = responsep;
    }
  }
  
  *goodp = good;
  *badp = bad;
}

void eb_socket_kill_inflight(eb_socket_t socketp, eb_device_t devicep) {
  struct eb_socket* socket;
  struct eb_response* response;
  struct eb_cycle* cycle;
  eb_response_t responsep, next_responsep;
  eb_response_t good, bad;
  eb_cycle_t cyclep;
  
  /* Split the list into good responses we keep, and bad responses we kill */
  good = EB_NULL;
  bad = EB_NULL;
  socket = EB_SOCKET(socketp);
  eb_socket_filter_inflight(&good, &bad, devicep, socket->last_response);
  eb_socket_filter_inflight(&good, &bad, devicep, eb_response_flip(socket->first_response));
  socket->first_response = good;
  socket->last_response = EB_NULL;
  
  /* Now kill all the bad responses */
  for (responsep = bad; responsep != EB_NULL; responsep = next_responsep) {
    response = EB_RESPONSE(responsep);
    next_responsep = response->next;
    
    cyclep = response->cycle;
    cycle = EB_CYCLE(response->cycle);
    
    /* Mark the response for clean-up */
    response->cycle = EB_NULL;
    
    /* Run the callback */
    (*cycle->callback)(cycle->user_data, cycle->un_link.device, cycle->un_ops.first, EB_TIMEOUT);
      
    /* Free it all */
    eb_cycle_destroy(cyclep);
    eb_free_cycle(cyclep);
    eb_free_response(responsep);
  }
}

void eb_socket_descriptors(eb_socket_t socketp, eb_user_data_t user, eb_descriptor_callback_t cb) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  struct eb_device* device;
  struct eb_transport* transport;
  struct eb_link* link;
  eb_device_t devicep, next_devicep, first_devicep;
  eb_transport_t transportp, next_transportp, first_transportp;
  eb_link_t linkp;
  
  socket = EB_SOCKET(socketp);
  aux = EB_SOCKET_AUX(socket->aux);
  
  first_devicep = socket->first_device;
  first_transportp = aux->first_transport;
  
  /* Add all the transports */
  for (transportp = first_transportp; transportp != EB_NULL; transportp = next_transportp) {
    transport = EB_TRANSPORT(transportp);
    next_transportp = transport->next;
    
    /* Invalidates pointers: user code called */
    eb_transports[transport->link_type].fdes(transport, 0, user, cb);
  }
  
  /* Add all the sockets to the listen set */
  for (devicep = first_devicep; devicep != EB_NULL; devicep = next_devicep) {
    device = EB_DEVICE(devicep);
    next_devicep = device->next;
    
    linkp = device->link;
    if (linkp != EB_NULL) {
      link = EB_LINK(linkp);
      transportp = device->transport;
      transport = EB_TRANSPORT(transportp);
      
      /* Invalidates pointers: user code called */
      eb_transports[transport->link_type].fdes(transport, link, user, cb);
    }
  }
}

uint32_t eb_socket_timeout(eb_socket_t socketp) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  struct eb_response* response;
  uint16_t udelta;
  int16_t sdelta;
  
  socket = EB_SOCKET(socketp);
  aux = EB_SOCKET_AUX(socket->aux);
  
  /* Find the first timeout */
  if (socket->first_response == EB_NULL) {
    socket->first_response = eb_response_flip(socket->last_response);
    socket->last_response = EB_NULL;
  }
  
  /* Determine how long until deadline expires */ 
  if (socket->first_response != EB_NULL) {
    response = EB_RESPONSE(socket->first_response);
    
    udelta = response->deadline - ((uint16_t)aux->time_cache);
    sdelta = udelta; /* Sign conversion */
    return aux->time_cache + sdelta;
  } else {
    return 0;
  }
}

int eb_socket_check(eb_socket_t socketp, uint32_t now, eb_user_data_t user, eb_descriptor_callback_t ready) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  struct eb_device* device;
  struct eb_transport* transport;
  struct eb_response* response;
  struct eb_cycle* cycle;
  eb_device_t devicep, next_devicep;
  eb_transport_t transportp, next_transportp;
  eb_link_t new_linkp;
  eb_response_t responsep;
  eb_cycle_t cyclep;
  eb_socket_aux_t auxp;
  int completed;
  
  socket = EB_SOCKET(socketp);
  auxp = socket->aux;
  completed = 0;
  
  /* Step 1. Kill any expired timeouts */
  while (socket->first_response != EB_NULL &&
         eb_socket_timeout(socketp) <= now) {
    /* Kill first */
    responsep = socket->first_response;
    response = EB_RESPONSE(responsep);
    
    cyclep = response->cycle;
    cycle = EB_CYCLE(cyclep);
    
    socket->first_response = response->next;
    
    (*cycle->callback)(cycle->user_data, cycle->un_link.device, cycle->un_ops.first, EB_TIMEOUT);
    socket = EB_SOCKET(socketp); /* Restore pointer */
    
    ++completed;
    eb_cycle_destroy(cyclep);
    eb_free_cycle(cyclep);
    eb_free_response(responsep);
  }
  
  /* Get some memory for accepting connections */
  new_linkp = eb_new_link();
  
  /* Update time */
  aux = EB_SOCKET_AUX(auxp);
  aux->time_cache = now;
  
  /* Step 2. Check all devices */
  
  /* Poll all the transports, potentially discovering new devices */
  for (transportp = aux->first_transport; transportp != EB_NULL; transportp = next_transportp) {
    transport = EB_TRANSPORT(transportp);
    next_transportp = transport->next;
    
    /* Try to accept inbound connections */
    while (new_linkp != EB_NULL &&
           (*eb_transports[transport->link_type].accept)(transport, EB_LINK(new_linkp), user, ready) > 0) {
      new_linkp = eb_device_new_slave(socketp, transportp, new_linkp);
      transport = EB_TRANSPORT(transportp);
    }
    
    /* Grab top-level messages */
    while (eb_device_slave(socketp, transportp, EB_NULL, user, ready, &completed) > 0) {
      /* noop */
    }
  }
  
  /* Poll all the connections */
  socket = EB_SOCKET(socketp);
  for (devicep = socket->first_device; devicep != EB_NULL; devicep = next_devicep) {
    device = EB_DEVICE(devicep);
    next_devicep = device->next;
    
    while (device->link != EB_NULL && 
           eb_device_slave(socketp, device->transport, devicep, user, ready, &completed) > 0) {
      device = EB_DEVICE(devicep);
    }
    
    if (device->un_link.passive != devicep)
      eb_device_flush(devicep, &completed);
  }
  
  /* Free the temporary address */
  if (new_linkp != EB_NULL)
    eb_free_link(new_linkp);
  
  return completed;
}
