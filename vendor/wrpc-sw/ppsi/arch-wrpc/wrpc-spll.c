/*
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 *
 * Released to the public domain
 */

#include <stdint.h>
#include <errno.h>
#include <ppsi/ppsi.h>
#include <dev/pps_gen.h>
#include <softpll_ng.h>
#include "../proto-ext-whiterabbit/wr-constants.h"
#include <dev/rxts_calibrator.h>

#include "../include/hw-specific/wrh.h"
#include "wrpc.h"

int wrpc_spll_locking_enable(struct pp_instance *ppi)
{
	if (wrc_ptp_get_mode() == WRC_MODE_GM) {
		/* If in grand master don't change pll mode */
		return WRH_SPLL_OK;
	}
	spll_init(SPLL_MODE_SLAVE, 0, SPLL_FLAG_ALIGN_PPS);
	WRPC_ARCH_I(ppi)->timingMode = WRH_TM_BOUNDARY_CLOCK;
	spll_enable_ptracker(0, 1);
	calib_t24p_init();
	return WRH_SPLL_OK;
}

int wrpc_spll_locking_poll(struct pp_instance *ppi)
{
	int locked;
	static int t24p_calibrated = 0;

	locked = spll_check_lock(0); /* both slave and gm mode */

	/* Else, slave: ensure calibration is done */
	if(!locked) {
		t24p_calibrated = 0;
		return WRH_SPLL_UNLOCKED;
	}
	if(!t24p_calibrated) {
		/*run t24p calibration if needed*/
		if (calib_t24p() < 0) {
			return WRH_SPLL_UNLOCKED;
		}
		t24p_calibrated = 1;
	}

	return WRH_SPLL_LOCKED;
}

int wrpc_spll_check_lock_with_timeout(int lock_timeout)
{
	uint32_t start_tics;
	start_tics = timer_get_tics();

	pp_printf("Locking PLL");

	while (!spll_check_lock(0) && lock_timeout) {
		spll_update();
		timer_delay(TICS_PER_SECOND);
		if (timer_get_tics() - start_tics > lock_timeout) {
			pp_printf("\nLock timeout.");
			return -ETIMEDOUT;
		}
		pp_printf(".");
	}
	pp_printf("\n");
	return 0;
}

int wrpc_spll_locking_reset(struct pp_instance *ppi)
{
	/* if configured as master, but due to BMCA changed into BC */
	if (wrc_ptp_get_mode() == WRC_MODE_MASTER && WRPC_ARCH_I(ppi)->timingMode == WRH_TM_BOUNDARY_CLOCK) {
		spll_init(SPLL_MODE_FREE_RUNNING_MASTER, 0, SPLL_FLAG_ALIGN_PPS);
		WRPC_ARCH_I(ppi)->timingMode = WRH_TM_FREE_MASTER;
		/* wait for spll to lock */
		wrpc_spll_check_lock_with_timeout(LOCK_TIMEOUT_FM);
	}

	return WRH_SPLL_OK;
}


int wrpc_spll_locking_disable(struct pp_instance *ppi)
{
	/* softpll_disable(); */
	return WRH_SPLL_OK;
}

int wrpc_spll_enable_ptracker(struct pp_instance *ppi)
{
	spll_enable_ptracker(0, 1);
	return WRH_SPLL_OK;
}

int wrpc_enable_timing_output(struct pp_globals *ppg, int enable)
{
	static int pps_enable;

	if (enable != 2) {
		pps_enable = enable;
	}
	shw_pps_gen_enable_output(pps_enable | GOPTS(ppg)->forcePpsGen);
	return WRH_SPLL_OK;
}

int wrpc_adjust_in_progress(void)
{
	return shw_pps_gen_busy() || spll_shifter_busy(0);
}

int wrpc_adjust_counters(int64_t adjust_sec, int32_t adjust_nsec)
{
	if (adjust_sec)
		shw_pps_gen_adjust(PPSG_ADJUST_SEC, adjust_sec);
	if (adjust_nsec)
		shw_pps_gen_adjust(PPSG_ADJUST_NSEC, adjust_nsec);
	return 0;
}

int wrpc_adjust_phase(int32_t phase_ps)
{
	spll_set_phase_shift(SPLL_ALL_CHANNELS, phase_ps);
	return WRH_SPLL_OK;
}

int wrpc_get_GM_lock_state(struct pp_globals *ppg, pp_timing_mode_state_t *state)
{
	if (spll_check_lock(0))
	    *state = PP_TIMING_MODE_STATE_LOCKED;
	else
	    *state = PP_TIMING_MODE_STATE_UNLOCKED;

	/* Holdover not implemented (PP_TIMING_MODE_STATE_HOLDOVER) */
	return 0;
}
