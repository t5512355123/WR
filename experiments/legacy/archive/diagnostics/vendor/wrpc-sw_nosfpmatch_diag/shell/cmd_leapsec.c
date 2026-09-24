/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2021 CERN (www.cern.ch)
 * Author: Adam Wujek
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
/*  Command: leapsec
    Arguments:
    	set SEC - sets leap seconds value
    	<none> - dumps leap seconds value

    Description: set/read leap seconds value used by PTP */

#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include "wrc.h"
#include "wrpc.h"

#include "shell.h"
#include "util.h"

/* Setting leap second makes sense only for GM. For other modes leap seconds
 * counter is received from a master (slave) or is hardcoded in PPSI (master).
 * In master it is hardcoded to PP_DEFAULT_UTC_OFFSET, since master mode does
 * not have timescale set. */
static int cmd_leapsec(const char *args[])
{
	int ptp_offset, system_offset;

	if (args[1] && !strcasecmp(args[0], "set")) {
		wrc_ptp_set_leapsec(atoi(args[1]));
	} else if (args[0] && strcasecmp(args[0], "get")) {
		/* other param given, but not "get" */
		return -EINVAL;
	}

	wrc_ptp_get_leapsec(&ptp_offset, &system_offset);
	pp_printf("leap seconds: ptp %d, system %d\n", ptp_offset, system_offset);

	return 0;
}

DEFINE_WRC_COMMAND(leapsec) = {
	.name = "leapsec",
	.exec = cmd_leapsec,
};
