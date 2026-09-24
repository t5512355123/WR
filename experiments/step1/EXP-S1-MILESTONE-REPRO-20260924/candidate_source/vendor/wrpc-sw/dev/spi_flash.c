/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Theodor Stana <t.stana@cern.ch>
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include "wrc-debug.h"
#include "dev/bb_spi.h"
#include "dev/spi_flash.h"

static uint8_t spi_flash_rsr(struct spi_flash_device *dev);

/*
 * Init function (just set the SPI pins for idle)
 */
void spi_flash_create(struct spi_flash_device *dev, struct spi_bus *bus, uint32_t sector_size, uint32_t cfg_entry)
{
	int i;

	dev->bus = bus;
	dev->sector_size = sector_size;
	dev->cfg_entry = cfg_entry;
	dev->use_4byte_addr = 0;

	for(i=0;i < 10; i++)
		(void) spi_flash_rsr( dev ); // make sure SPI bus is in known state

	uint32_t id = spi_flash_read_id( dev );



	// hack: detect a 512 Mbit flash. probably we need a lookup table.
	if( (id & 0xff) == 0x20 )
	{
		dev->sector_size = 0x10000;
		dev->use_4byte_addr = 1;
		dev->size = 0x100000 * 64;
	} else {
		dev->size = 1 << (( id >> 0 ) & 0xff);
	}

	dev_dbg("spi_flash: device ID = 0x%08x, size=%d bytes\n", id, dev->size);
}

static void spi_flash_write_addr(struct spi_flash_device *dev, uint32_t addr)
{
	if( dev->use_4byte_addr )
	{
		bb_spi_write(dev->bus, (addr & 0xFF000000) >> 24, 8);
		bb_spi_write(dev->bus, (addr & 0xFF0000) >> 16, 8);
		bb_spi_write(dev->bus, (addr & 0xFF00) >> 8, 8);
		bb_spi_write(dev->bus, (addr & 0xFF), 8);
	} else {
		bb_spi_write(dev->bus, (addr & 0xFF0000) >> 16, 8);
		bb_spi_write(dev->bus, (addr & 0xFF00) >> 8, 8);
		bb_spi_write(dev->bus, (addr & 0xFF), 8);
	}
}

/*
 * Write data to flash chip
 */
int spi_flash_write(struct spi_flash_device *dev, uint32_t addr, uint8_t *buf, int count)
{
	int i;

	bb_spi_cs( dev->bus, 1 );
	bb_spi_write( dev->bus, 0x06, 8 ); // write enable
	bb_spi_cs( dev->bus, 0 );

	bb_spi_delay(dev->bus);

	bb_spi_cs( dev->bus, 1 );
	bb_spi_write( dev->bus, dev->use_4byte_addr ? 0x12 : 0x02, 8 );
	spi_flash_write_addr( dev, addr );
	for (i = 0; i < count; i++) {
		bb_spi_write(dev->bus, buf[i], 8);
	}
	bb_spi_cs( dev->bus, 0 );

	/* make sure the write is complete */
	while (spi_flash_rsr(dev) & 0x01) {
		/* do nothing */
	}

	return count;
}

/*
 * Read data from flash
 */
int spi_flash_read(struct spi_flash_device *dev, uint32_t addr, uint8_t *buf, int count)
{
	int i;

	bb_spi_cs( dev->bus, 1 );

	bb_spi_write( dev->bus, dev->use_4byte_addr ? 0x0c : 0x0b, 8 );
	spi_flash_write_addr( dev, addr );
	bb_spi_write( dev->bus, 0, 8 );

	for (i = 0; i < count; i++) {
		buf[i] = bb_spi_read(dev->bus, 8);
	}
	bb_spi_cs( dev->bus, 0 );

	return count;
}


/*
 * Sector erase
 */
void spi_flash_erase_sector(struct spi_flash_device *dev, uint32_t addr)
{
	bb_spi_cs( dev->bus, 1 );
	bb_spi_write(dev->bus, 0x06, 8); // write enable
	bb_spi_cs( dev->bus, 0 );

 	bb_spi_cs( dev->bus, 1 );
	bb_spi_write( dev->bus, dev->use_4byte_addr ? 0xdc : 0xd8, 8 );
	spi_flash_write_addr( dev, addr );
	bb_spi_cs( dev->bus, 0 );

	uint32_t rsr;

	while (( rsr = spi_flash_rsr(dev) ) & 0x01)
			;

}

int spi_flash_erase(struct spi_flash_device *dev, uint32_t addr, int count)
{
	int i;
	int sectors = (count + dev->sector_size - 1) / dev->sector_size;

	for (i = 0; i < sectors; ++i) {
		spi_flash_erase_sector(dev, addr + i*dev->sector_size);
		while (spi_flash_rsr(dev) & 0x01)
			;
	}

	return count;
}

/*
 * Read status register
 */
static uint8_t spi_flash_rsr(struct spi_flash_device *dev)
{
	uint8_t retval;

	bb_spi_cs( dev->bus, 1 );
	bb_spi_write( dev->bus, 0x05, 8);
	retval = bb_spi_read(dev->bus, 8);
	bb_spi_cs( dev->bus, 0 );

	return retval;
}


uint32_t spi_flash_read_id(struct spi_flash_device *dev)
{
	uint32_t val = 0;

	/* make sure the flash is in known state (idle) */
	bb_spi_cs(dev->bus, 1);
	bb_spi_delay(dev->bus);

	bb_spi_cs(dev->bus, 0);
	bb_spi_delay(dev->bus);

	bb_spi_cs(dev->bus, 1);
	bb_spi_write(dev->bus, 0x9f, 8);
	val = (bb_spi_read(dev->bus, 8) << 16);
	val += (bb_spi_read(dev->bus, 8) << 8);
	val += bb_spi_read(dev->bus, 8);
	bb_spi_cs(dev->bus, 0);

	return val;
}

