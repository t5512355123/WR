/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


#include <stdint.h>
#include "ppsi/ppsi.h"

#include "wrc-debug.h"
#include "dev/syscon.h"
#include "dev/gpio.h"
#include "dev/bb_spi.h"
#include "dev/ad951x.h"
#include "dev/ltc695x.h"
#include "dev/ad9910.h"
#include "dev/clock_monitor.h"
#include "dev/24aa025.h"
#include "dev/ad7888.h"
#include "dev/spi_flash.h"
#include "dev/bb_i2c.h"
#include "dev/pps_gen.h"
#include "dev/console.h"
#include "dev/endpoint.h"
#include "dev/netif.h"
#include "dev/24aa025.h"

#include "softpll_ng.h"
#include "dev/minic.h"

#include "storage.h"
#include "wrpc.h"
#include "wrc-event.h"
#include "wrc-task.h"

static struct i2c_bus i2c_mac_bus[2];
static struct m24aa025_device i2c_mac_dev[2];

spll_gain_schedule_t spll_main_ocxo_gain_sched;

static void wr2rf_spll_setup(void)
{
/* configure a suitable PI gain schedule for the SoftPLL: */
    spll_gain_schedule_t* gs=  &spll_main_ocxo_gain_sched;

    gs->n_stages = 1;

/* we start with ~100 Hz bandwidth to make it lock reasonably fast */
    gs->stages[0].kp = -4000 * 16;
    gs->stages[0].ki = -5 * 16;
    gs->stages[0].lock_samples = 30000;
    gs->stages[0].shift = 16 - BOARD_SPLL_DIV_BITS;

/* once it's locked, the loop bandwidth is switched to ~0.1 Hz to filter out WR link added phase noise */
    gs->stages[1].kp = -3000;
    gs->stages[1].ki = -5;
    gs->stages[1].lock_samples = 10000;
    gs->stages[1].shift = 16 - BOARD_SPLL_DIV_BITS;

    spll_set_gain_schedule( gs );
    spll_set_pi_gain( SPLL_LOOP_HELPER, 0,
		      -150, -2, PI_FRACBITS - BOARD_SPLL_DIV_BITS );

    // Aux clock 0 is used for 'factory' calibration of CLKAB/LO/REF outputs.
    spll_set_aux_mode( 0, SPLL_AUX_MODE_PHASE_MONITOR );
}

/* Check if calibration values correspond to the bitstream.
   If not, remove them. */

static void wr2rf_check_hw_change(void)
{
    uint32_t hw_date, cal_date;

    storage_load_calibration();

    hw_date = sysc_get_hwbuild_date();
    if (hw_date == 0) {
	pp_printf("invalid hwbuild date! calibration status unknown\n");
	return;
    }

    /* Check if up to date. */
    if (storage_get_calibration_parameter(CAL_PARAM_CALIBRATION_DATE,
					  &cal_date) == 0
	&& cal_date == hw_date)
	return;

    storage_remove_calibration_parameter(CAL_PARAM_T24P);
    storage_remove_calibration_parameter(CAL_PARAM_PHY_TARGET_TX_PHASE);
    storage_set_calibration_parameter(CAL_PARAM_CALIBRATION_DATE, hw_date);
}


int wrc_board_early_init(void)
{
    int32_t flash_entry_points[64];
    uint8_t board_mac_addr[6];
    int i;

    /* initialize SPI flash */
    bb_spi_create( &spi_wrc_flash,
		&pin_sysc_spi_ncs,
		&pin_sysc_spi_mosi,
		&pin_sysc_spi_miso,
		&pin_sysc_spi_sclk, 0 );

    spi_flash_create( &wrc_flash_dev, &spi_wrc_flash, 16384, 0x600000 );

    bb_i2c_create( &i2c_mac_bus[0], &pin_sysc_fmc_scl, &pin_sysc_fmc_sda );
    bb_i2c_init( &i2c_mac_bus[0] );

    m24aa025_init( &i2c_mac_dev[0], &i2c_mac_bus[0], 0x50 );

    uint8_t *mac = board_mac_addr;
    m24aa025_read_mac( &i2c_mac_dev[0], mac );

    board_dbg("MAC address: Port 0 = %02x:%02x:%02x:%02x:%02x:%02x\n",
        mac[0],mac[1],mac[2],mac[3],mac[4],mac[5] );

    for(i = 0; i < 32 + 8; i++)
        flash_entry_points[i] = 0x600000 + 0x40000 * i;

    flash_entry_points[i] = -1;

    /* init storage (we use the SPI flash on eRTM14) */
    storage_spiflash_create( &wrc_storage_dev, &wrc_flash_dev );
    wrc_storage_dev.entry_points = &flash_entry_points[0];

    storage_mount( &wrc_storage_dev );

    wr2rf_check_hw_change();

    /* reset the networking part of the WRCore and start the WR Endpoint */
    net_rst();

    ep_init(&wrc_endpoint_dev, (void *) BASE_EP);
    ep_set_mac_addr( &wrc_endpoint_dev, board_mac_addr );
    netif_register_device(&wrc_endpoint_dev, &minic);

    /* Sleep for 1s to make sure WRS v4.2 always realizes that
     * the link is down */
    timer_delay_ms(200);
    ep_enable( &wrc_endpoint_dev, 1, 1);
    timer_delay_ms(200);

    wr2rf_spll_setup();

    return 0;
}

extern int phy_calibration_poll(void);
extern void phy_calibration_init(void);

int wrc_board_init()
{
    wrc_task_create( "phy-cal", phy_calibration_init, phy_calibration_poll );

    return 0;
}


int wrc_board_create_tasks()
{
    return 0;
}
