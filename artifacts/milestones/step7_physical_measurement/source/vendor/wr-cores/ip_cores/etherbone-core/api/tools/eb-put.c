/** @file eb-upload.c
 *  @brief A program which uploads a file to a device.
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

#define _POSIX_C_SOURCE 200112L /* strtoull */
#define _ISOC99_SOURCE /* strtoull on old systems */

#include <unistd.h> /* getopt */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "../etherbone.h"
#include "../glue/version.h"

#define OPERATIONS_PER_CYCLE 32

static const char* program;
static eb_width_t address_width, data_width;
static eb_address_t address;
static eb_format_t endian;
static int verbose, quiet;

static void help(void) {
  fprintf(stderr, "Usage: %s [OPTION] <proto/host/port> <address> <firmware>\n", program);
  fprintf(stderr, "\n");
  fprintf(stderr, "  -a <width>     acceptable address bus widths     (8/16/32/64)\n");
  fprintf(stderr, "  -d <width>     acceptable data bus widths        (8/16/32/64)\n");
  fprintf(stderr, "  -c <cycles>    cycles to pack per packet               (auto)\n");
  fprintf(stderr, "  -b             big-endian operation                    (auto)\n");
  fprintf(stderr, "  -l             little-endian operation                 (auto)\n");
  fprintf(stderr, "  -r <retries>   number of times to attempt autonegotiation (3)\n");
  fprintf(stderr, "  -f             force; ignore remote segfaults\n");
  fprintf(stderr, "  -p             disable self-describing wishbone device probe\n");
  fprintf(stderr, "  -v             verbose operation\n");
  fprintf(stderr, "  -q             quiet: do not display warnings\n");
  fprintf(stderr, "  -h             display this help and exit\n");
  fprintf(stderr, "\n");
  fprintf(stderr, "Report Etherbone bugs to <etherbone-core@ohwr.org>\n");
  fprintf(stderr, "Version %"PRIx32" (%s). Licensed under the LGPL v3.\n", EB_VERSION_SHORT, EB_DATE_FULL);
}

/* Counter for completion */
static int todo;
static FILE* firmware_f;
static const char* firmware;

static void dec_todo(eb_user_data_t data, eb_device_t dev, eb_operation_t op, eb_status_t status) {
  /* Check overall status */
  if (status != EB_OK) {
    fprintf(stderr, "\r%s: etherbone cycle error: %s\n", 
                    program, eb_status(status));
    exit(1);
  }
  
  /* Check operation error lines */
  for (; op != EB_NULL; op = eb_operation_next(op)) {
    if (eb_operation_had_error(op)) {
      fprintf(stderr, "\r%s: wishbone segfault writing %s %s bits to address 0x%"EB_ADDR_FMT".\n",
        program, 
        eb_width_data(eb_operation_format(op)),
        eb_format_endian(eb_operation_format(op)), 
        eb_operation_address(op));
      exit(1);
    }
  }
  
  --todo;
}

static int force;
static void transfer(eb_device_t device, eb_address_t address, eb_format_t format, int count) {
  eb_data_t data;
  eb_cycle_t cycle;
  eb_format_t size;
  eb_status_t status;
  uint8_t buffer[16];
  int i, j;
  
  size = format & EB_DATAX;
  
  if (verbose)
    fprintf(stdout, "\rProgramming 0x%"EB_ADDR_FMT"-", address);
  
  if ((status = eb_cycle_open(device, 0, &dec_todo, &cycle)) != EB_OK) {
    fprintf(stderr, "\r%s: cannot create cycle: %s\n", program, eb_status(status));
    exit(1);
  }
  
  for (i = 0; i < count; ++i) {
    if (fread(buffer, 1, size, firmware_f) != size) {
      fprintf(stderr, "\r%s: short read from '%s'\n", 
                      program, firmware);
      exit(1);
    }
    
    /* Construct value */
    data = 0;
    if ((format & EB_ENDIAN_MASK) == EB_BIG_ENDIAN) {
      for (j = 0; j < size; ++j) {
        data <<= 8;
        data |= buffer[j];
      }
    } else {
      for (j = size-1; j >= 0; --j) {
        data <<= 8;
        data |= buffer[j];
      }
    }
    
    eb_cycle_write(cycle, address, format, data);
    address += size;
  }
  
  if (verbose) {
    fprintf(stdout, "0x%"EB_ADDR_FMT"... ", address-1);
    fflush(stdout);
  }
  
  if (force)
    eb_cycle_close_silently(cycle);
  else
    eb_cycle_close(cycle);
  ++todo;
}
  
int main(int argc, char** argv) {
  long value;
  char* value_end;
  int opt, cycle, error;
  
  eb_socket_t socket;
  eb_status_t status;
  eb_device_t device;
  eb_width_t line_width;
  eb_format_t line_widths;
  eb_format_t device_support;
  eb_format_t write_sizes;
  eb_format_t bulk;
  eb_format_t edge;
  eb_address_t end_address, end_bulk, step, pos;
  
  /* Specific command-line options */
  int attempts, probe, cycles;
  const char* netaddress;
  eb_address_t firmware_length;

  /* Default arguments */
  program = argv[0];
  address_width = EB_ADDRX;
  data_width = EB_DATAX;
  endian = 0; /* auto-detect */
  attempts = 3;
  probe = 1;
  quiet = 0;
  verbose = 0;
  error = 0;
  cycles = 0;
  force = 0;
  
  /* Process the command-line arguments */
  while ((opt = getopt(argc, argv, "a:d:c:blr:fpvqh")) != -1) {
    switch (opt) {
    case 'a':
      value = eb_width_parse_address(optarg, &address_width);
      if (value != EB_OK) {
        fprintf(stderr, "%s: invalid address width -- '%s'\n", program, optarg);
        return 1;
      }
      break;
    case 'd':
      value = eb_width_parse_data(optarg, &data_width);
      if (value != EB_OK) {
        fprintf(stderr, "%s: invalid data width -- '%s'\n", program, optarg);
        return 1;
      }
      break;
    case 'c':
      value = strtol(optarg, &value_end, 0);
      if (*value_end || value < 0 || value > 100) {
        fprintf(stderr, "%s: invalid cycle count -- '%s'\n", program, optarg);
        return 1;
      }
      cycles = value;
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
      force = 1;
      break;
    case 'p':
      probe = 0;
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
  
  if (optind + 3 != argc) {
    fprintf(stderr, "%s: expecting three non-optional arguments: <proto/host/port> <address> <firmware>\n", program);
    return 1;
  }
  
  netaddress = argv[optind];
  
  address = strtoull(argv[optind+1], &value_end, 0);
  if (*value_end != 0) {
    fprintf(stderr, "%s: argument is not an unsigned value -- '%s'\n",
                    program, argv[optind+1]);
    return 1;
  }
  
  firmware = argv[optind+2];
  if ((firmware_f = fopen(firmware, "r")) == 0) {
    fprintf(stderr, "%s: fopen, %s -- '%s'\n",
                    program, strerror(errno), firmware);
    return 1;
  }
  
  if (fseeko(firmware_f, 0, SEEK_END) != 0) {
    fprintf(stderr, "%s: fseeko, %s -- '%s'\n",
                    program, strerror(errno), firmware);
    return 1;
  }
  
  firmware_length = ftello(firmware_f);
  fseeko(firmware_f, 0, SEEK_SET);
  
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
    
    if (info.sdb_component.addr_last - address < firmware_length-1) {
      if (!quiet)
        fprintf(stderr, "%s: warning: firmware end address 0x%"EB_ADDR_FMT" is past device end 0x%"EB_ADDR_FMT".\n", 
                        program, address+firmware_length-1, (eb_address_t)info.sdb_component.addr_last);
    }
  } else {
    device_support = endian | EB_DATAX;
  }
  
  /* Did the user request a bad endian? We use it anyway, but issue warning. */
  if (endian != 0 && (device_support & EB_ENDIAN_MASK) != endian) {
    if (!quiet)
      fprintf(stderr, "%s: warning: target device is %s (writing as %s).\n",
                      program, eb_format_endian(device_support), eb_format_endian(endian));
  }
  
  if (endian == 0) {
    /* Select the probed endian. May still be 0 if device not found. */
    endian = device_support & EB_ENDIAN_MASK;
  }
  
  /* We need to know endian if it's not aligned to the line size */
  if (endian == 0) {
    fprintf(stderr, "%s: error: must know endian to program firmware\n",
                    program);
    return 1;
  }
  
  /* We need to pick the operation width we use.
   * It must be supported both by the device and the line.
   */
  line_widths = ((line_width & EB_DATAX) << 1) - 1; /* Link can support any access smaller than line_width */
  write_sizes = line_widths & device_support;
    
  /* We cannot work with a device that requires larger access than we support */
  if (write_sizes == 0) {
    fprintf(stderr, "%s: error: device's %s-bit data port cannot be used via a %s-bit wire format\n",
                    program, eb_width_data(device_support), eb_width_data(line_width));
    return 1;
  }
  
  /* Pick the largest possible write_size for bulk transfer */
  bulk = write_sizes;
  bulk |= bulk >> 1;
  bulk |= bulk >> 2;
  bulk ^= bulk >> 1;
  
  /* Pick the smallest possible write_size for edge transfer */
  edge = write_sizes & -write_sizes;
  
  /* Calculate a reasonable number to pack in a packet */
  if (cycles == 0) {
    eb_width_t line_alignment;
    int cost, status;
    
    status = OPERATIONS_PER_CYCLE / ((line_width & EB_DATAX) * 8);
    if (status == 0) status = 1;
    
    /* How many bytes per line alignment? */
    line_alignment = line_width >> 4 | (line_width & EB_DATAX);
    line_alignment |= line_alignment >> 1;
    line_alignment |= line_alignment >> 2;
    line_alignment ^= line_alignment >> 1;
    
    /* Can the writes be compressed? */
    if (bulk != (line_width & EB_DATAX)) {
      /* Each needs its own header */
      cost = OPERATIONS_PER_CYCLE;
      cost *= 3 * line_alignment;
      cost += status * 3 * line_alignment;
    } else {
      cost = OPERATIONS_PER_CYCLE;
      cost *= line_alignment;
      cost += status * 6 * line_alignment;
    }
    
    /* A decent MTU */
    cycles = 1450 / cost;
    if (cycles == 0) cycles = 1;
  }
  
  if (verbose)
    fprintf(stdout, "Programming using batches of %d %s %s-bit words and %s-bit alignment\n",
                     OPERATIONS_PER_CYCLE*cycles, eb_format_endian(endian), eb_width_data(bulk), eb_width_data(edge));
  
  /* Confirm we can write the requested size faithfully */
  if ((firmware_length & (edge-1)) != 0) {
    fprintf(stderr, "%s: error: firmware length 0x%"EB_ADDR_FMT" is not a multiple of the minimum device granularity, %s-bit.\n",
                    program, firmware_length, eb_width_data(edge));
  }
  
  /* Confirm we can write the requested address faithfully */
  if ((address & (edge-1)) != 0) {
    fprintf(stderr, "%s: error: base address 0x%"EB_ADDR_FMT" is not a multiple of the minimum device granularity, %s-bit.\n",
                    program, address, eb_width_data(edge));
  }
  
  /* Start counting cycles */
  todo = 0;
  end_address = address + firmware_length;
  
  /* Write any edge chunks needed to reach bulk alignment */
  for (pos = address; (pos & (bulk-1)) != 0; pos += edge)
    transfer(device, pos, endian | edge, 1);
  
  /* Wait for head to be written */
  while (todo > 0) {
    eb_socket_run(socket, -1);
  }
  
  /* Begin the bulk transfer */
  end_bulk = end_address & ~(eb_address_t)(bulk-1);
  for (cycle = 0; pos < end_bulk; pos += step*bulk) {
    step = end_bulk - pos;
    step /= bulk;
    
    /* Don't put too many in one cycle */
    if (step > OPERATIONS_PER_CYCLE) step = OPERATIONS_PER_CYCLE;
    transfer(device, pos, endian | bulk, step);
    
    /* Flush? */
    if (++cycle == cycles) {
      cycle = 0;
      while (todo > 0) {
        eb_socket_run(socket, -1);
      }
    }
  }
  
  /* Write any edge chunks needed to reach bulk final address */
  for (; pos < end_address; pos += edge)
    transfer(device, pos, endian | edge, 1);
  
  if (verbose) {
    fprintf(stdout, " done!\n");
    fprintf(stdout, "Awaiting acknowledgement... ");
    fflush(stdout);
  }
  
  /* Wait for tail to be written */
  while (todo > 0) {
    eb_socket_run(socket, -1);
  }
  
  if (verbose)
    fprintf(stdout, " done!\n");
  
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
