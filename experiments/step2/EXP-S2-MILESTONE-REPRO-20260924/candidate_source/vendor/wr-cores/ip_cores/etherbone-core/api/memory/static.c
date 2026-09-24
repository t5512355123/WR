/** @file static.c
 *  @brief Allocate a fixed-size memory array.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  To keep memory management simple, all dynamic objects occupy the same space.
 *  This is appropriate for use in an embedded system without a C runtime.
 *  Memory is internally managed in the global array.
 *  If the heap is full, EB_OOM errors will result.
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

#ifdef EB_USE_STATIC

#include "memory.h"

union eb_memory_item eb_memory_array[EB_USE_STATIC];
static const EB_POINTER(eb_memory_item) eb_memory_array_size = EB_USE_STATIC;

int eb_expand_array(void) {
  static int setup = 0;
  EB_POINTER(eb_memory_item) i;
  
  if (!setup) {
    setup = 1;
    
    for (i = 0; i != eb_memory_array_size; ++i)
      EB_FREE_ITEM(i)->next = i+1;
    
    EB_FREE_ITEM(eb_memory_array_size-1)->next = EB_END_OF_FREE;
    eb_memory_free = 0;
    
    return 0;
  } else {
    return -1;
  }
}

#endif
