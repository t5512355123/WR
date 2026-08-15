/** @file master.c
 *  @brief Format an Etherbone request.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Prepare a records in two phases:
 *   1. Determine how many operations we can pack.
 *   2. Format the actual payload.
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
#define EB_NEED_BIGENDIAN_64 1

#include <string.h>

#include "../glue/operation.h"
#include "../glue/cycle.h"
#include "../glue/device.h"
#include "../glue/socket.h"
#include "../glue/widths.h"
#include "../transport/transport.h"
#include "../memory/memory.h"
#include "format.h"
#include "bigendian.h"

static void EB_mWRITE(uint8_t* wptr, eb_data_t val, int alignment) {
  switch (alignment) {
  case 2: *(uint16_t*)wptr = htobe16(val); break;
  case 4: *(uint32_t*)wptr = htobe32(val); break;
  case 8: *(uint64_t*)wptr = htobe64(val); break;
  }
}

/* This method is tricky.
 * Whenever a callback or an allocation happens, dereferenced pointers become invalid.
 * Thus, the EB_<TYPE>(x) conversions appear late and near their use.
 */
eb_status_t eb_device_flush(eb_device_t devicep, int *completed) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  struct eb_device* device;
  struct eb_link* link;
  struct eb_transport* transport;
  struct eb_cycle* cycle;
  struct eb_response* response;
  struct eb_transport_ops* tops;
  eb_cycle_t cyclep, nextp, prevp;
  eb_response_t responsep;
  eb_width_t biggest, data, addr, width;
  eb_format_t format, size, endian;
  eb_address_t address_mask;
  uint8_t buffer[sizeof(eb_max_align_t)*(255+255+1+1)+8]; /* big enough for worst-case record */
  uint8_t * wptr, * cptr, * eob;
  int alignment, record_alignment, header_alignment, stride, mtu, readback, has_reads;
  
  device = EB_DEVICE(devicep);
  transport = EB_TRANSPORT(device->transport);
  width = device->widths;
  
  if (device->link == EB_NULL) return EB_FAIL;
  
  /*
  assert (device->un_link.passive != devicep);
  assert (eb_width_refined(width) != 0);
  */
  
  /* Calculate alignment values */
  data = width & EB_DATAX;
  addr = width >> 4;
  biggest = addr | data;
  alignment = 2;
  alignment += (biggest >= EB_DATA32)*2;
  alignment += (biggest >= EB_DATA64)*4;
  record_alignment = 4;
  record_alignment += (biggest >= EB_DATA64)*4;
  header_alignment = record_alignment;
  stride = data;
  
  /* Determine alignment and masking sets */
  address_mask = ~(eb_address_t)0;
  address_mask >>= (sizeof(eb_address_t) - addr) << 3;
  
  /* Begin buffering */
  tops = &eb_transports[transport->link_type];
  link = EB_LINK(device->link);
  tops->send_buffer(transport, link, 1);
  
  /* Non-streaming sockets need a header */
  mtu = tops->mtu;
  if (mtu != 0) {
    memset(&buffer[0], 0, header_alignment);
    buffer[0] = 0x4E;
    buffer[1] = 0x6F;
    buffer[2] = 0x10; /* V1. no probe. */
    buffer[3] = width;
    cptr = wptr = &buffer[header_alignment];
    eob = &buffer[mtu];
  } else {
    cptr = wptr = &buffer[0];
    eob = &buffer[sizeof(buffer)];
  }
  
  /* Invert the list of cycles */
  prevp = EB_NULL;
  for (cyclep = device->un_link.ready; cyclep != EB_NULL; cyclep = nextp) {
    cycle = EB_CYCLE(cyclep);
    nextp = cycle->un_link.next;
    cycle->un_link.next = prevp;
    prevp = cyclep;
  }
  
  has_reads = 0;
  for (cyclep = prevp; cyclep != EB_NULL; cyclep = nextp) {
    struct eb_operation* operation;
    struct eb_operation* scan;
    eb_operation_t operationp;
    eb_operation_t scanp;
    eb_data_t data_mask;
    int needs_check, cycle_end;
    unsigned int ops, maxops;
    eb_status_t reason;
    
    cycle = EB_CYCLE(cyclep);
    nextp = cycle->un_link.next;
    
    /* Record the device which answers */
    cycle->un_link.device = devicep;
    
    /* Deal with OOM cases */
    if (cycle->un_ops.dead == cyclep) {
      (*cycle->callback)(cycle->user_data, cycle->un_link.device, EB_NULL, EB_OOM);
      ++*completed;
      eb_free_cycle(cyclep);
      continue;
    }
    
    /* Was the cycle a no-op? */
    if (cycle->un_ops.first == EB_NULL) {
      (*cycle->callback)(cycle->user_data, cycle->un_link.device, EB_NULL, EB_OK);
      ++*completed;
      eb_free_cycle(cyclep);
      continue;
    }
    
    /* Are there out of range widths? */
    reason = EB_OK; /* silence warning */
    for (operationp = cycle->un_ops.first; operationp != EB_NULL; operationp = operation->next) {
      operation = EB_OPERATION(operationp);
      
      /* Determine operations size: max of possibilities <= data */
      format = operation->format;
      endian = format & EB_ENDIAN_MASK;
      size = eb_width_refine(format & (data-1+data));
      
      /* If the operation is endian agnostic, clear the endian bits */
      if (size == data) endian = 0;
      
      /* If the size cannot be executed on the device, complain */
      if (size == 0) {
        reason = EB_WIDTH;
        break;
      }
      
      /* Not both endians please. If it is a sub-word access, endian is required. */
      if (endian == (EB_BIG_ENDIAN|EB_LITTLE_ENDIAN) || (size != data && endian == 0)) {
        reason = EB_ENDIAN;
        break;
      }
      
      /* Report what the operation format ended up to be */
      operation->format = endian | size;
      
      /* Is the address too big for a bus op? */
      if ((operation->flags & EB_OP_CFG_SPACE) == 0 &&
          (operation->address & (address_mask - (size - 1))) != operation->address) {
        reason = EB_ADDRESS;
        break;
      }
      
      /* Is the address too big for a cfg op? */
      if ((operation->flags & EB_OP_CFG_SPACE) != 0 &&
          (operation->address & (0xFFFFU - (size - 1))) != operation->address) {
        reason = EB_ADDRESS;
        break;
      }
      
      /* Is the data too big for the port? */
      if ((operation->flags & EB_OP_MASK) == EB_OP_WRITE) {
        data_mask = ~(eb_data_t)0;
        data_mask >>= (sizeof(eb_data_t) - size) << 3;
        if ((operation->un_value.write_value & data_mask) != operation->un_value.write_value) {
          reason = EB_WIDTH;
          break;
        }
      }
    }
    
    if (operationp != EB_NULL) {
      /* Report the bad operation to the user */
      (*cycle->callback)(cycle->user_data, cycle->un_link.device, operationp, reason);
      ++*completed;
      eb_cycle_destroy(cyclep);
      eb_free_cycle(cyclep);
      continue;
    }
    
    /* Record to hook it into socket */
    responsep = eb_new_response(); /* invalidates: cycle device transport */
    if (responsep == EB_NULL) {
      cycle = EB_CYCLE(cyclep);
      (*cycle->callback)(cycle->user_data, cycle->un_link.device, EB_NULL, EB_OOM);
      ++*completed;
      eb_cycle_destroy(cyclep);
      eb_free_cycle(cyclep);
      continue;
    }

    /* Refresh pointers typically needed per cycle */
    device = EB_DEVICE(devicep);
    cycle = EB_CYCLE(cyclep);
    socket = EB_SOCKET(device->socket);
    response = EB_RESPONSE(responsep);
    aux = EB_SOCKET_AUX(socket->aux);
    
    operationp = cycle->un_ops.first;
    operation = EB_OPERATION(operationp);
    
    needs_check = (operation->flags & EB_OP_CHECKED) != 0;
    if (needs_check) {
      maxops = stride * 8;
    } else {
      maxops = -1; 
    }
    
    /* Begin formatting the packet into records */
    ops = 0;
    readback = 0;
    cycle_end = 0;
    while (!cycle_end) {
      int wcount, rcount, rxcount, total, length, fifo;
      eb_address_t bwa;
      eb_data_t wv;
      eb_operation_flags_t rcfg, wcfg;
      uint8_t op_shift, low_addr;
      
      scanp = operationp;
      
      /* First pack writes into a record, if any */
      if (ops >= maxops ||
          scanp == EB_NULL ||
          ((scan = EB_OPERATION(scanp))->flags & EB_OP_MASK) != EB_OP_WRITE) {
        /* No writes in this record */
        wcount = 0;
        fifo = 0;
        wcfg = 0;
        
        format = EB_DATAX;
        low_addr = 0;
      } else {
        wcfg = scan->flags & EB_OP_CFG_SPACE;
        bwa = scan->address;
        scanp = scan->next;
        
        format = scan->format;
        low_addr = bwa & (data-1);
        
        if (wcfg == 0) ++ops;
        
        /* How many writes can we chain? must be either FIFO or sequential in same address space */
        if (ops >= maxops ||
            scanp == EB_NULL ||
            ((scan = EB_OPERATION(scanp))->flags & EB_OP_MASK) != EB_OP_WRITE ||
            (scan->flags & EB_OP_CFG_SPACE) != wcfg ||
            scan->format != format) {
          /* Only a single write */
          fifo = 0;
          wcount = 1;
        } else {
          /* Consider if FIFO or sequential work */
          if (scan->address == bwa) {
            /* FIFO -- count how many ops we can chain */
            fifo = 1;
            wcount = 2;
            if (wcfg == 0) ++ops;
            
            for (scanp = scan->next; scanp != EB_NULL; scanp = scan->next) {
              scan = EB_OPERATION(scanp);
              if (scan->address != bwa) break;
              if ((scan->flags & EB_OP_MASK) != EB_OP_WRITE) break;
              if ((scan->flags & EB_OP_CFG_SPACE) != wcfg) break;
              if (scan->format != format) break;
              if (wcount >= 255) break;
              if (ops >= maxops) break;
              if (wcfg == 0) ++ops;
              ++wcount;
            }
          } else if (scan->address == (bwa += stride)) {
            /* Sequential */
            fifo = 0;
            wcount = 2;
            if (wcfg == 0) ++ops;
            
            for (scanp = scan->next; scanp != EB_NULL; scanp = scan->next) {
              scan = EB_OPERATION(scanp);
              if (scan->address != (bwa += stride)) break;
              if ((scan->flags & EB_OP_MASK) != EB_OP_WRITE) break;
              if ((scan->flags & EB_OP_CFG_SPACE) != wcfg) break;
              if (scan->format != format) break;
              if (wcount >= 255) break;
              if (ops >= maxops) break;
              if (wcfg == 0) ++ops;
              ++wcount;
            }
          } else {
            /* Cannot chain writes */
            fifo = 0;
            wcount = 1;
          }
        }
      }

      /* Next, how many reads follow? */
      /* First pack writes into a record, if any */
      if (ops >= maxops ||
          scanp == EB_NULL ||
          ((scan = EB_OPERATION(scanp))->flags & EB_OP_MASK) == EB_OP_WRITE ||
          (format != EB_DATAX && (scan->format != format || (scan->address & (data-1)) != low_addr))) {
        /* No reads in this record */
        rcount = 0;
        rcfg = 0;
      } else {
        rcfg = scan->flags & EB_OP_CFG_SPACE;
        format = scan->format;
        low_addr = scan->address & (data-1);
        if (rcfg == 0) ++ops;
        
        rcount = 1;
        for (scanp = scan->next; scanp != EB_NULL; scanp = scan->next) {
          scan = EB_OPERATION(scanp);
          if ((scan->flags & EB_OP_MASK) == EB_OP_WRITE) break;
          if ((scan->flags & EB_OP_CFG_SPACE) != rcfg) break;
          if (scan->format != format) break;
          if ((scan->address & (data-1)) != low_addr) break;
          if (rcount >= 255) break;
          if (ops >= maxops) break;
          if (rcfg == 0) ++ops;
          ++rcount;
        }
      }
      
      if (rcount == 0 && 
          (format == EB_DATAX || format == data) && 
          (ops >= maxops || (scanp == EB_NULL && needs_check && ops > 0))) {
        /* Insert error-flag read */
        format = data;
        rxcount = 1;
        rcfg = 1;
      } else {
        rxcount = rcount;
      }
      
      /* Compute total request length */
      total = (wcount  > 0) + wcount
            + (rxcount > 0) + rxcount;
      
      length = record_alignment + total*alignment;
      
      /* Ensure sufficient buffer space */
      if (length > eob - wptr) {
        /* Refresh pointers */
        transport = EB_TRANSPORT(device->transport);
        link = EB_LINK(device->link);
        
        if (mtu == 0) {
          /* Overflow in a streaming device => flush and continue */
          (*tops->send)(transport, link, &buffer[0], wptr - &buffer[0]);
          wptr = &buffer[0];
        } else {
          /* Overflow in a packet-based device, send any previous cycles and keep current */
          
          /* Already contains a prior cycle -- flush it */
          if (cptr != &buffer[header_alignment]) {
            int send, keep;
            
            /* If we've sent no reads, toggle the header */
            if (has_reads == 0) buffer[2] |= EB_HEADER_NR;
            has_reads = 0;
            
            send = cptr - &buffer[0];
            (*tops->send)(transport, link, &buffer[0], send);
            
            /* Shift any existing records over */
            keep = wptr - cptr;
            memmove(&buffer[header_alignment], cptr, keep);
            cptr = &buffer[header_alignment];
            wptr = cptr + keep;
          }
          
          /* Test for cycle overflow of MTU */
          if (length > eob - wptr) {
            /* Blow up in the face of the user */
            (*cycle->callback)(cycle->user_data, cycle->un_link.device, operationp, EB_OVERFLOW);
            ++*completed;
            eb_cycle_destroy(cyclep);
            eb_free_cycle(cyclep);
            eb_free_response(responsep);
            
            /* Start next cycle at the head of buffer */
            wptr = &buffer[header_alignment];
            break; /* Exits while(), continues for() due to conditional after while() */
          }
        }
      }
      
      /* If we have reads, we don't promise none! */
      has_reads |= rxcount > 0;
      
      /* The last record in a cycle if: */
      cycle_end = 
        scanp == EB_NULL &&
        (!needs_check || ops == 0 || rxcount != rcount);
        
      /* The low address bits determine how far to shift values */
      size = format & EB_DATAX;
      endian = format & EB_ENDIAN_MASK;
      if (endian == EB_BIG_ENDIAN)
        op_shift = data - (low_addr+size);
      else
        op_shift = low_addr;
      
      /* Start by preparting the header */
      memset(wptr, 0, record_alignment);
      wptr[0] = EB_RECORD_BCA | EB_RECORD_RFF | /* BCA+RFF always set */
                (rcfg ? EB_RECORD_RCA : 0) |
                (wcfg ? EB_RECORD_WCA : 0) | 
                (fifo ? EB_RECORD_WFF : 0) |
                (cycle_end ? EB_RECORD_CYC : 0);
      wptr[1] = (0xFF >> (8-size)) << op_shift;
      wptr[2] = wcount;
      wptr[3] = rxcount;
      wptr += record_alignment;
      
      /* Fill in the writes */
      if (wcount > 0) {
        operation = EB_OPERATION(operationp);
        
        EB_mWRITE(wptr, operation->address, alignment);
        wptr += alignment;
        
        for (; wcount--; operationp = operation->next) {
          operation = EB_OPERATION(operationp);
          
          wv = operation->un_value.write_value;
          wv <<= (op_shift<<3);
          
          EB_mWRITE(wptr, wv, alignment);
          wptr += alignment;
        }
      }
      
      /* Insert the read-back */
      if (rxcount != rcount) {
        readback = 1;
        
        EB_mWRITE(wptr, aux->rba|1, alignment);
        wptr += alignment;
        
        /* Status register is read at differing offset for differing port widths */
        EB_mWRITE(wptr, 8 - stride, alignment);
        wptr += alignment;
        
        ops = 0;
      }
      
      /* Fill in the reads */
      if (rcount > 0) {
        readback = 1;
        
        EB_mWRITE(wptr, aux->rba, alignment);
        wptr += alignment;
        
        for (; rcount--; operationp = operation->next) {
          operation = EB_OPERATION(operationp);
          
          EB_mWRITE(wptr, operation->address, alignment);
          wptr += alignment;
        }
      }
    }
    
    /* Did we finish the while loop? */
    if (cycle_end) {
      if (readback == 0) {
        /* No response will arrive, so call callback now */
        /* Invalidates pointers, but jumps to top of loop afterwards */
        (*cycle->callback)(cycle->user_data, cycle->un_link.device, cycle->un_ops.first, EB_OK); 
        ++*completed;
        eb_cycle_destroy(cyclep);
        eb_free_cycle(cyclep);
        eb_free_response(responsep);
      } else {
        /* Setup a response */
        response->deadline = aux->time_cache + 5;
        response->cycle = cyclep;
        response->write_cursor = eb_find_read(cycle->un_ops.first);
        response->status_cursor = needs_check ? eb_find_bus(cycle->un_ops.first) : EB_NULL;
        
        /* Claim response address */
        response->address = aux->rba;
        aux->rba = 0x8000 | (aux->rba + 2);
        
        /* Chain it for response processing in FIFO order */
        response->next = socket->last_response;
        socket->last_response = responsep;
      }
      
      /* Update end pointer */
      cptr = wptr;
    }
  }
  
  /* Refresh pointer derferences */
  device = EB_DEVICE(devicep);
  transport = EB_TRANSPORT(device->transport);
  link = EB_LINK(device->link);
  
  if (mtu == 0) {
    if (wptr != &buffer[0]) {
      (*tops->send)(transport, link, &buffer[0], wptr - &buffer[0]);
    }
  } else {
    if (wptr != &buffer[header_alignment]) {
      if (has_reads == 0) buffer[2] |= EB_HEADER_NR;
      (*tops->send)(transport, link, &buffer[0], wptr - &buffer[0]);
    }
  }
  
  /* Done sending */
  tops->send_buffer(transport, link, 0);
  
  /* Clear the queue */
  device->un_link.ready = EB_NULL;
  
  return EB_OK;
}
