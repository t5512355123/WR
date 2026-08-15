/** @file strncasecmp.c
 *  @brief Implement case-insensitive string comparison.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Sadly, strncasecmp requires C99.
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

#include <ctype.h>
#include "strncasecmp.h"

int eb_strncasecmp(const char* s1, const char* s2, int len) {
  const char* eos = s1 + len;
  
  for (; s1 != eos && *s1 && *s2; ++s1, ++s2) {
    if (toupper(*s1) != toupper(*s2)) break;
  }
  
  return (s1 != eos) * (toupper(*s1) - toupper(*s2));
}
