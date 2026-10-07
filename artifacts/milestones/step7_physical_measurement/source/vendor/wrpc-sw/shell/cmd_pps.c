/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2021 CERN (www.cern.ch)
 * Author: Adam Wujek
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
/*  Command: pps
    Arguments:
    	force on|off - sets the behaviour of forcing PPS generation
    	<none> - dumps force PPS generation setting

    Description: Enable disable generation of PPS all the time */

#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include "wrc.h"
#include "wrpc.h"

#include "shell.h"
#include "util.h"

static const char * const pps_force_map[] = {
	[pps_force_off] = "off",
	[pps_force_on]  = "on",
};

static int cmd_pps(const char *args[])
{
	if (!strcasecmp(args[0], "force")) {
		if (!strcasecmp(args[1], "on")) {
			wrc_pps_force(pps_force_on);
		} else if (!strcasecmp(args[1], "off")) {
			wrc_pps_force(pps_force_off);
		} else {
			return -1;
		}
	}

	pp_printf("PPS force %s\n", pps_force_map[wrc_pps_force(pps_force_check)]);
	return 0;
}

DEFINE_WRC_COMMAND(pps) = {
	.name = "pps",
	.exec = cmd_pps,
};
