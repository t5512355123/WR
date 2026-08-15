/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012 - 2015 CERN (www.cern.ch)
 * Author: Alessandro Rubini <rubini@gnudd.com>
 * Author: Adam Wujek <adam.wujek@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include "softpll_ng.h"
#include "revision.h"

/*
 * On the switch, we export softpll internal status to the ARM cpu, for SNMP.
 * Thus, we place this structure at a known address in the linker script
 */
#ifdef CONFIG_TARGET_WR_SWITCH
#define STATS_SECTION(NAME) __attribute__((section(NAME)))
#else
#define STATS_SECTION(NAME)
#endif

#ifdef CONFIG_TARGET_WR_SWITCH
struct spll_stats stats STATS_SECTION(".stats") = {
	.magic = 0x5b1157a7,
	.ver = SPLL_STATS_VER
};
#endif

const struct spll_build_id build_id STATS_SECTION(".build_id") = {
#ifdef CONFIG_DETERMINISTIC_BINARY
	.build_date = "",
	.build_time = "",
	.build_by = "",
#else
	.build_date = __DATE__,
	.build_date[sizeof(build_id.build_date) - 1] = 0,
	.build_time = __TIME__,
	.build_time[sizeof(build_id.build_time) - 1] = 0,
	.build_by = __GIT_USR__,
	.build_by[sizeof(build_id.build_by) - 1] = 0,
#endif
	.commit_id = __GIT_VER__,
	.commit_id[sizeof(build_id.commit_id) - 1] = 0,
};
