/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Theodor Stana <t.stana@cern.ch>
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include "wrc.h"
#include "dev/flash.h"
#include "storage.h"

#include <libsdbfs.h>

#include "dev/syscon.h"
#include "dev/bb_spi.h"
#include "dev/spi_flash.h"

struct spi_bus spi_wrc_flash;
struct spi_flash_device wrc_flash_dev;

void flash_init(void)
{
	bb_spi_create( &spi_wrc_flash,
		&pin_sysc_spi_ncs,
		&pin_sysc_spi_mosi,
		&pin_sysc_spi_miso,
		&pin_sysc_spi_sclk, 10 );

	spi_flash_create( &wrc_flash_dev, &spi_wrc_flash, 16384, 0 );
}
