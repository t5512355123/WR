/** @file loopback.cpp
 *  @brief A test program which executes many many EB queries.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  All Etherbone object types are opaque in this interface.
 *  Only those methods listed in this header comprise the public interface.
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

#define __STDC_FORMAT_MACROS
#define __STDC_CONSTANT_MACROS

// #define EB_MEMORY_HACK 1
#define EB_TEST_TCP 1

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <vector>
#include <list>
#include <algorithm>

#include "../etherbone.h"
#include "../glue/version.h"

#ifdef EB_MEMORY_HACK
extern uint16_t eb_memory_used; // A hack to read directly the memory consumption of EB
extern uint32_t eb_memory_array_size;
#endif

using namespace etherbone;
using namespace std;

void die(const char* why, status_t error);
void test_query(Device device, int len, int requests);
void test_width(Socket socket, width_t width);

static int serial = 0;
static bool loud = false;

void die(const char* why, status_t error) {
  fflush(stdout);
  fprintf(stderr, "%s: %s (%d)\n", why, eb_status(error), serial);
  exit(1);
}

enum RecordType { READ_BUS, READ_CFG, WRITE_BUS, WRITE_CFG };
struct Record {
  address_t address;
  data_t data;
  width_t width;
  bool error;
  RecordType type;
  
  Record(width_t width);
};

Record::Record(width_t width_) {
  static address_t prev = 0;
  long seed = rand();
  
  width_t addrw = width_ >> 4;
  width_t dataw = width_ & EB_DATAX;
  
  if ((seed & 31) == 0) {
    /* Perform sub-word access */
    if ((seed &  32) != 0) dataw /= 2;
    if ((seed &  64) != 0) dataw /= 2;
    if ((seed & 128) != 0) dataw /= 2;
    if (dataw == 0) dataw = 1;
    seed >>= 8;
  } else {
    seed >>= 5;
  }
  
  width = (addrw<<4) | dataw;
  
  address = rand();
  address += address*RAND_MAX;
  address += rand();
  address += address*RAND_MAX;
  address += rand();
  
  data = rand();
  data += data*RAND_MAX;
  data += rand();
  data += data*RAND_MAX;
  data += rand();
  
  switch (seed & 3) {
  case 0: type = READ_BUS; break;
  case 1: type = READ_CFG; break;
  case 2: type = WRITE_BUS; break;
  case 3: type = WRITE_CFG; break;
  }
  seed >>= 2;
  
  /* Expect no data for config space reads */
  if (type == READ_CFG)
    data = 0;
  
  /* Introduce a high chance for FIFO/seq access */
  if ((seed&3) != 3) {
    if (type == WRITE_BUS) address = prev;
    if (type == WRITE_CFG) address = prev & 0x7FFF;
  }
  seed >>= 2;
  
  data &= (data_t)(~0) >> ((sizeof(data)-dataw)*8);
  if (type == READ_CFG || type == WRITE_CFG) {
    /* Config space is narrower */
    address &= 0x7FFF;
    /* Don't stomp on the error flag register */
    if (address < 8) address = 8;
    /* Config space never has an error */
    error = 0;
  } else {
    /* Trim the request to fit the addr/data widths */
    address &= (address_t)(~0) >> ((sizeof(address)-addrw)*8);
    error = (seed & 3) == 1;
    seed >>= 2;
  }
  
  /* Align the access */
  address &= ~(address_t)(dataw-1);
  
  /* Cache for later use in FIFO IO */
  prev = address;
}

list<Record> expect;
class Echo : public Handler {
public:
  status_t read (address_t address, width_t width, data_t* data);
  status_t write(address_t address, width_t width, data_t  data);
};

status_t Echo::read (address_t address, width_t width, data_t* data) {
  if (loud)
    printf("recvd read  to %016"EB_ADDR_FMT"(bus): ", address);

  if (expect.empty()) die("unexpected read", EB_FAIL);
  Record r = expect.front();
  expect.pop_front();
  
  /* Confirm it's as we expect */
  if (r.width != width) die("wrong width recvd", EB_FAIL);
  if (r.type != READ_BUS) die("wrong op recvd", EB_FAIL);
  if (r.address != address) die("wrong addr recvd", EB_FAIL);
  
  *data = r.data;
  
  if (loud)
    printf("%016"EB_DATA_FMT": %s\n", *data, r.error?"fault":"ok");

  return r.error?EB_FAIL:EB_OK;
}

status_t Echo::write(address_t address, width_t width, data_t  data) {
  if (loud)
    printf("recvd write to %016"EB_ADDR_FMT"(bus): %016"EB_DATA_FMT": ", address, data);

  if (expect.empty()) die("unexpected write", EB_FAIL);
  Record r = expect.front();
  expect.pop_front();
  
  /* Confirm it's as we expect */
  if (r.width != width) die("wrong width recvd", EB_FAIL);
  if (r.type != WRITE_BUS) die("wrong op recvd", EB_FAIL);
  if (r.address != address) die("wrong addr recvd", EB_FAIL);
  if (r.data != data) die("wrong data recvd", EB_FAIL);
  
  if (loud)
    printf("%s\n", r.error?"fault":"ok");
  
  return r.error?EB_FAIL:EB_OK;
}

class TestCycle {
public:
  vector<Record> records;
  list<Record>::iterator first, last;
  int* success;

  void launch(Device device, int length, int* success);
  void complete(Device dev, Operation op, status_t status);
};

void TestCycle::complete(Device dev, Operation op, status_t status) {
#ifndef EB_TEST_TCP
  if (status == EB_OVERFLOW) {
    if (loud) printf("Skipping overflow cycle\n");
    ++*success;
    expect.erase(first, ++last);
    return;
  }
#endif
  
  if (status != EB_OK) die("cycle failed", status);

  for (unsigned i = 0; i < records.size(); ++i) {
    Record& r = records[i];
    
    if (op.is_null()) die("unexpected null op", EB_FAIL);
    
    if (loud)
      printf("reply %s to %016"EB_ADDR_FMT"(%s): %016"EB_DATA_FMT": %s\n", 
        op.is_read() ? "read ":"write",
        op.address(),
        op.is_config() ? "cfg" : "bus",
        op.data(),
        op.had_error()?"fault":"ok");
    
    switch (r.type) {
    case READ_BUS:  if (!op.is_read() ||  op.is_config()) die("wrong op", EB_FAIL); break;
    case READ_CFG:  if (!op.is_read() || !op.is_config()) die("wrong op", EB_FAIL); break;
    case WRITE_BUS: if ( op.is_read() ||  op.is_config()) die("wrong op", EB_FAIL); break;
    case WRITE_CFG: if ( op.is_read() || !op.is_config()) die("wrong op", EB_FAIL); break;
    }
    
    if (op.address  () != r.address) die("wrong addr", EB_FAIL);
    if (op.data     () != r.data)    die("wrong data", EB_FAIL);
    if (op.had_error() != r.error)   die("wrong flag", EB_FAIL);
    
    op = op.next();
  }
  if (!op.is_null()) die("too many ops", EB_FAIL);
  
  ++*success;
}

void TestCycle::launch(Device device, int length, int* success_) {
  success = success_;
  bool first_push = true;
  
  Cycle cycle;
  cycle.open(device, this, &wrap_member_callback<TestCycle, &TestCycle::complete>);
  
  for (int op = 0; op < length; ++op) {
    Record r(device.width());
    
    format_t format = (r.width & EB_DATAX) | EB_BIG_ENDIAN;
    
    switch (r.type) {
    case READ_BUS:  cycle.read        (r.address, format, 0);      break;
    case READ_CFG:  cycle.read_config (r.address, format, 0);      break;
    case WRITE_BUS: cycle.write       (r.address, format, r.data); break;
    case WRITE_CFG: cycle.write_config(r.address, format, r.data); break;
    }
    records.push_back(r);
    
    if (r.type == READ_BUS || r.type == WRITE_BUS) {
      expect.push_back(r);
      if (first_push) first = --expect.end();
      first_push = false;
      last = --expect.end();
    }

    if (loud)
      printf("query %s to %016"EB_ADDR_FMT"(%s): %016"EB_DATA_FMT"\n", 
        (r.type == READ_BUS || r.type == READ_CFG) ? "read ":"write",
        r.address,
        (r.type == READ_CFG || r.type == WRITE_CFG) ? "cfg" : "bus",
        r.data);
  }
  
  cycle.close();
}

void test_query(Device device, int len, int requests) {
  std::vector<int> cuts;
  std::vector<TestCycle> tests;
  unsigned i;
  int success, timeout;
  ++serial;
  
#if 0
  if (serial == 907) {
    printf("Enabling debug\n");
    loud = true;
  }
#endif
  
  cuts.push_back(0);
  cuts.push_back(len);
  for (int cut = 1; cut < requests; ++cut)
    cuts.push_back(len ? (rand() % (len+1)) : 0);
  sort(cuts.begin(), cuts.end());
  
  /* Prepare each cycle */
  tests.resize(requests);
  success = 0;
  for (i = 1; i < cuts.size(); ++i) {
    int amount = cuts[i] - cuts[i-1];
    tests[i-1].launch(device, amount, &success);
    if (loud) {
      if (i == cuts.size()-1) printf("---\n"); 
      else printf("...\n");
    }
  }
  
  /* Wait until all complete successfully */
  timeout = 1000000; /* 1 second */
  Socket socket = device.socket();
  while (success < requests && timeout > 0) {
    timeout -= socket.run(timeout);
  }
  
  if (timeout < 0) die("waiting for loopback success", EB_TIMEOUT);
}

void test_width(Socket socket, width_t width) {
  Device device;
  status_t err;
  
#ifdef EB_TEST_TCP
  if ((err = device.open(socket, "tcp/127.0.0.1/60368", width)) != EB_OK) die("device.open", err);
#else
  if ((err = device.open(socket, "udp/127.0.0.1/60368", width)) != EB_OK) die("device.open", err);
#endif
  
  for (int len = 0; len < 4000; ++len) {
#ifdef EB_MEMORY_HACK
    printf("\rLength: %d ==> %d/%d cells used... ", len, eb_memory_used, eb_memory_array_size);
    fflush(stdout);
#endif
    
    for (int requests = 1; requests <= 9; ++requests)
      for (int repetitions = 0; repetitions < 100; ++repetitions)
        test_query(device, len, requests);
  }
    
  if ((err = device.close()) != EB_OK) die("device.close", err);
}  

int main() {
  struct sdb_device device;
  status_t err;
  
  device.abi_class = 0x1;
  device.abi_ver_major = 1;
  device.abi_ver_minor = 0;
  device.bus_specific = EB_DATAX; /* Support all access widths */
  
  device.sdb_component.addr_first = 0x4000;
  device.sdb_component.addr_last  = ~(eb_address_t)0;
  device.sdb_component.product.vendor_id = 0x651; /* GSI */
  device.sdb_component.product.device_id = 0xb576c7f1;
  device.sdb_component.product.version = EB_VERSION_SHORT;
  device.sdb_component.product.date = EB_DATE_SHORT;
  device.sdb_component.product.record_type = sdb_record_device;
  
  memcpy(device.sdb_component.product.name, "Software-Memory    ", sizeof(device.sdb_component.product.name));
  
  Socket socket;
  if ((err = socket.open("60368", EB_DATA16|EB_ADDR32)) != EB_OK) die("socket.open", err);
  
  Echo echo;
  if ((err = socket.attach(&device, &echo)) != EB_OK) die("socket.attach", err);
  
  /* for widths */
  test_width(socket, EB_DATAX | EB_ADDRX);
  
  if ((err = socket.close()) != EB_OK) die("socket.close", err);

#ifdef EB_MEMORY_HACK
  printf("\nFinal memory consumption: %d/%d\n", eb_memory_used, eb_memory_array_size);
#endif
  
  return 0;
}
