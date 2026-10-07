/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
/*  Command: time
    Arguments:
    	set UTC NSEC - sets time
    	raw - dumps raw time
    	<none> - dumps pretty time

    Description: (re)starts/stops the PTP session. */

#include "wrc.h"
#include "wrpc.h"

#include "shell.h"
#include "util.h"
#include "dev/pps_gen.h"

static const char * const time_cmds[] =
{
	 [0] = "set",
	 [1] = "setsec",
	 [2] = "setnsec",
	 [3] = "raw",
};

static int cmd_time(const char *args[])
{
	int icmd;
	uint64_t sec;
	uint32_t nsec;

	shw_pps_gen_get_time(&sec, &nsec);

	if (!args[0]) {
		pp_printf("%s +%d nanoseconds.\n",
			  format_time(sec, TIME_FORMAT_LEGACY),
			  (unsigned int) nsec);
		/* fixme: clock freq is not always 125 MHz */
		return 0;
	}

	icmd = sub_cmd(time_cmds, ARRAY_SIZE(time_cmds), args);

	switch(icmd) {
	case 0:
		if (!args[2] || wrc_ptp_get_mode() == WRC_MODE_SLAVE)
			return -1;
		shw_pps_gen_set_time((uint64_t) atoi(args[1]),
				     atoi(args[2]), PPSG_SET_ALL);
		return 0;
	case 1:
		if (!args[1] || wrc_ptp_get_mode() == WRC_MODE_SLAVE)
			return -1;
		shw_pps_gen_set_time((int64_t) atoi(args[1]), 0, PPSG_SET_SEC);
		return 0;
	case 2:
		if (!args[1] || wrc_ptp_get_mode() == WRC_MODE_SLAVE)
			return -1;
		shw_pps_gen_set_time(0, atoi(args[1]), PPSG_SET_NSEC);
		return 0;
	case 3:
		pp_printf("%d %d\n", (unsigned int) sec, (unsigned int) nsec);
		return 0;
	}


	return 0;
}

DEFINE_WRC_COMMAND(time) = {
	.name = "time",
	.exec = cmd_time,
};
