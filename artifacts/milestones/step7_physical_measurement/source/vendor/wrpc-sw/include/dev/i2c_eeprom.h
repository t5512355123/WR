/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012-2020 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __I2C_EEPROM_H
#define __I2C_EEPROM_H

#include "board.h"

struct i2c_eeprom_device {
    struct i2c_bus *bus;
    uint8_t addr;
    int offset_bytes;
};


int i2c_eeprom_create( struct i2c_eeprom_device *dev, struct i2c_bus *bus, uint8_t i2c_addr, int offset_bytes );
int i2c_eeprom_read(struct i2c_eeprom_device *dev, int offset, void *buf, int count);
int i2c_eeprom_write(struct i2c_eeprom_device *dev, int offset, void *buf, int count);
int i2c_eeprom_erase(struct i2c_eeprom_device *dev, int offset, int count);

#endif
