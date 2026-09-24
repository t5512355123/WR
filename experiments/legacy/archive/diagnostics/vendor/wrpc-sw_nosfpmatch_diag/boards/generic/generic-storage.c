#include "board.h"
#include "wrc-debug.h"
#include "dev/bb_spi.h"
#include "dev/bb_i2c.h"
#include "dev/w1.h"
#include "dev/spi_flash.h"
#include "dev/i2c_eeprom.h"
#include "dev/syscon.h"
#include "storage.h"

static struct i2c_bus i2c_wrc_eeprom;
static struct i2c_eeprom_device wrc_eeprom_dev;

int wrc_generic_board_storage_init(void)
{
	int memtype;
	uint32_t sdbfs_entry;
	uint32_t sector_size;

	if (HAS_W1_EEPROM
	    && storage_w1eeprom_create(&wrc_storage_dev, &wrpc_w1_bus) == 0) {
		/* Found.  */
	}
	else if (EEPROM_STORAGE) {
		/* EEPROM support */
		bb_i2c_create(&i2c_wrc_eeprom,
			      &pin_sysc_fmc_scl,
			      &pin_sysc_fmc_sda);
		bb_i2c_init(&i2c_wrc_eeprom);

		i2c_eeprom_create(&wrc_eeprom_dev, &i2c_wrc_eeprom, FMC_EEPROM_ADR, 2);
		storage_i2ceeprom_create( &wrc_storage_dev, &wrc_eeprom_dev );
	} else {
		/* Flash support */
		/*
		 * declare GPIO pins and configure their directions for bit-banging SPI
		 * limit SPI speed to 10MHz by setting bit_delay = CPU_CLOCK / 10^6
		 */
		bb_spi_create( &spi_wrc_flash,
			&pin_sysc_spi_ncs,
			&pin_sysc_spi_mosi,
			&pin_sysc_spi_miso,
			&pin_sysc_spi_sclk, CPU_CLOCK / 10000000 );

		spi_wrc_flash.rd_falling_edge = 1;

		/*
		 * Read from gateware info about used memory. Currently only base
		 * address and sector size for memtype flash is supported.
		 */
		get_storage_info(&memtype, &sdbfs_entry, &sector_size);

		/*
		 * Initialize SPI flash and read its ID
		 */
		spi_flash_create( &wrc_flash_dev, &spi_wrc_flash, sector_size, sdbfs_entry);

		/*
		 * Initialize storage subsystem with newly created SPI Flash
		 */
		storage_spiflash_create( &wrc_storage_dev, &wrc_flash_dev );
	}

	/*
	 * Mount SDBFS filesystem from storage.
	 */
	storage_mount( &wrc_storage_dev );

	return 0;
}
