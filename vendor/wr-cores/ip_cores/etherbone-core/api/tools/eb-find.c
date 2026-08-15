/** @file eb-find.c
 *  @brief A tool which finds the address of a Wishbone device.
 *
 *  Copyright (C) 2014 GSI Helmholtz Centre for Heavy Ion Research GmbH 
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

#define MAX_DEVICES 1000

static const char* program;
static eb_width_t address_width, data_width;
static int verbose, index;

static void help(void) {
  fprintf(stderr, "Usage: %s [OPTION] <proto/host/port> <vendor-id> <device-id>\n", program);
  fprintf(stderr, "\n");
  fprintf(stderr, "  -a <width>     acceptable address bus widths     (8/16/32/64)\n");
  fprintf(stderr, "  -d <width>     acceptable data bus widths        (8/16/32/64)\n");
  fprintf(stderr, "  -r <retries>   number of times to attempt autonegotiation (3)\n");
  fprintf(stderr, "  -n <index>     show only the n-th device's address (show all)\n");
  fprintf(stderr, "  -v             verbose operation\n");
  fprintf(stderr, "  -h             display this help and exit\n");
  fprintf(stderr, "\n");
  fprintf(stderr, "Report Etherbone bugs to <etherbone-core@ohwr.org>\n");
  fprintf(stderr, "Version %"PRIx32" (%s). Licensed under the LGPL v3.\n", EB_VERSION_SHORT, EB_DATE_FULL);
}

int main(int argc, char** argv) {
  long value;
  char* value_end;
  int opt, error;
  
  eb_socket_t socket;
  eb_status_t status;
  eb_device_t device;
  
  /* Specific command-line options */
  const char* netaddress;
  const char* vendor_ids;
  const char* device_ids;
  int attempts;
  uint64_t vendor_id;
  uint32_t device_id;
  
  int num_devices;
  struct sdb_device devices[MAX_DEVICES];
  
  /* Default command-line arguments */
  program = argv[0];
  address_width = EB_ADDRX;
  data_width = EB_DATAX;
  attempts = 3;
  verbose = 0;
  index = -1;
  error = 0;
  
  /* Process the command-line arguments */
  while ((opt = getopt(argc, argv, "a:d:r:n:vh")) != -1) {
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
    case 'r':
      value = strtol(optarg, &value_end, 0);
      if (*value_end || value < 0 || value > 100) {
        fprintf(stderr, "%s: invalid number of retries -- '%s'\n", program, optarg);
        return 1;
      }
      attempts = value;
      break;
    case 'n':
      value = strtol(optarg, &value_end, 0);
      if (*value_end || value < 0 || value > MAX_DEVICES) {
        fprintf(stderr, "%s: invalid device index -- '%s'\n", program, optarg);
        return 1;
      }
      index = value;
      break;
    case 'v':
      verbose = 1;
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
    fprintf(stderr, "%s: expecting three non-optional arguments: <protocol/host/port> <vendor-id> <device-id>\n", program);
    return 1;
  }
  
  netaddress = argv[optind];
  vendor_ids = argv[optind+1];
  device_ids = argv[optind+2];
  
  vendor_id = strtoull(vendor_ids, &value_end, 0);
  if (*value_end) {
    fprintf(stderr, "%s: invalid vendor id -- '%s'\n", program, vendor_ids);
    return 1;
  }
  
  device_id = strtoul(device_ids, &value_end, 0);
  if (*value_end) {
    fprintf(stderr, "%s: invalid device id -- '%s'\n", program, device_ids);
    return 1;
  }
  
  if ((status = eb_socket_open(EB_ABI_CODE, 0, address_width|data_width, &socket)) != EB_OK) {
    fprintf(stderr, "%s: failed to open Etherbone socket: %s\n", program, eb_status(status));
    return 1;
  }
  
  if ((status = eb_device_open(socket, netaddress, EB_ADDRX|EB_DATAX, attempts, &device)) != EB_OK) {
    fprintf(stderr, "%s: failed to open Etherbone device: %s\n", program, eb_status(status));
    return 1;
  }
  
  num_devices = MAX_DEVICES;
  eb_sdb_find_by_identity(device, vendor_id, device_id, &devices[0], &num_devices);
  if (num_devices == 0) {
    fprintf(stderr, "%s: no matching devices found\n", program);
    return 1;
  }
  
  if (num_devices > MAX_DEVICES) {
    fprintf(stderr, "%s: more devices found that tool supports (%d > %d)\n", program, num_devices, MAX_DEVICES);
    return 1;
  }
  
  if (index > num_devices) {
    fprintf(stderr, "%s: device #%d could not be found; only %d present\n", program, index, num_devices);
    return 1;
  }
  
  if (index == -1) {
    for (index = 0; index < num_devices; ++index) {
      printf("0x%"PRIx64"\n", devices[index].sdb_component.addr_first);
    }
  } else {
    printf("0x%"PRIx64"\n", devices[index].sdb_component.addr_first);
  }
  
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
