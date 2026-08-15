/** @file operation.c
 *  @brief Implement the Etherbone operation data structure.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  These accessors only deal with how operations appear in callbacks.
 *  For initialization, see cycle.c. For processing, see format/master.c.
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

#include "operation.h"
#include "../memory/memory.h"

eb_operation_t eb_operation_next(eb_operation_t opp) {
  return EB_OPERATION(opp)->next;
}

int eb_operation_is_read(eb_operation_t opp) {
  return (EB_OPERATION(opp)->flags & EB_OP_MASK) != EB_OP_WRITE;
}

int eb_operation_is_config(eb_operation_t opp) {
  return (EB_OPERATION(opp)->flags & EB_OP_CFG_SPACE) != 0;
}

int eb_operation_had_error(eb_operation_t opp) {
  return (EB_OPERATION(opp)->flags & EB_OP_ERROR) != 0;
}

eb_address_t eb_operation_address(eb_operation_t opp) {
  return EB_OPERATION(opp)->address;
}

eb_data_t eb_operation_data(eb_operation_t opp) {
  struct eb_operation* op;
  
  op = EB_OPERATION(opp);
  switch (op->flags & EB_OP_MASK) {
  case EB_OP_WRITE:	return op->un_value.write_value;
  case EB_OP_READ_PTR:	return *op->un_value.read_destination;
  case EB_OP_READ_VAL:	return op->un_value.read_value;
  }
  
  /* unreachable */
  return 0;
}

eb_format_t eb_operation_format(eb_operation_t opp) {
  return EB_OPERATION(opp)->format;
}

eb_operation_t eb_find_bus(eb_operation_t opp) {
  struct eb_operation* op;
  
  for (; opp != EB_NULL; opp = op->next) {
    op = EB_OPERATION(opp);
    if ((op->flags & EB_OP_CFG_SPACE) == 0) break;
  }
  return opp;
}

eb_operation_t eb_find_read(eb_operation_t opp) {
  struct eb_operation* op;
  
  for (; opp != EB_NULL; opp = op->next) {
    op = EB_OPERATION(opp);
    if ((op->flags & EB_OP_MASK) != EB_OP_WRITE) break;
  }
  return opp;
}
