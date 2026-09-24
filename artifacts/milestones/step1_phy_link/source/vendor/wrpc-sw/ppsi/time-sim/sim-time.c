/*
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Pietro Fezzardi (pietrofezzardi@gmail.com)
 *
 * Released to the public domain
 */

/*
 * Time operations for the simulator, design to be used both for
 * master and the slave instance.
 */

#include <time.h>
#include <errno.h>
#include <ppsi/ppsi.h>
#include "../arch-sim/ppsi-sim.h"

int sim_fast_forward_ns(struct pp_globals *ppg, int64_t ff_ns)
{
	struct pp_sim_time_instance *t_inst;
	int i;
	int64_t tmp;

	for (i = 0; i < ppg->nlinks; i++) {
		t_inst = &SIM_PPI_ARCH(INST(ppg, i))->time;
		tmp = ff_ns + t_inst->freq_ppb_real * ff_ns / 1000 / 1000 / 1000;
		t_inst->current_ns += tmp + (t_inst->freq_ppb_servo) *
						tmp / 1000 / 1000 / 1000;
	}
	pp_diag(0, ext, 2, "%s: %lli ns\n", __func__, (long long)ff_ns);

	struct sim_pending_pkt *pkt;
	struct sim_ppg_arch_data *data = SIM_PPG_ARCH(ppg);
	if (data->n_pending) {
		for (i = 0; i < data->n_pending; i++) {
			pkt = &data->pending[i];
			pkt->delay_ns -= ff_ns;
			if (pkt->delay_ns < 0) {
				pp_error("pkt->delay_ns = %lli\n",
						(long long)pkt->delay_ns);
				exit(1);
			}
		}
	}

	return 0;
}

static int sim_time_get_utc_time(struct pp_instance *ppi, int *hours, int *minutes, int *seconds)
{
	/* no UTC time */
	*hours = 0;
	*minutes = 0;
	*seconds = 0;
	return -1;
}

static int sim_time_get_utc_offset(struct pp_instance *ppi, int *offset, int *leap59, int *leap61)
{
	/* no UTC offset */
	*leap59 = 0;
	*leap61 = 0;
	*offset = 0;
	return -1;
}

static int sim_time_set_utc_offset(struct pp_instance *ppi, int offset, int leap59, int leap61)
{
	/* no UTC offset */
	return -1;
}

#if 0
static int sim_time_get_servo_state(struct pp_instance *ppi, int *state)
{
	*state = PP_SERVO_UNKNOWN;
	return 0;
}
#endif

static int sim_time_get(struct pp_instance *ppi, struct pp_time *t)
{
	t->scaled_nsecs = (SIM_PPI_ARCH(ppi)->time.current_ns %
			   (long long)PP_NSEC_PER_SEC) << 16;
	t->secs = SIM_PPI_ARCH(ppi)->time.current_ns /
		(long long)PP_NSEC_PER_SEC;

	if (!(pp_global_d_flags & PP_FLAG_NOTIMELOG))
		pp_diag(ppi, time, 2, "%s: %9li.%09li\n", __func__,
			(long)t->secs, (long)(t->scaled_nsecs >> 16));
	return 0;
}

static int sim_time_set(struct pp_instance *ppi, const struct pp_time *t)
{
	if (!t) {
		/* Change the network notion of utc/tai offset */
		return 0;
	}

	SIM_PPI_ARCH(ppi)->time.current_ns = (t->scaled_nsecs >> 16)
				+ t->secs * (long long)PP_NSEC_PER_SEC;

	pp_diag(ppi, time, 1, "%s: %9i.%09i\n", __func__,
		(int)t->secs, (int)(t->scaled_nsecs >> 16));
	return 0;
}

static int sim_time_adjust(struct pp_instance *ppi, long offset_ns,
				long freq_ppb)
{
	if (freq_ppb) {
		if (freq_ppb > PP_ADJ_FREQ_MAX)
			freq_ppb = PP_ADJ_FREQ_MAX;
		if (freq_ppb < -PP_ADJ_FREQ_MAX)
			freq_ppb = -PP_ADJ_FREQ_MAX;
		SIM_PPI_ARCH(ppi)->time.freq_ppb_servo = freq_ppb;
	}

	if (offset_ns)
		SIM_PPI_ARCH(ppi)->time.current_ns += offset_ns;

	pp_diag(ppi, time, 1, "%s: %li %li\n", __func__, offset_ns, freq_ppb);
	return 0;
}

static int sim_adjust_freq(struct pp_instance *ppi, long freq_ppb)
{
	return sim_time_adjust(ppi, 0, freq_ppb);
}

static int sim_adjust_offset(struct pp_instance *ppi, long offset_ns)
{
	return sim_time_adjust(ppi, offset_ns, 0);
}

static inline int sim_init_servo(struct pp_instance *ppi)
{
	return SIM_PPI_ARCH(ppi)->time.freq_ppb_real;
}

static unsigned long sim_calc_timeout(struct pp_instance *ppi, int millisec)
{
	return millisec + SIM_PPI_ARCH(ppi)->time.current_ns / 1000LL / 1000LL;
}

static int sim_get_GM_lock_state(struct pp_globals *ppg,
				  pp_timing_mode_state_t *state)
{
	*state = PP_TIMING_MODE_STATE_LOCKED;
	return 0;

}

static int sim_enable_timing_output(struct pp_globals *ppg, int enable)
{
	static int prev_enable = 0;

	if (prev_enable != enable) {
		pp_diag(NULL, time, 2, "%s dummy timing output\n",
			enable ? "enable" : "disable");
		prev_enable = enable;

		return 0;
	}

	return 0;
}

const struct pp_time_operations sim_time_ops = {
	.get_utc_time = sim_time_get_utc_time,
	.get_utc_offset = sim_time_get_utc_offset,
	.set_utc_offset = sim_time_set_utc_offset,
	//	.get_servo_state = sim_time_get_servo_state,
	.get = sim_time_get,
	.set = sim_time_set,
	.adjust = sim_time_adjust,
	.adjust_offset = sim_adjust_offset,
	.adjust_freq = sim_adjust_freq,
	.init_servo = sim_init_servo,
	.calc_timeout = sim_calc_timeout,
	.get_GM_lock_state = sim_get_GM_lock_state,
	.enable_timing_output = sim_enable_timing_output
};
