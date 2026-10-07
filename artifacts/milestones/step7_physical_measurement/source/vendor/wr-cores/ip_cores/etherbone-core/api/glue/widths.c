/** @file widths.c
 *  @brief Helper functions for manipulating the width type.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  These give a few bit twiddling functions meaningful names.
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

#include "widths.h"

int eb_width_possible(eb_width_t width) {
  eb_width_t data = width & 0xf;
  eb_width_t addr = width >> 4;
  return data != 0 && addr != 0;
}

int eb_width_refined(eb_width_t width) {
  eb_width_t data = width & 0xf;
  eb_width_t addr = width >> 4;
  
  return data != 0 && addr != 0 && 
         (data & (data-1)) == 0 && 
         (addr & (addr-1)) == 0;
}

eb_width_t eb_width_refine(eb_width_t width) {
  eb_width_t data = width & 0xf;
  eb_width_t addr = width >> 4;
  
  addr |= addr >> 1;
  addr |= addr >> 2;
  ++addr;
  addr >>= 1;
  
  data |= data >> 1;
  data |= data >> 2;
  ++data;
  data >>= 1;
  
  return (addr << 4) | data;
}
