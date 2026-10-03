/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <wrc.h>

#include "softpll_ng.h"
#include "shell.h"
#include "dev/rxts_calibrator.h"
#include "rxts-diag.h"
#include "wrh-fixed-diag.h"
#include "wr-ts-diag.h"
#include "phase-history.h"

#define CMD_INIT 0
#define CMD_CL 1
#define CMD_STAT 2
#define CMD_SPS 3
#define CMD_GPS 4
#define CMD_START 5
#define CMD_STOP 6
#define CMD_SDAC 7
#define CMD_GDAC 8
#define CMD_GAIN 9
#define CMD_RXTS 10
#define CMD_FIXED 11
#define CMD_TS4 12
#define CMD_PHIST 13



/* The sub-commands.  */
static const char * const pll_menu[] =
{
	[CMD_INIT] = "init",
	[CMD_CL] = "cl",
	[CMD_STAT] = "stat",
	[CMD_SPS] = "sps",
	[CMD_GPS] = "gps",
	[CMD_START] = "start",
	[CMD_STOP] = "stop",
	[CMD_SDAC] = "sdac",
	[CMD_GDAC] = "gdac",
	[CMD_GAIN] = "gain",
	[CMD_RXTS] = "rxts",
	[CMD_FIXED] = "fixed",
	[CMD_TS4] = "ts4",
	[CMD_PHIST] = "phist"
};

/* Number of arguments for the sub-commands.  Mind the order!  */
static const unsigned char nargs[] =
{
	[CMD_INIT] = 3,
	[CMD_CL] = 1,
	[CMD_STAT] = 0,
	[CMD_SPS] = 2,
	[CMD_GPS] = 1,
	[CMD_START] = 1,
	[CMD_STOP] = 1,
	[CMD_SDAC] = 2,
	[CMD_GDAC] = 1,
	[CMD_GAIN] = 5,
	[CMD_RXTS] = 1,
	[CMD_FIXED] = 0,
	[CMD_TS4] = 1,
	[CMD_PHIST] = 1
};

static int cmd_pll(const char *args[])
{
	unsigned narg;
	int vals[8];
	int icmd;

	icmd = sub_cmd(pll_menu, ARRAY_SIZE(pll_menu), args);

	/* Decode arguments.  */
	for (narg = 1; args[narg]; narg++)
		vals[narg] = atoi(args[narg]);

	/* Args from 1 to NARG.  */
	narg--;

	if (icmd < 0 || nargs[icmd] != narg)
		return -EINVAL;

	switch (icmd) {
	case CMD_PHIST:
		return wr_phase_history_show_page((unsigned)vals[1]);
	case CMD_TS4:
		return wr_ts_diag_show_page((unsigned)vals[1]);
	case CMD_FIXED:
	{
		struct wrh_fixed_diag d;
		int32_t current, target;
		/* Main-loop RAM copy before console output; no control writes. */
		wrh_fixed_diag_get(&d);
		spll_get_phase_shift(0, &current, &target);
		pp_printf("FIXED_V1 enabled=%u latched=%u entry=%u writes=%u "
			  "inits=%u revoked=%u setp=%d spll_init=%u "
			  "current=%d target=%d\n", d.enabled, d.latched,
			  d.entry_update, d.phase_writes, d.servo_inits,
			  d.revoked, (int)d.frozen_setpoint,
			  wrpc_spll_init_count, (int)current, (int)target);
		return 0;
	}
	case CMD_RXTS:
		return rxts_diag_show_page((unsigned)vals[1]);
	case CMD_INIT:
		wrpc_spll_note_init_reason(WRPC_SPLL_INIT_REASON_SHELL_CMD_PLL,
					vals[1], vals[3]);
		spll_init(vals[1], vals[2], vals[3]);
		return 0;
	case CMD_CL:
		pp_printf("%d\n", spll_check_lock(vals[1]));
		return 0;
	case CMD_STAT:
		spll_show_stats();
		calib_t24p_show_state();
		return 0;
	case CMD_SPS:
		spll_set_phase_shift(vals[1], vals[2]);
		return 0;
	case CMD_GPS:
	{
		int32_t cur, tgt;
		spll_get_phase_shift(vals[1], &cur, &tgt);
		pp_printf("%d %d\n", (int) cur, (int) tgt);
		return 0;
	}
	case CMD_START:
		spll_start_channel(vals[1]);
		return 0;
	case CMD_STOP:
		spll_stop_channel(vals[1]);
		return 0;
	case CMD_SDAC:
		spll_set_dac(vals[1], vals[2]);
		return 0;
	case CMD_GDAC:
		pp_printf("%d\n", spll_get_dac(vals[1]));
		return 0;
	case CMD_GAIN:
	{
		spll_set_pi_gain( vals[1], vals[2], vals[3], vals[4], vals[5] );
		return 0;
	}
	default:
		return 0;
	}
}

DEFINE_WRC_COMMAND(pll) = {
	.name = "pll",
	.exec = cmd_pll,
};
