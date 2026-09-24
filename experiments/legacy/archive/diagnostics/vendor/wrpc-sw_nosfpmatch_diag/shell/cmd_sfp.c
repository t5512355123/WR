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

static const char * const sfp_cmds[] =
{
	 [0] = "erase",
	 [1] = "add",
	 [2] = "show",
	 [3] = "match",
	 [4] = "ena",
#ifdef CONFIG_CMD_SFP_INFO
	 [5] = "info",
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
#ifdef CONFIG_CMD_SFP_INFO
	case 5:
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
