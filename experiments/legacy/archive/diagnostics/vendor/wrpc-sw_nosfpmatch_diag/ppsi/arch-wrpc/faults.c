/*
 * Copyright (C) 2017 GSI (www.gsi.de)
 * Author: Alessandro Rubini
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <ppsi/ppsi.h>
#include "wrpc.h"
#include <errno.h>
#include "shell.h"
#include "syscon.h"

extern struct pp_instance ppi_static;
extern int frame_rx_delay_us;
extern struct pp_time faulty_stamps[6];

static int cmd_fault(const char *args[])
{
	struct pp_globals *ppg = ppi_static.glbs;

	if (args[0] && !strcmp(args[0], "drop")) {
		if (args[1])
			ppg->rxdrop = atoi(args[1]);
		if (args[2])
			ppg->txdrop = atoi(args[2]);
		ppsi_drop_init(ppg, timer_get_tics());
		pp_printf("dropping %i/1000 rx,  %i/1000 tx\n",
			  ppg->rxdrop, ppg->txdrop);
		return 0;
	}
	if (args[0] && !strcmp(args[0], "delay")) {
		if (args[1])
			frame_rx_delay_us = atoi(args[1]);
		pp_printf("delaying %i us on rx frame\n", frame_rx_delay_us);
		return 0;
	}
	if (args[0] && !strcmp(args[0], "stamp")) {
		int i;
		int64_t v;
		struct pp_time *t;

		/* input is hex, output is decimal (ps) */
		pp_printf("timestamp offset:");
		for (i = 0; i < 6; i++) {
			t = faulty_stamps + i;
			if (args[i + 1]) {
				fromhex64(args[i + 1], &v);
				t->scaled_nsecs = v;
			}
			pp_printf("   %i ps",
				  (int)((t->scaled_nsecs * 1000) >> 16));
		}
		pp_printf("\n");
		return 0;
	}

	pp_printf("Use: \"fault drop [<rxdrop> <txdrop>]\" (0..999)\n");
	pp_printf("     \"fault delay [<usecs>]\"\n");
	pp_printf("     \"fault stamp [<hex-offset> ...]\"\n");
	return -EINVAL;
}

DEFINE_WRC_COMMAND(fault) = {
        .name = "fault",
        .exec = cmd_fault,
};

