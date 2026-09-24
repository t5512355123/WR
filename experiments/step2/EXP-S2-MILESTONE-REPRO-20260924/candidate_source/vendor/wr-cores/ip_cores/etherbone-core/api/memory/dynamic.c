/** @file dynamic.c
 *  @brief Resize the memory array when it is exhaused, using realloc.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  To keep memory management simple, all dynamic objects occupy the same space.
 *  This implementation assumes a backing C runtime memory subsystem.
 *  Using dynamic.c instead of malloc.c is faster and deterministic, so long as
 *  the available memory is not exhausted, necessitating a resize.
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

#if !defined(EB_USE_STATIC) && !defined(EB_USE_MALLOC)

#include <stdlib.h>
#include "memory.h"

union eb_memory_item* eb_memory_array = 0;
EB_PRIVATE uint32_t eb_memory_array_size = 128; /* ie: initally 256 */

int eb_expand_array(void) {
  void* new_address;
  uint32_t next_size, i;
  
  /* When next_size reaches the maximum of 64k entries, fail */
  if (eb_memory_array_size == 65536) return -1;
  
  /* Doubling ensures constant cost */
  next_size = eb_memory_array_size + eb_memory_array_size;
  
  if (eb_memory_array)
    new_address = realloc(eb_memory_array, sizeof(union eb_memory_item) * next_size);
  else
    new_address = malloc(sizeof(union eb_memory_item) * next_size);
  
  if (new_address == 0) 
    return -1;
  
  eb_memory_array = (union eb_memory_item*)new_address;
  
  /* Link together the expanded free list */
  for (i = eb_memory_array_size; i != next_size; ++i)
    eb_memory_array[i].free_item.next = i+1; 

  eb_memory_array[next_size-1].free_item.next = EB_END_OF_FREE;
  eb_memory_free = eb_memory_array_size;
  eb_memory_array_size = next_size;
  
  return 0;
}

#endif
