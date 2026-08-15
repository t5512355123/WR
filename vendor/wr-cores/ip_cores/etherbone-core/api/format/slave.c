/** @file slave.c
 *  @brief Process (and reply to) an Etherbone request.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Processing of read/write operations is deffered to glue/readwrite.c.
 *  Unlink a hardware implementation, responses to writes are not padded.
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

#include "../transport/transport.h"
#include "../glue/readwrite.h"
#include "../glue/socket.h"
#include "../glue/device.h"
#include "../glue/widths.h"
#include "../memory/memory.h"
#include "bigendian.h"
#include "format.h"

static eb_data_t EB_LOAD(uint8_t* rptr, int alignment) {
  switch (alignment) {
  case 2: return be16toh(*(uint16_t*)rptr);
  case 4: return be32toh(*(uint32_t*)rptr);
  case 8: return be64toh(*(uint64_t*)rptr);
  }
  return 0; /* unreachable */
}

static void EB_sWRITE(uint8_t* wptr, eb_data_t val, int alignment) {
  switch (alignment) {
  case 2: *(uint16_t*)wptr = htobe16(val); break;
  case 4: *(uint32_t*)wptr = htobe32(val); break;
  case 8: *(uint64_t*)wptr = htobe64(val); break;
  }
}

/* Find the offset */
static uint8_t eb_log2_table[8] = { 0, 1, 2, 4, 7, 3, 6, 5 };
static uint8_t eb_log2(uint8_t x) { return eb_log2_table[(uint8_t)(x * 0x17) >> 5]; }

int eb_device_slave(eb_socket_t socketp, eb_transport_t transportp, eb_device_t devicep, eb_user_data_t user_data, eb_descriptor_callback_t ready, int* completed) {
  struct eb_socket* socket;
  struct eb_transport* transport;
  struct eb_device* device;
  struct eb_link* link;
  eb_link_t linkp;
  int len, keep;
  uint8_t buffer[sizeof(eb_max_align_t)*(255+255+1+1)+8]; /* big enough for worst-case record */
  uint8_t* wptr, * rptr, * eos;
  uint64_t error;
  eb_width_t widths, biggest, data, addr;
  eb_address_t address_filter_bits;
  int alignment, record_alignment, header_alignment, stride, cycle_end, cycle_open;
  int reply, header, passive, active;
  
  transport = EB_TRANSPORT(transportp);
  socket = EB_SOCKET(socketp);
  
  if (devicep != EB_NULL) {
    device = EB_DEVICE(devicep);
    
    linkp = device->link;
    /* assert (linkp != EB_NULL); */ /* guard in eb_socket_check */
    link = EB_LINK(linkp);
    
    if (eb_transports[transport->link_type].mtu == 0) {
      widths = device->widths;
      header = widths == 0;
    } else {
      widths = 0;
      header = 1;
    }
    
    passive = device->un_link.passive == devicep;
    active = !passive;
  } else {
    device = 0; /* silence warning */
    
    linkp = EB_NULL;
    link = 0;
    
    widths = 0;
    header = 1;
    
    active = 0;
    passive = 0;
  }
  
  /* Cases:
   *   passive device
   *     needing probe request
   *   active device
   *     needing probe response
   *   transport
   *     always needs EB header
   */

  reply = 0;
  len = eb_transports[transport->link_type].poll(transport, link, user_data, ready, buffer, sizeof(buffer));
  if (len == 0) return 0; /* no data ready */
  if (len < 2) goto kill; /* EB is always 2 byte aligned */
  
  /* Expect and require an EB header */
  if (header) {
    /* On a stream, EB header may not be fragmented */
    if (buffer[0] != 0x4E || buffer[1] != 0x6F || len < 4) goto kill;
    
    /* Is this a probe? */
    if ((buffer[2] & EB_HEADER_PF) != 0) { /* probe flag */
      if (len != 8) goto kill; /* > 8: requestor couldn't send data before we respond! */
                               /* < 8: protocol violation! */
      if (active) goto kill; /* active link not probed! */
      
      widths = buffer[3];
      widths = eb_width_refine(widths & socket->widths);
      
      buffer[2] = 0x10 | EB_HEADER_PR | EB_HEADER_NR; /* V1 probe response */
      buffer[3] = socket->widths; /* passive and transport both use socket widths */
      
      if (passive) device->widths = widths; /* This will be the negotiated width */
      
      /* Bytes 4-7 are echoed back */
      eb_transports[transport->link_type].send(transport, link, buffer, 8);
      
      /* Kill the link if negotiation is impossible */
      if (!eb_width_possible(widths)) goto kill;
      
      return 1;
    }
    
    /* Is this a probe response? */
    if ((buffer[2] & EB_HEADER_PR) != 0) { /* probe response */
      eb_device_t devp;
      struct eb_device* dev;
      
      if (len != 8) goto kill; /* > 8: haven't sent requests, passive should not send data */
                               /* < 8: protocol violation! */
      if (passive) goto kill; /* passive link not responded! */
      
      /* Find device by probe id */
      eb_address_t tag;
      tag = be32toh(*(uint32_t*)&buffer[4]);
      
      for (devp = socket->first_device; devp != EB_NULL; devp = dev->next) {
        dev = EB_DEVICE(devp);
        if (((uint32_t)(uintptr_t)devp) == tag) break;
      }
      if (devp == EB_NULL) goto kill;
      
      dev->widths = buffer[3];
      
      return 0; /* don't poll again */
    } 
    
    /* Not V1 ? */
    if ((buffer[2] & 0xf0) != 0x10) goto kill;
    
    /* Unsupported widths? fail */
    widths = eb_width_refine(buffer[3] & socket->widths);
    if (!eb_width_possible(widths)) goto kill;
    
    /* As a reply, this will contain no reads */
    buffer[2] |= EB_HEADER_NR;
  }
  
  /* Alignment is either 2, 4, or 8. */
  data = widths & EB_DATAX;
  addr = widths >> 4;
  biggest = addr | data;
  alignment = 2;
  alignment += (biggest >= EB_DATA32)*2;
  alignment += (biggest >= EB_DATA64)*4;
  record_alignment = 4;
  record_alignment += (biggest >= EB_DATA64)*4;
  header_alignment = record_alignment;
  /* FIFO stride size */
  stride = data;
  
  /* Only these bits of incoming addresses are processed */
  address_filter_bits = ~(eb_address_t)0;
  address_filter_bits >>= (sizeof(eb_address_t) - addr) << 3;
  address_filter_bits -= (data-1);
  
  /* Setup the initial pointers */
  wptr = &buffer[0];
  if (header) wptr += header_alignment;
  rptr = wptr;
  eos = &buffer[len];
  
  /* Session-limited error shift */
  error = 0;
  cycle_end = 1;
  cycle_open = 0;

resume_cycle:
  /* Below this point, assume no dereferenced pointer is valid */

  /* Start processing the payload */
  while (rptr <= eos - record_alignment) {
    int total, wconfig, wfifo, rconfig, rfifo, bconfig, sel_ok;
    eb_address_t bwa, bwa_b, bwa_l;
    eb_address_t ra, ra_b, ra_l;
    eb_address_t bra;
    eb_data_t wv, data_mask;
    eb_width_t op_width, op_widths;
    uint8_t op_shift, bits, bits1;
    uint8_t addr_low_big_endian, addr_low_little_endian;
    uint8_t flags  = rptr[0];
    uint8_t select = rptr[1];
    uint8_t wcount = rptr[2];
    uint8_t rcount = rptr[3];
    
    rptr += record_alignment;
    
    /* Decode the intended width from the select lines */
    
    /* Step 1. How many bytes shifted are the operations? 
     * op_shift = position of first set bit
     */
    op_shift = eb_log2(select & -select);

    /* Step 2. How many ones are there in a row? */
    bits = select >> op_shift;
    bits1 = (bits>>1)+1;
    op_widths = eb_log2(bits1);
    op_width = op_widths+1;
    
    /* Step 3. Check that the bitmask is valid */
    sel_ok = select != 0                 /* select is not 0 */
          && (bits & (bits+1)) == 0      /* One bit set => was an unbroken sequence of bits */
          && (op_width & op_widths) == 0 /* One bit set => operation length was a power of two */
          && (op_shift & op_widths) == 0 /* The operation is aligned to the width */
          && op_width <= data            /* The width must be supported by the port */
          && op_shift < data;            /* The shift must be supported by the port */
    
    /* Determine the low address bits of the operation */
    addr_low_big_endian = data - (op_shift+op_width);
    addr_low_little_endian = op_shift;
    
    /* Create a mask for filtering out the important write data */
    data_mask = ~(eb_data_t)0;
    data_mask >>= (sizeof(eb_data_t) - op_width) << 3;
    
    /* Put the address width back into the result */
    op_width |= (addr << 4);

    /* Is the cycle flag high? */
    cycle_end = flags & EB_RECORD_CYC;
    
    total = wcount;
    total += rcount;
    total += (wcount>0);
    total += (rcount>0);
    
    /* Test if record overflows packet */
    while (total*alignment > eos-rptr) {
      transport = EB_TRANSPORT(transportp);
      if (linkp != EB_NULL) link = EB_LINK(linkp);
      
      /* If not a streaming socket, this is a critical error */
      if (eb_transports[transport->link_type].mtu != 0) goto kill;
      
      /* Streaming beyond this point */
      
      /* Rewind to the record header, so we keep this intact.
       * Even though we've read it, we need its space for writing a reply.
       */
      rptr -= record_alignment;
      
      if (reply) {
        eb_transports[transport->link_type].send(transport, link, buffer, wptr - &buffer[0]);
      }
      
      keep = eos-rptr;
      if (rptr != &buffer[0]) memmove(&buffer[0], rptr, keep);
      
      len = eb_transports[transport->link_type].recv(transport, link, buffer+keep, sizeof(buffer)-keep);
      if (len <= 0) goto kill;
      len += keep;
      
      wptr = &buffer[0];
      rptr = &buffer[record_alignment]; /* Skip past the record header again */
      eos = &buffer[len];
    }
    
    if (wcount > 0) {
      wfifo = flags & EB_RECORD_WFF;
      wconfig = flags & EB_RECORD_WCA;
      
      bwa = EB_LOAD(rptr, alignment);
      rptr += alignment;
      
      if (wconfig) {
        /* Our config space uses all bits of the address for WBA */
        /* If it ever supports register write access, this would need to change */
        bwa_b = bwa_l = 0; /* appease warning */
      } else {
        /* Wishbone devices ignore the low address bits and use the select lines */
        bwa &= address_filter_bits;
        bwa_b = bwa | addr_low_big_endian;
        bwa_l = bwa | addr_low_little_endian;
      }
        
      while (wcount--) {
        wv = EB_LOAD(rptr, alignment);
        rptr += alignment;
        
        wv >>= (op_shift<<3);
        wv &= data_mask;
        
        if (wconfig) {
          if (sel_ok)
            *completed += eb_socket_write_config(socketp, op_width, bwa, wv);
        } else {
          if (sel_ok)
            eb_socket_write(socketp, op_width, bwa_b, bwa_l, wv, &error);
          else
            error = (error<<1) | 1;
        }
        
        if (wfifo == 0) {
          bwa += stride;
          bwa_l += stride;
          bwa_b += stride;
        }
      }
    }
    
    if (rcount > 0) {
      reply = 1;
      rfifo = flags & EB_RECORD_RFF;
      bconfig = flags & EB_RECORD_BCA;
      rconfig = flags & EB_RECORD_RCA;
      
      /* Impossible to run out of space; sizeof(request) >= sizeof(reply) */
      
      /* Prepare new header */
      memset(wptr, 0, record_alignment);
      wptr[0] = cycle_end | 
                (bconfig ? EB_RECORD_WCA : 0) | 
                (rfifo   ? EB_RECORD_WFF : 0);
      wptr[1] = select;
      wptr[2] = rcount;
      wptr[3] = 0;
      
      wptr += record_alignment;
      
      /* Do we have an open cycle written to the line? */
      cycle_open = cycle_end == 0;
      
      bra = EB_LOAD(rptr, alignment);
      rptr += alignment;
    
      /* Echo back the base return address */
      EB_sWRITE(wptr, bra, alignment);
      wptr += alignment;
      
      while (rcount--) {
        ra = EB_LOAD(rptr, alignment);
        rptr += alignment;
        
        /* Wishbone devices ignore the low address bits and use the select lines */
        ra &= address_filter_bits;
        ra_b = ra | addr_low_big_endian;
        ra_l = ra | addr_low_little_endian;
        
        if (rconfig) {
          if (sel_ok) {
            wv = eb_socket_read_config(socketp, op_width, ra_b, error);
          } else {
            wv = 0;
          }
        } else {
          if (sel_ok) {
            wv = eb_socket_read(socketp, op_width, ra_b, ra_l, &error);
          } else {
            wv = 0;
            error = (error<<1) | 1;
          }
        }
        
        wv &= data_mask;
        wv <<= (op_shift<<3);
        
        EB_sWRITE(wptr, wv, alignment);
        wptr += alignment;
      }
    }
    
    /* We need to terminate the cycle */
    if (cycle_open && cycle_end) {
      memset(wptr, 0, record_alignment);
      wptr[0] = cycle_end;
      wptr += record_alignment;
    }
  }
  
  /* Reply if needed */
  if (reply) {
    eb_transports[transport->link_type].send(transport, link, buffer, wptr - &buffer[0]);
  }
  
  /* Is the cycle line still high? */
  if (cycle_end == 0) {
    /* Only streaming sockets may keep cycle line high */
    if (eb_transports[transport->link_type].mtu != 0) goto kill;
    
    keep = eos-rptr;
    if (rptr != &buffer[0]) memmove(&buffer[0], rptr, keep);
    
    len = eb_transports[transport->link_type].recv(transport, link, buffer+keep, sizeof(buffer)-keep);
    if (len <= 0) goto kill;
    len += keep;
    
    wptr = rptr = &buffer[0];
    eos = rptr + len;
    goto resume_cycle;
  }
  
  /* Improperly terminated message? */
  if (rptr != eos) goto kill;
  
  return 1;
  
kill:
  /* Destroy the connection */
  if (devicep == EB_NULL) return 0;
  
  if (passive) {
    eb_device_close(devicep);
  } else {
    device = EB_DEVICE(devicep);
    transport = EB_TRANSPORT(transportp);
    link = EB_LINK(linkp);
    
    eb_transports[transport->link_type].disconnect(transport, link);
    eb_free_link(device->link);
    device->link = EB_NULL;
  }
  
  return 0;
}
