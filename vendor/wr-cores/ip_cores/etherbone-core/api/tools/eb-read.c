/** @file eb-read.c
 *  @brief A tool for executing Etherbone reads.
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

#define _POSIX_C_SOURCE 200112L /* strtoull + getopt */
#define _ISOC99_SOURCE /* strtoull on old systems */

#include <unistd.h> /* getopt */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../etherbone.h"
#include "../glue/version.h"

static const char* program;
static eb_width_t address_width, data_width;
static eb_address_t address;
static eb_format_t endian;
static int verbose, quiet;

static void help(void) {
  fprintf(stderr, "Usage: %s [OPTION] <proto/host/port> <address/size>\n", program);
  fprintf(stderr, "\n");
  fprintf(stderr, "  -a <width>     acceptable address bus widths     (8/16/32/64)\n");
  fprintf(stderr, "  -d <width>     acceptable data bus widths        (8/16/32/64)\n");
  fprintf(stderr, "  -b             big-endian operation                    (auto)\n");
  fprintf(stderr, "  -l             little-endian operation                 (auto)\n");
  fprintf(stderr, "  -r <retries>   number of times to attempt autonegotiation (3)\n");
  fprintf(stderr, "  -s             don't read error status from device\n");
  fprintf(stderr, "  -c             read the config space instead of the bus\n");
  fprintf(stderr, "  -f             fidelity: do not fragment or widen read\n");
  fprintf(stderr, "  -p             disable self-describing wishbone device probe\n");
  fprintf(stderr, "  -v             verbose operation\n");
  fprintf(stderr, "  -q             quiet: do not display warnings\n");
  fprintf(stderr, "  -h             display this help and exit\n");
  fprintf(stderr, "\n");
  fprintf(stderr, "Report Etherbone bugs to <etherbone-core@ohwr.org>\n");
  fprintf(stderr, "Version %"PRIx32" (%s). Licensed under the LGPL v3.\n", EB_VERSION_SHORT, EB_DATE_FULL);
}

static eb_data_t data;
static void set_stop(eb_user_data_t user, eb_device_t dev, eb_operation_t op, eb_status_t status) {
  int* stop = (int*)user;
  *stop = 1;
  
  if (status != EB_OK) {
    fprintf(stderr, "%s: etherbone cycle error: %s\n", 
                    program, eb_status(status));
    exit(1);
  } else {
    data = 0;
    for (; op != EB_NULL; op = eb_operation_next(op)) {
      /* We read low bits first */
      data <<= (eb_operation_format(op) & EB_DATAX) * 8;
      data |= eb_operation_data(op);
      
      if (eb_operation_had_error(op))
        fprintf(stderr, "%s: wishbone segfault reading %s %s bits from address 0x%"EB_ADDR_FMT"\n",
                        program, eb_width_data(eb_operation_format(op)), 
                        eb_format_endian(eb_operation_format(op)), eb_operation_address(op));
    }
  }
}

int main(int argc, char** argv) {
  long value;
  char* value_end;
  int stop, opt, error;
  
  eb_socket_t socket;
  eb_status_t status;
  eb_device_t device;
  eb_width_t line_width;
  eb_format_t line_widths;
  eb_format_t device_support;
  eb_format_t read_sizes;
  eb_format_t format;
  eb_cycle_t cycle;
  eb_data_t mask;
  int shift;
  
  /* Specific command-line options */
  eb_format_t size;
  int attempts, probe, fidelity, silent, config;
  const char* netaddress;

  /* Default arguments */
  program = argv[0];
  address_width = EB_ADDRX;
  data_width = EB_DATAX;
  size = EB_DATAX;
  endian = 0; /* auto-detect */
  attempts = 3;
  probe = 1;
  fidelity = 0;
  quiet = 0;
  verbose = 0;
  error = 0;
  silent = 0;
  config = 0;
  
  /* Process the command-line arguments */
  while ((opt = getopt(argc, argv, "a:d:blr:fcpsvqh")) != -1) {
    switch (opt) {
    case 'a':
      value = eb_width_parse_address(optarg, &address_width);
      if (value != EB_OK) {
        fprintf(stderr, "%s: invalid address width -- '%s'\n", program, optarg);
        error = 1;
      }
      break;
    case 'd':
      value = eb_width_parse_data(optarg, &data_width);
      if (value != EB_OK) {
        fprintf(stderr, "%s: invalid data width -- '%s'\n", program, optarg);
        error = 1;
      }
      break;
    case 'b':
      endian = EB_BIG_ENDIAN;
      break;
    case 'l':
      endian = EB_LITTLE_ENDIAN;
      break;
    case 'r':
      value = strtol(optarg, &value_end, 0);
      if (*value_end || value < 0 || value > 100) {
        fprintf(stderr, "%s: invalid number of retries -- '%s'\n", program, optarg);
        return 1;
      }
      attempts = value;
      break;
    case 'f':
      fidelity = 1;
      break;
    case 'p':
      probe = 0;
      break;
    case 'c':
      config = 1;
      break;
    case 's':
      silent = 1;
      break;
    case 'v':
      verbose = 1;
      break;
    case 'q':
      quiet = 1;
      break;
    case 'h':
      help();
      return 1;
    case ':':
    case '?':
      error = 1;
      break;
    default:
      fprintf(stderr, "%s: bad getopt result\n", program);
      return 1;
    }
  }
  
  if (error) return 1;
  
  if (optind + 2 != argc) {
    fprintf(stderr, "%s: expecting two non-optional arguments: <proto/host/port> <address/size>\n", program);
    return 1;
  }
  
  netaddress = argv[optind];
  
  address = strtoull(argv[optind+1], &value_end, 0);
  if (*value_end == '/')
    size = strtoull(value_end+1, &value_end, 0);
  else
    size = 0;
  if (*value_end != 0 || (size != 1 && size != 2 && size != 4 && size != 8)) {
    fprintf(stderr, "%s: argument does not match format <address>/<1|2|3|4|8> -- '%s'\n",
                    program, argv[optind+1]);
    return 1;
  }
  
  if ((address & (size-1)) != 0) {
    fprintf(stderr, "%s: 0x%"EB_ADDR_FMT" is not aligned to a %d byte boundary\n", 
                    program, address, size);
    return 1;
  }
  
  if (size > sizeof(eb_data_t)) {
    fprintf(stderr, "%s: local Etherbone library only supports %s-bit operations.\n", 
                    program, eb_width_data((sizeof(eb_data_t)<<1) - 1));
    return 1;
  }
  
  /* How big can the data be? */
  mask = ~(eb_data_t)0;
  mask >>= (sizeof(eb_data_t)-size)*8;
  
  if (verbose)
    fprintf(stdout, "Opening socket with %s-bit address and %s-bit data widths\n", 
                    eb_width_address(address_width), eb_width_data(data_width));
  
  if ((status = eb_socket_open(EB_ABI_CODE, 0, address_width|data_width, &socket)) != EB_OK) {
    fprintf(stderr, "%s: failed to open Etherbone socket: %s\n", program, eb_status(status));
    return 1;
  }
  
  if (verbose)
    fprintf(stdout, "Connecting to '%s' with %d retry attempts...\n", netaddress, attempts);
  
  if ((status = eb_device_open(socket, netaddress, EB_ADDRX|EB_DATAX, attempts, &device)) != EB_OK) {
    fprintf(stderr, "%s: failed to open Etherbone device: %s\n", program, eb_status(status));
    return 1;
  }
  
  line_width = eb_device_width(device);
  if (verbose)
    fprintf(stdout, "  negotiated %s-bit address and %s-bit data session.\n", 
                    eb_width_address(line_width), eb_width_data(line_width));
  
  if (probe) {
    if (verbose)
      fprintf(stdout, "Scanning remote bus for Wishbone devices...\n");

    struct sdb_device info;
    if ((status = eb_sdb_find_by_address(device, address, &info)) != EB_OK) {
      fprintf(stderr, "%s: failed to find SDB record: %s\n", program, eb_status(status));
      return 1;
    }
    
    if ((info.bus_specific & SDB_WISHBONE_LITTLE_ENDIAN) != 0)
      device_support = EB_LITTLE_ENDIAN;
    else
      device_support = EB_BIG_ENDIAN;
    device_support |= info.bus_specific & EB_DATAX;
  } else {
    device_support = endian | EB_DATAX;
  }
  
  /* Did the user request a bad endian? We use it anyway, but issue warning. */
  if (endian != 0 && (device_support & EB_ENDIAN_MASK) != endian) {
    if (!quiet)
      fprintf(stderr, "%s: warning: target device is %s (reading as %s).\n",
                      program, eb_format_endian(device_support), eb_format_endian(endian));
  }
  
  if (endian == 0) {
    /* Select the probed endian. May still be 0 if device not found. */
    endian = device_support & EB_ENDIAN_MASK;
  }
  
  /* Final operation endian has been chosen. If 0 the access had better be a full data width access! */
  format = endian;
  
  /* We need to pick the operation width we use.
   * It must be supported both by the device and the line.
   */
  line_widths = ((line_width & EB_DATAX) << 1) - 1; /* Link can support any access smaller than line_width */
  read_sizes = line_widths & device_support;
    
  /* We cannot work with a device that requires larger access than we support */
  if (read_sizes == 0) {
    fprintf(stderr, "%s: error: device's %s-bit data port cannot be used via a %s-bit wire format\n",
                    program, eb_width_data(device_support), eb_width_data(line_width));
    return 1;
  }
  
  /* Begin the cycle */
  if ((status = eb_cycle_open(device, &stop, &set_stop, &cycle)) != EB_OK) {
    fprintf(stderr, "%s: failed to create cycle: %s\n", program, eb_status(status));
    return 1;
  }
  
  /* Can the operation be performed with fidelity? */
  if ((size & read_sizes) == 0) {
    eb_format_t fragment_sizes;
    eb_format_t fragment_size;
    eb_format_t complete_size;
    
    /* We are about to screw with their operation to get it to work... */
    if (fidelity) {
      if ((size & line_widths) == 0)
        fprintf(stderr, "%s: error: cannot perform a %s-bit read through a %s-bit connection\n",
                        program, eb_width_data(size), eb_width_data(line_widths));
      else
        fprintf(stderr, "%s: error: cannot perform a %s-bit read to a %s-bit device\n",
                        program, eb_width_data(size), eb_width_data(device_support));
      return 1;
    }
    
    /* What will we do? Prefer to fragment if possible; reading is evil. */
    
    /* Fragmented reading is possible if there is a bit in read_sizes smaller than a bit in size */
    fragment_sizes = size;
    fragment_sizes |= fragment_sizes >> 1;
    fragment_sizes |= fragment_sizes >> 2; /* Filled in all sizes under max */
    if ((fragment_sizes & read_sizes) != 0) {
      int stride, chunk, count;
      
      /* We can do a fragmented read. Pick largest read possible. */
      complete_size = fragment_sizes ^ (fragment_sizes >> 1); /* This many bytes to read */
      /* (the above code sets complete_size = size, but works also if size were a mask) */
      
      /* Filter out only those which have a good read size */
      fragment_sizes &= read_sizes;
      /* Then pick the largest bit */
      fragment_sizes |= fragment_sizes >> 1;
      fragment_sizes |= fragment_sizes >> 2;
      fragment_size = fragment_sizes ^ (fragment_sizes >> 1);
      
      /* We read fragments */
      format |= fragment_size;
      
      if (!quiet)
        fprintf(stderr, "%s: warning: fragmenting %s-bit read into %s-bit operations\n",
                        program, eb_width_data(complete_size), eb_width_data(format));
      
      /* Each operation reads this many bytes */
      chunk = format & EB_DATAX;
      count = complete_size / chunk;
      
      /* Read the low bits first */
      switch (format & EB_ENDIAN_MASK) {
      case EB_BIG_ENDIAN:
        stride = chunk;
        break;
      case EB_LITTLE_ENDIAN:
        address += chunk*(count-1);
        stride = -chunk;
        break;
      default:
        fprintf(stderr, "%s: error: must know endian to fragment read\n",
                        program);
        return 1;
      }
      
      for (; count > 0; --count) {
        if (verbose)
          fprintf(stdout, "Reading 0x%"EB_ADDR_FMT"/%d\n",
                          address, format & EB_DATAX);
        
        if (config)
          eb_cycle_read_config(cycle, address, format, 0);
        else
          eb_cycle_read(cycle, address, format, 0);
        address += stride;
      }
      
      shift = 0;
    } else {
      eb_address_t aligned_address;
      
      /* All bits in read_sizes are larger than all bits in size */
      /* We will need to do a larger operation than the read requested. */
      
      /* Pick the largest sized read possible. */
      fragment_size = fragment_sizes ^ (fragment_sizes >> 1);
      /* (the above code sets fragment_size = size, but works also if size were a mask) */
      
      /* Now pick the smallest bit in read_sizes. */
      complete_size = read_sizes & -read_sizes;
      
      /* We have our final operation format. */
      format |= complete_size;
      
      if (!quiet)
        fprintf(stderr, "%s: warning: reading %s bits to read a %s bit fragment\n",
                        program, eb_width_data(complete_size), eb_width_data(fragment_size));
      
      /* Align the address */
      aligned_address = address & ~(eb_address_t)(complete_size-1);
      
      /* How far do we need to shift the offset? */
      switch (format & EB_ENDIAN_MASK) {
      case EB_BIG_ENDIAN:
        shift = (complete_size-fragment_size) - (address - aligned_address);
        break;
      case EB_LITTLE_ENDIAN:
        shift = (address - aligned_address);
        break;
      default:
        fprintf(stderr, "%s: error: must know endian to fill a partial read\n",
                        program);
        return 1;
      }
      
      /* Issue the read */
      if (config)
        eb_cycle_read_config(cycle, aligned_address, format, 0);
      else
        eb_cycle_read(cycle, aligned_address, format, 0);
      if (verbose)
        fprintf(stdout, "Reading 0x%"EB_ADDR_FMT"/%d\n",
                        aligned_address, format & EB_DATAX);
    }
  } else {
    /* There is a size requested that the device and link supports */
    format |= (size & read_sizes);
    
    /* If the access it full width, an endian is needed. Print a friendlier message than EB_ADDRESS. */
    if ((format & line_width & EB_DATAX) == 0 && (format & EB_ENDIAN_MASK) == 0) {
      fprintf(stderr, "%s: error: when wreading %s-bit through a %s-bit connection, endian is required.\n",
                      program, eb_width_data(format), eb_width_data(line_width));
      return 1;
    }
    
    if (verbose)
      fprintf(stdout, "Reading 0x%"EB_ADDR_FMT"/%d\n",
                      address, format & EB_DATAX);
    
    if (config)
      eb_cycle_read_config(cycle, address, format, 0);
    else
      eb_cycle_read(cycle, address, format, 0);
    shift = 0;
  }
  
  
  if (silent)
    eb_cycle_close_silently(cycle);
  else
    eb_cycle_close(cycle);
    
  stop = 0;
  while (!stop) {
    eb_socket_run(socket, -1);
  }
  
  data >>= shift*8;
  data &= mask;
  fprintf(stdout, "%0*"EB_DATA_FMT"\n", size*2, data);
  
  if ((status = eb_device_close(device)) != EB_OK) {
    fprintf(stderr, "%s: failed to close Etherbone device: %s\n", program, eb_status(status));
    return 1;
  }
  
  if ((status = eb_socket_close(socket)) != EB_OK) {
    fprintf(stderr, "%s: failed to close Etherbone socket: %s\n", program, eb_status(status));
    return 1;
  }
  
  return 0;
}
