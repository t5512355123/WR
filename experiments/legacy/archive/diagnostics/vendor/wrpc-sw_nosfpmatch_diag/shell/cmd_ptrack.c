/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include <string.h>
#include <wrc.h>
#include <softpll_ng.h>
#include "shell.h"
#ifdef CONFIG_WRPC_PPSI
#  include <ppsi/ppsi.h>
#  include "proto-ext-whiterabbit/wr-api.h"
#else
#  include "ptpd.h"
#endif

static const char * const ptrack_cmds[] =
{
	"unfreeze",
	"ps-freeze",
	"vco-freeze",
	"channel",
	"stat",
};


static int cmd_ptrack(const char *args[])
{
	int icmd = sub_cmd(ptrack_cmds, ARRAY_SIZE(ptrack_cmds), args);

	switch (icmd) {
	case 0:
		pp_printf("UnFreezing SPLL phase shifter\n");
		spll_vco_freeze(0);
		spll_pshifter_freeze(0);
		break;
	case 1:
		if (args[1]) {
			int ps = atoi(args[1]);
			pp_printf("Freezing SPLL phase shifter at phase %d ps\n", ps);
			spll_set_phase_shift(0, ps);
			spll_pshifter_freeze(1);
		}
		else {
			pp_printf("Freezing SPLL phase shifter");
			spll_pshifter_freeze(1);
		}
		break;
	case 2:
		pp_printf("Freezing SPLL VCO control");
		spll_vco_freeze(1);
		break;
	case 3:
		if (args[1]) {
			int ch = atoi(args[1]);
			pp_printf("enable ptracker %d\n", ch);
			spll_enable_ptracker(ch, 1);
		}
		else
			return -1;
		break;
	case 4:
		ptracker_show_stats();
		break;
	}
	return 0;
}

DEFINE_WRC_COMMAND(ptrack) = {
	.name = "ptrack",
	.exec = cmd_ptrack,
};
