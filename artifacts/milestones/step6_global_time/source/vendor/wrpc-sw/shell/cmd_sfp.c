/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
/* Command: sfp
 * Arguments: subcommand [subcommand-specific args]
 *
 * Description: SFP detection/database manipulation.
 * Subcommands:
 * add <product_number> <delta_tx> <delta_rx> <alpha> - adds an SFP to
 *                      the database, with given alpha/delta_rx/delta_tx values
 * show - shows the SFP database
 * params - prints cached calibration state and performs a read-only lookup
 * match - detects the transceiver type and tries to get calibration parameters
 *         from DB for a detected SFP
 * erase - cleans the SFP database
 */

#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <wrc.h>

#include "shell.h"
#include "storage.h"
#include "dev/syscon.h"
#include "dev/endpoint.h"

#include "sfp.h"

#ifdef CONFIG_CMD_SFP_INFO
static void print_info(void)
{
	uint16_t tmp;
	struct shw_sfp_header *sfp_header;

	sfp_header = sfp_info.sfp_header;
	/* to save the code, print only the most important parameters */
	pp_printf("Nominal Bit Rate: %d Mbits/s\n", sfp_header->br_nom * 100);
	pp_printf("Vendor Name: %.16s\n", sfp_header->vendor_name);
	pp_printf("Vendor PN: %.16s\n", sfp_header->vendor_pn);
	pp_printf("Vendor serial: %.16s\n", sfp_header->vendor_serial);
	pp_printf("TX Wavelength: %d\n", (sfp_header->tx_wavelength[0] << 8)
					 + sfp_header->tx_wavelength[1]);

	if (HAS_SFP_DOM) {
		struct shw_sfp_dom *sfp_dom;
		if (!(sfp_header->diagnostic_monitoring_type & SFP_DIAG_IMPLEMENTED)){
			/* no DOM supported */
			pp_printf("No DOM support\n");
			return;
		}

		sfp_dom = sfp_info.sfp_dom;
		tmp = (sfp_dom->temp[0] << 8) + sfp_dom->temp[1];
		pp_printf("Temperature: %d.%02d C\n", tmp/256, ((tmp*100)/256)%100);
		tmp = (sfp_dom->vcc[0] << 8) + sfp_dom->vcc[1];
		pp_printf("Voltage: %d.%04d V\n", tmp/10000, tmp%10000);
		tmp = ((sfp_dom->tx_bias[0] << 8) + sfp_dom->tx_bias[1])/5;
		pp_printf("Bias Current: %d.%02d mA\n", tmp / 100, tmp % 100);
		tmp = ((sfp_dom->tx_pow[0] << 8) + sfp_dom->tx_pow[1]);
		pp_printf("TX power: %d.%04d mW\n", tmp / 10000, tmp % 10000);
		tmp = ((sfp_dom->rx_pow[0] << 8) + sfp_dom->rx_pow[1]);
		pp_printf("RX power: %d.%04d mW\n", tmp / 10000, tmp % 10000);
	}
}
#endif /* CONFIG_CMD_SFP_INFO */

static uint8_t cached_sfp_checksum(const uint8_t *bytes, int first, int checksum)
{
	int i;
	uint16_t sum = 0;

	for (i = first; i < checksum; ++i)
		sum += bytes[i];
	return sum & 0xff;
}

/* This observer only reads the state populated during normal startup. It
 * never calls sfp_match() or changes the active calibration parameters. */
static void print_cached_sfp_params(void)
{
	const uint8_t *header_bytes;
	uint8_t base_sum, ext_sum;
	struct s_sfpinfo lookup;
	int lookup_status;
	const char *lookup_result;

	if (!sfp_info.sfp_header) {
		pp_printf("SFP_PARAMS unavailable=no_cached_header\n");
		return;
	}

	header_bytes = (const uint8_t *)sfp_info.sfp_header;
	base_sum = cached_sfp_checksum(header_bytes, 0, 63);
	ext_sum = cached_sfp_checksum(header_bytes, 64, 95);

	pp_printf("SFP_ACTIVE_CAL db_flag=%d pn=%.16s alpha=%Ld dTx=%d dRx=%d\n",
		  sfp_info.sfp_in_db, sfp_info.sfp_params.pn,
		  sfp_info.sfp_params.alpha, (int)sfp_info.sfp_params.dTx,
		  (int)sfp_info.sfp_params.dRx);
	if (sfp_info.sfp_header->id == SFP_ID_SFF8636_QSFP
	    || sfp_info.sfp_header->id == SFP_ID_SFF8636_QSFP28) {
		pp_printf("QSFP_CACHED_LOWER id=%02x format=SFF-8636 serial_id=upper_page_00\n",
			  sfp_info.sfp_header->id);
		memset(&lookup, 0, sizeof(lookup));
		memcpy(lookup.pn, sfp_info.sfp_params.pn, SFP_PN_LEN);
		lookup_status = storage_match_sfp(&lookup);
		lookup_result = lookup_status > 0 ? "MATCH" :
				lookup_status == 0 ? "NO_MATCH" : "ERROR";
		pp_printf("QSFP_READONLY_DB_LOOKUP result=%s rc=%d pn=%.16s alpha=%Ld dTx=%d dRx=%d\n",
			  lookup_result, lookup_status, lookup.pn, lookup.alpha,
			  (int)lookup.dTx, (int)lookup.dRx);
		return;
	}
	pp_printf("SFP_CACHED_HEADER pn=%.16s base_calc=%02x base_stored=%02x base_valid=%d ext_calc=%02x ext_stored=%02x ext_valid=%d\n",
		  sfp_info.sfp_header->vendor_pn,
		  base_sum, header_bytes[63], base_sum == header_bytes[63],
		  ext_sum, header_bytes[95], ext_sum == header_bytes[95]);

	if (base_sum != header_bytes[63] || ext_sum != header_bytes[95]) {
		pp_printf("SFP_READONLY_DB_LOOKUP skipped=bad_cached_header\n");
		return;
	}

	memset(&lookup, 0, sizeof(lookup));
	memcpy(lookup.pn, sfp_info.sfp_header->vendor_pn, SFP_PN_LEN);
	lookup_status = storage_match_sfp(&lookup);
	lookup_result = lookup_status > 0 ? "MATCH" :
			lookup_status == 0 ? "NO_MATCH" : "ERROR";
	pp_printf("SFP_READONLY_DB_LOOKUP result=%s rc=%d pn=%.16s alpha=%Ld dTx=%d dRx=%d\n",
		  lookup_result, lookup_status, lookup.pn, lookup.alpha,
		  (int)lookup.dTx, (int)lookup.dRx);
}

static void print_raw_bytes(const char *label, const uint8_t *bytes,
			    uint32_t size)
{
	uint32_t i;

	for (i = 0; i < size; i += 16) {
		uint32_t j;
		pp_printf("%s %02x:", label, (unsigned int)i);
		for (j = 0; j < 16 && i + j < size; ++j)
			pp_printf(" %02x", bytes[i + j]);
		pp_printf("\n");
	}
}

/* Explicitly requested live EEPROM read. Data stays in this observer's local
 * buffer; the active cached header and calibration fields are not touched. */
static void print_live_sfp_header(void)
{
	uint8_t lower[sizeof(struct shw_sfp_header)];
	uint8_t upper[SFP_QSFP_SERIAL_ID_SIZE];
	uint8_t page_select = 0xff;
	uint32_t lower_ack = 0, page_ack = 0, upper_ack = 0;
	uint8_t base_sum, ext_sum;
	struct s_sfpinfo lookup;
	int ret, page_ret, upper_ret, lookup_status;
	const char *lookup_result;

	ret = sfp_read_header_diagnostic(lower, &lower_ack);
	pp_printf("SFP_LIVE_READ rc=%d ack_mask=%02x expected=07\n",
		  ret, (unsigned int)lower_ack);
	if (ret)
		return;

	if (lower[0] == SFP_ID_SFF8636_QSFP
	    || lower[0] == SFP_ID_SFF8636_QSFP28) {
		page_ret = sfp_read_eeprom_diagnostic(SFP_QSFP_PAGE_SELECT,
						      &page_select, 1, &page_ack);
		pp_printf("QSFP_LIVE_PAGE_SELECT rc=%d value=%02x ack_mask=%02x expected=07\n",
			  page_ret, page_select, (unsigned int)page_ack);
		if (page_ret || page_select != 0) {
			print_raw_bytes("QSFP_LIVE_LOWER_RAW", lower, sizeof(lower));
			return;
		}

		upper_ret = sfp_read_eeprom_diagnostic(SFP_QSFP_SERIAL_ID_START,
						       upper,
						       SFP_QSFP_SERIAL_ID_SIZE,
						       &upper_ack);
		pp_printf("QSFP_LIVE_SERIAL_READ rc=%d ack_mask=%02x expected=07\n",
			  upper_ret, (unsigned int)upper_ack);
		if (upper_ret) {
			print_raw_bytes("QSFP_LIVE_LOWER_RAW", lower, sizeof(lower));
			return;
		}

		base_sum = cached_sfp_checksum(upper, 0, 63);
		ext_sum = cached_sfp_checksum(upper, 64, 95);
		pp_printf("QSFP_LIVE_SERIAL id_lower=%02x id_upper=%02x pn=%.16s base_calc=%02x base_stored=%02x base_valid=%d ext_calc=%02x ext_stored=%02x ext_valid=%d\n",
			  lower[0], upper[0], &upper[SFP_QSFP_VENDOR_PN_OFFSET],
			  base_sum, upper[63],
			  upper[0] == lower[0] && base_sum == upper[63],
			  ext_sum, upper[95], ext_sum == upper[95]);
		if (upper[0] == lower[0] && base_sum == upper[63]
		    && ext_sum == upper[95]) {
			memset(&lookup, 0, sizeof(lookup));
			memcpy(lookup.pn, &upper[SFP_QSFP_VENDOR_PN_OFFSET],
			       SFP_PN_LEN);
			lookup_status = storage_match_sfp(&lookup);
			lookup_result = lookup_status > 0 ? "MATCH" :
					lookup_status == 0 ? "NO_MATCH" : "ERROR";
			pp_printf("QSFP_LIVE_DB_LOOKUP result=%s rc=%d pn=%.16s alpha=%Ld dTx=%d dRx=%d\n",
				  lookup_result, lookup_status, lookup.pn,
				  lookup.alpha, (int)lookup.dTx, (int)lookup.dRx);
		} else {
			pp_printf("QSFP_LIVE_DB_LOOKUP skipped=invalid_serial_id\n");
		}
		print_raw_bytes("QSFP_LIVE_LOWER_RAW", lower, sizeof(lower));
		print_raw_bytes("QSFP_LIVE_SERIAL_RAW", upper, sizeof(upper));
	} else {
		struct shw_sfp_header *live_header =
			(struct shw_sfp_header *)lower;
		base_sum = cached_sfp_checksum(lower, 0, 63);
		ext_sum = cached_sfp_checksum(lower, 64, 95);
		pp_printf("SFP_LIVE_HEADER id=%02x pn=%.16s base_calc=%02x base_stored=%02x base_valid=%d ext_calc=%02x ext_stored=%02x ext_valid=%d cached_equal=%d\n",
			  live_header->id, live_header->vendor_pn,
			  base_sum, lower[63], base_sum == lower[63],
			  ext_sum, lower[95], ext_sum == lower[95],
			  memcmp(lower, sfp_info.sfp_header, sizeof(lower)) == 0);
		print_raw_bytes("SFP_LIVE_RAW", lower, sizeof(lower));
	}
}

static const char * const sfp_cmds[] =
{
	 [0] = "erase",
	 [1] = "add",
	 [2] = "show",
	 [3] = "match",
	 [4] = "ena",
	 [5] = "params",
#ifdef CONFIG_CMD_SFP_INFO
	 [6] = "info",
#endif
};

static int cmd_sfp(const char *args[])
{
	int icmd;

	icmd = sub_cmd(sfp_cmds, ARRAY_SIZE(sfp_cmds), args);

	switch (icmd) {
	case 0:
		if (storage_sfpdb_erase() == EE_RET_I2CERR) {
			pp_printf("Could not erase DB\n");
			return -EIO;
		}
		return 0;
	case 1:
	{
		unsigned temp, i;
		struct s_sfpinfo sfp;

		if (!args[5])
			return -1;
		temp = strnlen(args[1], SFP_PN_LEN);
		for (i = 0; i < temp; ++i)
			sfp.pn[i] = args[1][i];
		while (i < SFP_PN_LEN)
			sfp.pn[i++] = ' ';	//padding
		sfp.dTx = atoi(args[2]);
		sfp.dRx = atoi(args[3]);
		sfp.alpha = atoi(args[4]);
		sfp.alpha = sfp.alpha * 1000000000;
		/* first value defines a sign */
		sfp.alpha += (sfp.alpha < 0?-1:1) * atoi(args[5]);
		temp = storage_get_sfp(&sfp, SFP_ADD, 0);
		if (temp == EE_RET_DBFULL) {
			pp_printf("SFP DB is full\n");
			return -ENOSPC;
		} else if (temp == EE_RET_I2CERR) {
			pp_printf("I2C error\n");
			return -EIO;
		} else if (temp < 0) {
			pp_printf("SFP database error (%d)\n", temp);
			return -EFAULT;
		}
		pp_printf("%d SFPs in DB\n", temp);
		return 0;
	}
	case 2:
	{
		unsigned i, temp;
		struct s_sfpinfo sfp;
		int sfpcount = 1;

		for (i = 0; i < sfpcount; ++i) {
			sfpcount = storage_get_sfp(&sfp, SFP_GET, i);
			if (sfpcount == 0) {
				pp_printf("SFP database empty\n");
				return 0;
			} else if (sfpcount < 0) {
				pp_printf("SFP database error (%d)\n",
					  sfpcount);
				return -EFAULT;
			}
			pp_printf("%d: PN:", i + 1);
			for (temp = 0; temp < SFP_PN_LEN; ++temp)
				pp_printf("%c", sfp.pn[temp]);
			pp_printf(" dTx: %8d dRx: %8d alpha: %19Ld\n",
				  (int) sfp.dTx, (int) sfp.dRx, sfp.alpha);
		}
		return 0;
	}
	case 3:
	{
		int ret;

		if (args[1] && !strcmp(args[1], "force")) {
			ret = sfp_match(1);
		} else {
			ret = sfp_match(0);
		}
		if (ret == -ENODEV) {
			pp_printf("No SFP.\n");
			return ret;
		}
		if (ret == -EIO) {
			pp_printf("SFP read error\n");
			return ret;
		}

		/* SFP read correctly */
		pp_printf("%.16s\n", sfp_info.sfp_params.pn);

		if (ret == -ENXIO) {
			pp_printf("Could not match to DB\n");
			return ret;
		}
		/* match successful */
		pp_printf("SFP matched, dTx=%d dRx=%d alpha=%Ld\n",
			  (int) sfp_info.sfp_params.dTx,
			  (int) sfp_info.sfp_params.dRx,
			  sfp_info.sfp_params.alpha);
		return ret;
	}
	case 4:
		if (!args[1])
			return -1;
		ep_sfp_enable(&wrc_endpoint_dev, atoi(args[1]));
		return 0;
	case 5:
		print_cached_sfp_params();
		if (args[1] && !strcmp(args[1], "live"))
			print_live_sfp_header();
		return 0;
#ifdef CONFIG_CMD_SFP_INFO
	case 6:
		/* DOM data is updated periodically by a task */
		print_info();
		return 0;
#endif
	default:
		return -1;
	}
}

DEFINE_WRC_COMMAND(sfp) = {
	.name = "sfp",
	.exec = cmd_sfp,
};
