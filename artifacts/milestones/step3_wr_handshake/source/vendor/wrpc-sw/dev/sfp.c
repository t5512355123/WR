/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012-2021 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 * Author: Adam Wujek
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
/* SFP Detection / managenent functions */

#include <inttypes.h>
#include <string.h>
#include <errno.h>

#include "wrc-task.h"
#include "pp-printf.h"
#include "dev/syscon.h"
#include "dev/bb_i2c.h"
#include "dev/gpio.h"
#include "sfp.h"
#include "storage.h"

static struct shw_sfp_header sfp_header;
/* sfp_dom is static, so it is not included if CONFIG_SFP_DOM is not selected */
static struct shw_sfp_dom sfp_dom;

struct sfp_info sfp_info = {
	.sfp_header = &sfp_header,
#ifdef CONFIG_SFP_DOM
	.sfp_dom = &sfp_dom,
#endif
	.version = WRC_G_SFP_VERSION,
	.sfp_params = {
		.alpha = 0, /* default value for alpha */
	},
};

static int sfp_present(void)
{
	return !gen_gpio_in(&pin_sysc_sfp1_det);
}

static void sfp_read_i2c(int addr, uint8_t *mem, int start, int size)
{
	const struct i2c_bus *dev = &dev_i2c_sfp1;
	int i = start;
	uint8_t data;

	bb_i2c_init(dev);

	bb_i2c_start(dev);
	bb_i2c_put_byte(dev, addr << 1);
	bb_i2c_put_byte(dev, start);
	bb_i2c_repeat_start(dev);
	bb_i2c_put_byte(dev, addr << 1 | BB_I2C_WRITE);
	bb_i2c_get_byte(dev, &data, 1);
	bb_i2c_stop(dev);
	*(mem + i) = data;

	bb_i2c_start(dev);
	bb_i2c_put_byte(dev, addr << 1 | BB_I2C_WRITE);
	for (i++; i < start + size - 1; ++i) {
		bb_i2c_get_byte(dev, &data, 0);
		*(mem + i) = data;
	}
	bb_i2c_get_byte(dev, &data, 1);	//final word, checksum
	*(mem + i) = data;
	bb_i2c_stop(dev);
}

static int verify_checksum(uint8_t *mem, int from, int to)
{
	int i;
	uint16_t sum = 0;

	for (i = from; i < to; i++) {
		sum += *(mem + i);
	}
	sum = sum & 0xff;

	if (sum == *(mem + to))
		return 0;
	return 1;
}

int sfp_dom_update(void)
{
	static uint32_t sfp_dom_last_update_tick;

	if (wrc_task_not_yet(&sfp_dom_last_update_tick,
			     SFP_DOM_UPDATE_TICK_INTERVAL)) {
		return 0;
	}

	if (!(sfp_header.diagnostic_monitoring_type & SFP_DIAG_IMPLEMENTED)) {
		return 0;
	}

	/* Read Real Time Diagnostics (DOM) data, bytes 96-111 */
	sfp_read_i2c(I2C_SFP_DOM_ADDRESS, (uint8_t *)&sfp_dom, 96, 10);

	return 1;
}

int sfp_match(int force)
{
	if (!force && !sfp_present()) {
		return -ENODEV;
	}

	/* Read sfp header info from SFP */
	sfp_read_i2c(I2C_SFP_ADDRESS, (uint8_t *)&sfp_header, 0,
		     sizeof(struct shw_sfp_header));

	if (verify_checksum((uint8_t *)&sfp_header, 0, 63)
	    || verify_checksum((uint8_t *)&sfp_header, 64, 95)) {
		/* Print error */
		pp_printf("Wrong SFP checksum %s\n", "");
		return -EIO;
	}

	if (HAS_SFP_DOM
	    && sfp_header.diagnostic_monitoring_type & SFP_DIAG_IMPLEMENTED) {
		/* Read sfp DOM info from SFP only if DOM supported */
		sfp_read_i2c(I2C_SFP_DOM_ADDRESS, (uint8_t *)&sfp_dom, 0,
			     sizeof(struct shw_sfp_dom));
		if (verify_checksum((uint8_t *)&sfp_dom, 0, 95)) {
			pp_printf("Wrong SFP checksum %s\n", "DOM");
		}
	}

	memcpy(sfp_info.sfp_params.pn, sfp_info.sfp_header->vendor_pn,
	       SFP_PN_LEN);
	if (storage_match_sfp(&sfp_info.sfp_params) == 0) {
		sfp_info.sfp_in_db = SFP_NOT_MATCHED;
		return -ENXIO;
	}

	sfp_info.sfp_in_db = SFP_MATCHED;
	return 0;
}
