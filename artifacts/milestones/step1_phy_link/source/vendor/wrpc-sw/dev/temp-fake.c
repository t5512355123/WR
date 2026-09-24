/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2016 GSI (www.gsi.de)
 * Author: Alessandro rubini
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <wrc.h>
#include "dev/temperature.h"
#include "shell.h"
#include "dev/temp-fake.h"


static struct wrc_temp_sensor temp_fake_data[] = {
	{"roof", TEMP_INVALID},
	{"core", TEMP_INVALID},
	{"case", TEMP_INVALID},
	{NULL,}
};

static int temp_fake_refresh(struct wrc_temp_sensor *t)
{
	/* nothing to do */
	return 0;
}

static int cmd_faketemp(const char *args[])
{
	int i;
	const char *dot;

	if (!args[0]) {
		pp_printf("%08x %08x %08x\n",
			  (unsigned int) temp_fake_data[0].t,
			  (unsigned int) temp_fake_data[1].t,
			  (unsigned int) temp_fake_data[2].t);
		return 0;
	}

	for (i = 0; i < 3 && args[i]; i++) {
		int val;

		/* accept at most one decimal */
		dot = fromdec(args[i], &val);
		val <<= 16;
		if (dot[0] == '.' && dot[1] >= '0' && dot[1] <= '9')
			val += 0x10000 / 10 * (dot[1] - '0');
		temp_fake_data[i].t = val;
	}
	return 0;
}

void temp_faketemp_init(void)
{
	struct wrc_temp_group tbr;

	tbr.read = temp_fake_refresh;
	tbr.t = temp_fake_data;
	wrc_temp_register(&tbr);
}

DEFINE_WRC_COMMAND(faketemp) = {
	.name = "faketemp",
	.exec = cmd_faketemp,
};


