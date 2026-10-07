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
#include "wrc.h"
#include "dev/w1.h"
#include "storage.h"

#include "dev/spi_flash.h"

static const int32_t spi_flash_default_entry_points[] =
{
				0x000000,	/* flash base */
				0x100,		/* second page in flash */
				0x200,		/* IPMI with MultiRecord */
				0x300,		/* IPMI with larger MultiRecord */
				0x170000,	/* after first FPGA bitstream */
				0x2e0000,	/* after MultiBoot bitstream */
				0x600000,	/* after SVEC AFPGA bitstream */
				-1 };

static const struct storage_rwops spi_flash_rwops = {
	(void *)spi_flash_read,
	(void *)spi_flash_write,
	(void *)spi_flash_erase
};

void storage_spiflash_create(struct storage_device *dev, struct spi_flash_device *flash)
{
	dev->name = "spi-flash";
	dev->priv = flash;
	dev->rwops = &spi_flash_rwops;
	dev->size = flash->size;
	dev->cfg_entry = flash->cfg_entry;
	dev->block_size = flash->sector_size;
	dev->entry_points = spi_flash_default_entry_points;
}
