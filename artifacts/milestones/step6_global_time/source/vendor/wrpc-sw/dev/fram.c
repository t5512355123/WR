/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2018 CERN (www.cern.ch)
 * Author: Maciej Lipinski
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include <wrc.h>
#include <dev/fram.h>
#include <storage.h>
#include <dev/flash.h>
#include <dev/bb_spi.h>
#include <dev/syscon.h>

#include <libsdbfs.h>

struct fram_device wrc_fram_dev;

/*
 * Init function (just set the SPI pins for idle)
 */
void fram_init(struct fram_device *dev, struct spi_bus *bus)
{
	dev->bus = bus;
}

/*
 * Write data to flash chip
 */
int fram_write(struct fram_device *dev, uint32_t addr, uint8_t *buf, int count)
{
	int i;

	bb_spi_cs(dev->bus, 1);
	bb_spi_write(dev->bus, 0x06, 8);                // WREN (set write enable latch)
	bb_spi_cs(dev->bus, 0);

	bb_spi_cs(dev->bus, 1);
	bb_spi_write(dev->bus, 0x02, 8);                // optcode for writing
	bb_spi_write(dev->bus, (addr & 0xFF00) >> 8, 8);// write address MSB
	bb_spi_write(dev->bus, (addr & 0xFF), 8);       // write address LSB
	for (i = 0; i < count; i++) {
		bb_spi_write(dev->bus, buf[i], 8);
	}
	bb_spi_cs(dev->bus, 0);

	return count;
}

/*
 * Read data from flash
 */
int fram_read(struct fram_device *dev, uint32_t addr, uint8_t *buf, int count)
{
	int i;

	bb_spi_cs(dev->bus, 1);
	bb_spi_write(dev->bus, 0x03, 8);                 // optcode for reading
	bb_spi_write(dev->bus, (addr & 0xFF00) >> 8, 8);
	bb_spi_write(dev->bus, (addr & 0xFF), 8);
	for (i = 0; i < count; i++) {
		buf[i] = bb_spi_read(dev->bus, 8);
	}
	bb_spi_cs(dev->bus, 0);

	return count;
}

int fram_erase(struct fram_device *dev, uint32_t addr, int count)
{
	int i;
	uint8_t buf[1] = {0xff};

	for (i = 0; i < count; i++)
		fram_write(dev, addr+i, buf , 1);
	return count;
}


/*****************************************************************************/
/*			SDB						     */
/*****************************************************************************/

/* The sdb filesystem itself */
static struct sdbfs wrc_sdb = {
	.name = "wrpc-storage",
	.blocksize = 0, /* Not currently used */
	/* .read and .write according to device type */
};

/*
 * SDB read and write functions
 */
static int sdb_fram_read(struct sdbfs *fs, int offset, void *buf, int count)
{
	return fram_read(&wrc_fram_dev, offset, buf, count);
}

static int sdb_fram_write(struct sdbfs *fs, int offset, void *buf, int count)
{
	return fram_write(&wrc_fram_dev, offset, buf, count);
}

/*
 * A trivial dumper, just to show what's up in there
 */
static void fram_sdb_list(struct sdbfs *fs)
{
	struct sdb_device *d;
	int new = 1;

	while ((d = sdbfs_scan(fs, new)) != NULL) {
		d->sdb_component.product.record_type = '\0';
		pp_printf("file 0x%08x @ %4i, name %19s\n",
			  (int)(d->sdb_component.product.device_id),
			  (int)(d->sdb_component.addr_first),
			  (char *)(d->sdb_component.product.name));
		new = 0;
	}
}

/*
 * Check for SDB presence on fram
 */
int fram_sdb_check(void)
{
	uint32_t magic = 0;
	int i;

	uint32_t entry_point[] = {
			0x000000,	/* fram base */
			0x6000		/* for VXS*/
        };

	for (i = 0; i < ARRAY_SIZE(entry_point); i++) {
		fram_read(&wrc_fram_dev, entry_point[i], (uint8_t *)&magic, 4);
		if (magic == SDB_MAGIC)
			break;
	}
	if (i == ARRAY_SIZE(entry_point))
		return -1;

	pp_printf("Found SDB magic at address 0x%06x\n", entry_point[i]);
	wrc_sdb.drvdata = NULL;
	wrc_sdb.entrypoint = entry_point[i];
	wrc_sdb.read = sdb_fram_read;
	wrc_sdb.write = sdb_fram_write;
	fram_sdb_list(&wrc_sdb);
	return 0;
}
