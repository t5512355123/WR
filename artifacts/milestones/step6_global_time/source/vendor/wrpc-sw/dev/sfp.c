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

static int sfp_read_i2c_checked(int addr, int start, uint8_t *buffer,
				int size, uint32_t *ack_mask)
{
	const struct i2c_bus *dev = &dev_i2c_sfp1;
	uint32_t ack = 0;
	unsigned int i;
	int ret = -EIO;

	if (!buffer || size <= 0 || start < 0 || start + size > 256)
		return -EINVAL;

	/* One random-read transaction. Check all three host-written bytes before
	 * accepting data, and keep the EEPROM/page contents read-only. */
	bb_i2c_init(dev);
	bb_i2c_start(dev);
	if (bb_i2c_put_byte(dev, addr << 1) < 0)
		goto out;
	ack |= 1u << 0;
	if (bb_i2c_put_byte(dev, start) < 0)
		goto out;
	ack |= 1u << 1;
	bb_i2c_repeat_start(dev);
	if (bb_i2c_put_byte(dev, (addr << 1) | BB_I2C_WRITE) < 0)
		goto out;
	ack |= 1u << 2;

	for (i = 0; i < (unsigned int)size; ++i)
		bb_i2c_get_byte(dev, &buffer[i], i == (unsigned int)size - 1);
	ret = 0;

out:
	bb_i2c_stop(dev);
	if (ack_mask)
		*ack_mask = ack;
	return ret;
}

int sfp_read_eeprom_diagnostic(uint8_t start, uint8_t *buffer,
			       uint32_t size, uint32_t *ack_mask)
{
	if (!buffer || !ack_mask || !size || size > 256u - start)
		return -EINVAL;
	*ack_mask = 0;
	if (!sfp_present())
		return -ENODEV;
	return sfp_read_i2c_checked(I2C_SFP_ADDRESS, start, buffer,
				    (int)size, ack_mask);
}

int sfp_read_header_diagnostic(uint8_t *header, uint32_t *ack_mask)
{
	return sfp_read_eeprom_diagnostic(0, header,
					  sizeof(struct shw_sfp_header), ack_mask);
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
	struct s_sfpinfo matched;
	uint8_t qsfp_page_select;
	uint8_t qsfp_serial_id[SFP_QSFP_SERIAL_ID_SIZE];
	int ret;
	int match_result;

	if (!force && !sfp_present()) {
		return -ENODEV;
	}

	ret = sfp_read_i2c_checked(I2C_SFP_ADDRESS, 0,
				   (uint8_t *)&sfp_header, sizeof(sfp_header), NULL);
	if (ret < 0) {
		pp_printf("SFP/QSFP EEPROM read failed (%d)\n", ret);
		return ret;
	}

	memset(&matched, 0, sizeof(matched));
	if (sfp_header.id == SFP_ID_SFF8472) {
		if (verify_checksum((uint8_t *)&sfp_header, 0, 63)
		    || verify_checksum((uint8_t *)&sfp_header, 64, 95)) {
			pp_printf("Wrong SFP checksum\n");
			return -EIO;
		}
		memcpy(matched.pn, sfp_header.vendor_pn, SFP_PN_LEN);
	} else if (sfp_header.id == SFP_ID_SFF8636_QSFP
		   || sfp_header.id == SFP_ID_SFF8636_QSFP28) {
		/* SFF-8636 serial identification is in Upper Page 00h, bytes
		 * 128-223. Never change the module's page-select register here:
		 * use the page only when it is already set to 00h. */
		ret = sfp_read_i2c_checked(I2C_SFP_ADDRESS,
					   SFP_QSFP_PAGE_SELECT,
					   &qsfp_page_select, 1, NULL);
		if (ret < 0 || qsfp_page_select != 0) {
			pp_printf("QSFP page select unavailable (rc=%d page=%02x)\n",
				  ret, ret < 0 ? 0xff : qsfp_page_select);
			return ret < 0 ? ret : -EAGAIN;
		}
		ret = sfp_read_i2c_checked(I2C_SFP_ADDRESS,
					   SFP_QSFP_SERIAL_ID_START,
					   qsfp_serial_id,
					   SFP_QSFP_SERIAL_ID_SIZE, NULL);
		if (ret < 0 || qsfp_serial_id[0] != sfp_header.id
		    || verify_checksum(qsfp_serial_id, 0, 63)
		    || verify_checksum(qsfp_serial_id, 64, 95)) {
			pp_printf("Wrong QSFP SFF-8636 serial-ID checksum/read\n");
			return ret < 0 ? ret : -EIO;
		}
		/* Page 00h bytes 168-183 are the 16-byte vendor part number. */
		memcpy(matched.pn,
		       &qsfp_serial_id[SFP_QSFP_VENDOR_PN_OFFSET], SFP_PN_LEN);
	} else {
		pp_printf("Unsupported transceiver identifier %02x\n", sfp_header.id);
		return -ENOTSUP;
	}

	match_result = storage_match_sfp(&matched);
	if (match_result <= 0) {
		sfp_info.sfp_in_db = SFP_NOT_MATCHED;
		memcpy(sfp_info.sfp_params.pn, matched.pn, SFP_PN_LEN);
		return match_result < 0 ? -EIO : -ENXIO;
	}

	sfp_info.sfp_params = matched;
	sfp_info.sfp_in_db = SFP_MATCHED;

	if (sfp_header.id == SFP_ID_SFF8472 && HAS_SFP_DOM
	    && sfp_header.diagnostic_monitoring_type & SFP_DIAG_IMPLEMENTED) {
		/* DOM reads are only defined by the current implementation for SFP. */
		sfp_read_i2c(I2C_SFP_DOM_ADDRESS, (uint8_t *)&sfp_dom, 0,
			     sizeof(struct shw_sfp_dom));
		if (verify_checksum((uint8_t *)&sfp_dom, 0, 95))
			pp_printf("Wrong SFP checksum DOM\n");
	}
	return 0;
}
