/** @file cplusplus.cpp
 *  @brief Implement C++ bindings not done well inline.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Most of the C++ binding is inlined in etherbone.h.
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

#include "../etherbone.h"

namespace etherbone {

eb_status_t eb_proxy_read_handler(eb_user_data_t data, eb_address_t address, eb_width_t width, eb_data_t* ptr) {
  Handler* handler = reinterpret_cast<Handler*>(data);
  return handler->read(address, width, ptr);
}

eb_status_t eb_proxy_write_handler(eb_user_data_t data, eb_address_t address, eb_width_t width, eb_data_t value) {
  Handler* handler = reinterpret_cast<Handler*>(data);
  return handler->write(address, width, value);
}

Handler::~Handler() {
}

eb_status_t Device::sdb_find_by_identity(uint64_t vendor_id, uint32_t device_id, std::vector<struct sdb_device>& output) {
  eb_status_t status;
  int size = 32; /* initial size */
  
  output.resize(size);
  if ((status = eb_sdb_find_by_identity(device, vendor_id, device_id, &output[0], &size)) != EB_OK) {
    output.clear();
    return status;
  }
  
  if (size > (int)output.size()) {
    output.resize(size);
    /* try again with large enough array */
    status = eb_sdb_find_by_identity(device, vendor_id, device_id, &output[0], &size);
  }
  
  if (status == EB_OK) {
    output.resize(size);
  } else {
    output.clear();
  }
  
  return status;
}

}
