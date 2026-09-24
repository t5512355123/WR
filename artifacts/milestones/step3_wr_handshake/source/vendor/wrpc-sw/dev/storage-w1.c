/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012, 2013 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 * Author: Alessandro Rubini <rubini@gnudd.com>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <errno.h>
#include <wrc.h>
#include <dev/w1.h>
#include <storage.h>

/* The methods for W1 access */

static const int32_t eeprom_default_entry_points[] = {0, 64, 128, 256, 512, 1024, -1 };

static const struct storage_rwops w1_eeprom_rwops = {
	(void *)w1_read_eeprom,
	(void *)w1_write_eeprom,
	(void *)w1_erase_eeprom
};

/* Find the eeprom device on the bus.  */
struct w1_dev *w1_find_eeprom_device(struct w1_bus *bus)
{
	int i;

	/* Find the eeprom device on the bus.  */
	for (i = 0; i < W1_MAX_DEVICES; i++) {
		if (w1_class(bus->devs + i) == 0x43) {
			return bus->devs + 1;
		}
	}
	return NULL;
}

int storage_w1eeprom_create(struct storage_device *dev, struct w1_bus *bus)
{
	struct w1_dev *w1_dev = w1_find_eeprom_device(bus);

	if (w1_dev == NULL) {
		/* not found */
		return -1;
	}

	dev->name = "w1-eeprom";
	dev->priv = w1_dev;
	dev->rwops = &w1_eeprom_rwops;
	dev->size = 8192;
	dev->cfg_entry = 0;
	dev->block_size = 1;
	dev->entry_points = eeprom_default_entry_points;

	return 0;
}
