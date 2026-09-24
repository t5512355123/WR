/*
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include <stdarg.h>
#include <ppsi/ppsi.h>

#ifndef ARRAY_SIZE
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#endif

static const char * const thing_name[] = {
	[pp_dt_fsm]	= "fsm",
	[pp_dt_time]	= "time",
	[pp_dt_frames]	= "frames",
	[pp_dt_servo]	= "servo",
	[pp_dt_bmc]	= "bmc",
	[pp_dt_ext]	= "extension",
	[pp_dt_config]	= "config",
};


void __pp_diag(struct pp_instance *ppi, enum pp_diag_things th,
	       int level, const char *fmt, ...)
{
	va_list args;
	const char *name;

	if (!__PP_DIAG_ALLOW(ppi, th, level))
		return;

	name = ppi ? ppi->port_name : "ppsi";

	/* Use the normal output channel for diagnostics */
	if (PP_DIAG_EXTRA_PRINT_TIME) {
		int hours, minutes, seconds;

		if (ppi && TOPS(ppi) && TOPS(ppi)->get_utc_time )
			TOPS(ppi)->get_utc_time(ppi, &hours, &minutes, &seconds);
		else
			hours=minutes=seconds=0;
		pp_printf("%02d:%02d:%02d ", hours, minutes,seconds);
	}
	pp_printf("diag-%s-%i-%s: ", thing_name[th], level, name);
	va_start(args, fmt);
	pp_vprintf(fmt, args);
	va_end(args);
}

unsigned long pp_diag_parse(const char *diaglevel)
{
	unsigned long res = 0;
	int i = 28; /* number of bits to shift the nibble: 28..31 is first */
	int nthings = ARRAY_SIZE(thing_name);

	while (*diaglevel && i >= (32 - 4 * nthings)) {
		if (*diaglevel < '0' || *diaglevel > '3')
			break;
		res |= ((*diaglevel - '0') << i);
		i -= 4;
		diaglevel++;
	}
	if (*diaglevel)
		pp_printf("%s: error parsing \"%s\"\n", __func__, diaglevel);

	return res;
}
