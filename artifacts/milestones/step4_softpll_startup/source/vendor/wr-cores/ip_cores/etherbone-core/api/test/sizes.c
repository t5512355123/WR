/** @file sizes.c
 *  @brief Debug the size of heap objects.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  With array-backed memory, this program determines bottleneck record size.
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

#include <stdio.h>

#include "../memory/memory.h"

int main(void) {
#ifndef EB_USE_MALLOC
  printf("operation        = %lu\n", (unsigned long)sizeof(struct eb_operation));
  printf("cycle            = %lu\n", (unsigned long)sizeof(struct eb_cycle));
  printf("device           = %lu\n", (unsigned long)sizeof(struct eb_device));
  printf("socket           = %lu\n", (unsigned long)sizeof(struct eb_socket));
  printf("handler_callback = %lu\n", (unsigned long)sizeof(struct eb_handler_callback));
  printf("handler_address  = %lu\n", (unsigned long)sizeof(struct eb_handler_address));
  printf("response         = %lu\n", (unsigned long)sizeof(struct eb_response));
  printf("free_item        = %lu\n", (unsigned long)sizeof(struct eb_free_item));
  printf("union            = %lu\n", (unsigned long)sizeof(union eb_memory_item));
#endif

  printf("sdb_empty        = %d\n", (unsigned)sizeof(struct sdb_empty));
  printf("sdb_interconnect = %d\n", (unsigned)sizeof(struct sdb_interconnect));
  printf("sdb_device       = %d\n", (unsigned)sizeof(struct sdb_device));
  printf("sdb_bridge       = %d\n", (unsigned)sizeof(struct sdb_bridge));
  return 0;
}
