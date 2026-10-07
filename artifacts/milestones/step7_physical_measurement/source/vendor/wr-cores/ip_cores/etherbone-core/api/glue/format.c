/** @file format.c
 *  @brief Implement string converion methos for integer types
 *
 *  Copyright (C) 2011-2013 GSI Helmholtz Centre for Heavy Ion Research GmbH 
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

#include <stdlib.h>
#include "../etherbone.h"

const char* eb_status(eb_status_t code) {
  switch (code) {
  case EB_SEGFAULT: return "one or more operations failed";
  case EB_OK:       return "success";
  case EB_FAIL:     return "system failure";
  case EB_ADDRESS:  return "invalid address";
  case EB_WIDTH:    return "impossible bus width";
  case EB_OVERFLOW: return "cycle length overflow";
  case EB_ENDIAN:   return "remote endian required";
  case EB_BUSY:     return "resource busy";
  case EB_TIMEOUT:  return "timeout";
  case EB_OOM:      return "out of memory";
  case EB_ABI:      return "library incompatible with application";
  default:          return "unknown Etherbone error code";
  }
}

static const char* endian_str[4] = {
 /*  0 */ "auto-endian",
 /*  1 */ "big-endian",
 /*  2 */ "little-endian",
 /*  3 */ "invalid-endian"
};

static const char* width_str[16] = {
 /*  0 */ "<null>",
 /*  1 */ "8",
 /*  2 */ "16",
 /*  3 */ "8/16",
 /*  4 */ "32",
 /*  5 */ "8/32",
 /*  6 */ "16/32",
 /*  7 */ "8/16/32",
 /*  8 */ "64",
 /*  9 */ "8/64",
 /* 10 */ "16/64",
 /* 11 */ "8/16/64",
 /* 12 */ "32/64",
 /* 13 */ "8/32/64",
 /* 14 */ "16/32/64",
 /* 15 */ "8/16/32/64"
};

const char* eb_width_data(eb_width_t width) {
  return width_str[width & EB_DATAX];
}

const char* eb_width_address(eb_width_t width) {
  return width_str[(width & EB_ADDRX) >> 4];
}

const char* eb_format_data(eb_format_t format) {
  return width_str[format & EB_DATAX];
}

const char* eb_format_endian(eb_format_t format) {
  return endian_str[(format & EB_ENDIAN_MASK) >> 4];
}

static int eb_parse_width(const char* str) {
  int width, widths;
  char* next;
  
  widths = 0;
  while (1) {
    width = strtol(str, &next, 0);
    if (width != 8 && width != 16 && width != 32 && width != 64) break;
    widths |= width/8;
    if (!*next) return widths;
    if (*next != '/' && *next != ',') break;
    str = next+1;
  }
  
  return -1;
}

int eb_width_parse_data(const char* str, eb_width_t* width) {
  int result = eb_parse_width(str);
  if (result < 0) return EB_WIDTH;
  
  *width = result | (*width & EB_ADDRX);
  return EB_OK;
}

int eb_width_parse_address(const char* str, eb_width_t* width) {
  int result = eb_parse_width(str);
  if (result < 0) return EB_WIDTH;
  
  *width = (result<<4) | (*width & EB_DATAX);
  return EB_OK;
}
