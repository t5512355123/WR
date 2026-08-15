/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Alessandro Rubini <rubini@gnudd.com>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <wrc.h>
#include <shell.h>
#include <storage.h>
#include <dev/endpoint.h>
#include <ppsi/ppsi.h>
#include <ppsi/ppsi.h>

extern struct pp_globals *ppg;

static int cmd_devmem(const char *args[])
{
	uint32_t *addr, value;

	if (!args[0]) {
		pp_printf("devmem: use: \"devmem <address> [<value>]\"\n");
		return 0;
	}
	fromhex(args[0], (void *)&addr);
	if (args[1]) {
		fromhex(args[1], (void *)&value);
		*addr = value;
	} else {
		pp_printf("%08x = %08x\n", (int) addr, (unsigned int) *addr);
	}
	return 0;
}

DEFINE_WRC_COMMAND(devmem) = {
	.name = "devmem",
	.exec = cmd_devmem,
};

static int cmd_delays(const char *args[])
{
	wrh_servo_t * wr_servo;
	wr_servo_ext_t * wr_servo_ext = NULL;

	int tx, rx;

	if (!ppg || !ppg->pp_instances)
		return -1;
	wr_servo = (ppg->pp_instances->protocol_extension == PPSI_EXT_WR
		    && ppg->pp_instances->extState == PP_EXSTATE_ACTIVE) ?
			(wrh_servo_t*) ppg->pp_instances->ext_data : NULL;
	if (!wr_servo) {
		return -2;
	}
	wr_servo_ext = &((struct wr_data *)wr_servo)->servo_ext;

	if (args[0] && !args[1]) {
		pp_printf("delays: use: \"delays [<txdelay> <rxdelay>]\"\n");
		return 0;
	}
	if (args[1]) {
		tx = atoi(args[0]);
		rx = atoi(args[1]);
		/* Overwrite SFP parameters, in case PPSI is restarted */
		sfp_info.sfp_params.dTx = tx;
		sfp_info.sfp_params.dRx = rx;
		/* Change the active value too (add bislide here) */
		picos_to_pp_time(rx, &wr_servo_ext->delta_rxm);
		picos_to_pp_time(tx, &wr_servo_ext->delta_txm);
	} else {
		pp_printf("tx: %i   rx: %i\n", (int) sfp_info.sfp_params.dTx,
			  (int) sfp_info.sfp_params.dRx);
	}
	return 0;
}

DEFINE_WRC_COMMAND(delays) = {
	.name = "delays",
	.exec = cmd_delays,
};
