/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2020 CERN (www.cern.ch)
 * Author: Greg Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include "board.h"
#include "dev/bb_i2c.h"
#include "dev/i2c_eeprom.h"
#include "dev/syscon.h"
#include "dev/endpoint.h"
#include "dev/24aa025.h"
#include "storage.h"
#include "wrc-debug.h"

static struct i2c_bus i2c_wrc_eeprom;
static struct i2c_eeprom_device wrc_eeprom_dev;
static struct m24aa025_device mac_id_eeprom;

int wrc_board_early_init()
{
	/* EEPROM support */
	bb_i2c_create( &i2c_wrc_eeprom,
		&pin_sysc_fmc_scl,
		&pin_sysc_fmc_sda );
	bb_i2c_init( &i2c_wrc_eeprom );

	i2c_eeprom_create( &wrc_eeprom_dev, &i2c_wrc_eeprom, CFG_EEPROM_ADR, 2);
	storage_i2ceeprom_create( &wrc_storage_dev, &wrc_eeprom_dev);

	/*
	 * Mount SDBFS filesystem from storage.
	 */
	storage_mount( &wrc_storage_dev );

	return 0;
}

int wrc_board_init()
{
	uint8_t mac_addr[6];

	/*
	 * MAC address assignment
	 */
	/* 1. Try reading from 24AA025E48T unique ID chip */
	if (m24aa025_init(&mac_id_eeprom, &i2c_wrc_eeprom, MAC_CHIP_ADR)) {
		board_dbg("Getting MAC address from Unique ID chip\n");
		m24aa025_read_mac(&mac_id_eeprom, mac_addr);

	/* 2. Try reading from configuration EEPROM */
	} else if (storage_get_persistent_mac(0, mac_addr) == -1) {
	/* 3. If everything fails, use default MAC */
		board_dbg("Failed to get MAC address from Unique ID chip or EEPROM. \
				Using fallback address.\n");
		mac_addr[0] = 0x22;
		mac_addr[1] = 0x33;
		mac_addr[2] = 0x44;
		mac_addr[3] = 0x55;
		mac_addr[4] = 0x66;
		mac_addr[5] = 0x77;
	}
	ep_set_mac_addr(&wrc_endpoint_dev, mac_addr);
	ep_pfilter_init_default(&wrc_endpoint_dev);

	return 0;
}

int wrc_board_create_tasks()
{
    return 0;
}
