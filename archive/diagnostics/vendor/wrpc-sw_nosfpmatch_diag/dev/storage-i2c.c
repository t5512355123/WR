/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012, 2013 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 * Author: Alessandro Rubini <rubini@gnudd.com>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include "wrc.h"
#include "storage.h"

#include "dev/bb_i2c.h"
#include "dev/i2c_eeprom.h"

static const int32_t i2c_eeprom_default_entry_points[] = {0, 64, 128, 256, 512, 1024, -1 };


/* Functions for I2C EEPROM access */
static const struct storage_rwops i2c_eeprom_rwops = {
	(void *)i2c_eeprom_read,
	(void *)i2c_eeprom_write,
	(void *)i2c_eeprom_erase
};

void storage_i2ceeprom_create(struct storage_device *dev, struct i2c_eeprom_device *eeprom)
{
	dev->name = "i2c-eeprom";
	dev->priv = eeprom;
	dev->rwops = &i2c_eeprom_rwops;
	dev->size = 8192;
	dev->cfg_entry = 0;
	dev->block_size = 32;
	dev->entry_points = i2c_eeprom_default_entry_points;
}
