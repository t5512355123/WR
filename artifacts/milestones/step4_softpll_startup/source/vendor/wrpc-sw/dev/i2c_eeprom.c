/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012-2020 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include "board.h"
#include "dev/bb_i2c.h"
#include "dev/i2c_eeprom.h"

int i2c_eeprom_create( struct i2c_eeprom_device *dev, struct i2c_bus *bus, uint8_t i2c_addr, int offset_bytes )
{
	dev->bus = bus;
	dev->offset_bytes = offset_bytes;
	dev->addr = i2c_addr;
	return 0;
}

int i2c_eeprom_read(struct i2c_eeprom_device *dev, int offset, void *buf, int count)
{
	int i;
	unsigned char *cb = buf;

	bb_i2c_start(dev->bus);
	if (bb_i2c_put_byte(dev->bus, dev->addr << 1) < 0) {
		bb_i2c_stop(dev->bus);
		return -1;
	}

	if(dev->offset_bytes == 2)
		bb_i2c_put_byte(dev->bus, (offset >> 8) & 0xff);
	
	bb_i2c_put_byte(dev->bus, offset & 0xff);
	bb_i2c_repeat_start(dev->bus);
	bb_i2c_put_byte(dev->bus, (dev->addr << 1) | 1);
	for (i = 0; i < count - 1; ++i) {
		bb_i2c_get_byte(dev->bus, cb, 0);
		cb++;
	}
	bb_i2c_get_byte(dev->bus, cb, 1);
	cb++;
	bb_i2c_stop(dev->bus);

	return count;
}

int i2c_eeprom_write(struct i2c_eeprom_device *dev, int offset, void *buf, int count)
{
	int i, busy;
	unsigned char *cb = buf;

	for (i = 0; i < count; i++) {
		bb_i2c_start(dev->bus);

		if (bb_i2c_put_byte(dev->bus, dev->addr << 1) < 0) {
			bb_i2c_stop(dev->bus);
			return -1;
		}

		if(dev->offset_bytes == 2)
			bb_i2c_put_byte(dev->bus, (offset >> 8) & 0xff);

		bb_i2c_put_byte(dev->bus, offset & 0xff);
		bb_i2c_put_byte(dev->bus, *cb++);
		offset++;
		bb_i2c_stop(dev->bus);

		do {		/* wait until the chip becomes ready */
			bb_i2c_start(dev->bus);
			busy = bb_i2c_put_byte(dev->bus, dev->addr << 1);
			bb_i2c_stop(dev->bus);
		} while (busy);

	}
	return count;
}

int i2c_eeprom_erase(struct i2c_eeprom_device *dev, int offset, int count)
{
	int i, busy;

	for (i = 0; i < count; i++) {
		bb_i2c_start(dev->bus);

		if (bb_i2c_put_byte(dev->bus, dev->addr << 1) < 0) {
			bb_i2c_stop(dev->bus);
			return -1;
		}

		if(dev->offset_bytes == 2)
			bb_i2c_put_byte(dev->bus, (offset >> 8) & 0xff);

		bb_i2c_put_byte(dev->bus, offset & 0xff);
		bb_i2c_put_byte(dev->bus, 0xff);
		offset++;
		bb_i2c_stop(dev->bus);

		do {		/* wait until the chip becomes ready */
			bb_i2c_start(dev->bus);
			busy = bb_i2c_put_byte(dev->bus, dev->addr << 1);
			bb_i2c_stop(dev->bus);
		} while (busy);

	}
	return count;
}
