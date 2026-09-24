/*
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 * (Mostly code by Tomasz Wlostowski in wrpc-sw)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include <ppsi/ppsi.h>
#include "dev/pps_gen.h" /* in wrpc-sw */
#include "dev/syscon.h" /* in wrpc-sw */
#include "../arch-wrpc/wrpc.h"

static int utcOffset = CONFIG_LEAP_SECONDS_VAL;

static int wrpc_time_get_utc_time(struct pp_instance *ppi, int *hours, int *minutes, int *seconds)
{
	/* no UTC time */
	*hours = 0;
	*minutes = 0;
	*seconds = 0;
	return -1;
}

static int wrpc_time_get_utc_offset(struct pp_instance *ppi, int *offset, int *leap59, int *leap61)
{
	*leap59 = 0;
	*leap61 = 0;
	*offset = utcOffset;
	return 0;
}

static int wrpc_time_set_utc_offset(struct pp_instance *ppi, int offset, int leap59, int leap61) 
{
	utcOffset = offset;
	return 0;
}

static int wrpc_time_get(struct pp_instance *ppi, struct pp_time *t)
{
	uint64_t sec;
	uint32_t nsec;

	shw_pps_gen_get_time(&sec, &nsec);

	t->secs = sec;
	t->scaled_nsecs = (int64_t)nsec << 16;
	if (!(pp_global_d_flags & PP_FLAG_NOTIMELOG))
		pp_diag(ppi, time, 2, "%s: %9lu.%09li\n", __func__,
			(long)sec, (long)nsec);
	return 0;
}

static int wrpc_time_set(struct pp_instance *ppi, const struct pp_time *t)
{
	uint64_t sec;
	unsigned long nsec;

	if (!t) /* tai offset changed. We don't have it in wrpc-sw */
		return 0;

	sec = t->secs;
	nsec = t->scaled_nsecs >> 16;

	shw_pps_gen_set_time(sec, nsec, PPSG_SET_ALL);
	pp_diag(ppi, time, 1, "%s: %9lu.%09li\n", __func__,
		(long)sec, (long)nsec);
	return 0;
}

static int wrpc_time_adjust_offset(struct pp_instance *ppi, long offset_ns)
{
	pp_diag(ppi, time, 1, "%s: %li\n",
		__func__, offset_ns);
	if (offset_ns)
		shw_pps_gen_adjust(PPSG_ADJUST_NSEC, offset_ns);
	return 0;
}

static int wrpc_time_adjust(struct pp_instance *ppi, long offset_ns,
			    long freq_ppb)
{
	if (freq_ppb != 0)
		pp_diag(ppi, time, 1, "Warning: %s: can not adjust freq_ppb %li\n",
				__func__, freq_ppb);
	return wrpc_time_adjust_offset(ppi, offset_ns);
}

static unsigned long wrpc_calc_timeout(struct pp_instance *ppi, int millisec)
{
	return timer_get_tics() + millisec;
}

const struct pp_time_operations wrpc_time_ops = {
	.get_utc_time = wrpc_time_get_utc_time,
	.get_utc_offset = wrpc_time_get_utc_offset,
	.set_utc_offset = wrpc_time_set_utc_offset,
	.get = wrpc_time_get,
	.set = wrpc_time_set,
	.adjust = wrpc_time_adjust,
	.adjust_offset = wrpc_time_adjust_offset,
	.adjust_freq = NULL,
	.calc_timeout = wrpc_calc_timeout,
	.get_GM_lock_state = wrpc_get_GM_lock_state,
	.enable_timing_output = wrpc_enable_timing_output,
};
