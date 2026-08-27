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
#include "dev/wdiags.h"

int wrpc_spll_locking_enable(struct pp_instance *ppi)
{
	wrpc_wr_lock_enable_count++;
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

	wrpc_wr_lock_poll_count++;
	locked = spll_check_lock(0); /* both slave and gm mode */

	/* Else, slave: ensure calibration is done */
	if(!locked) {
		t24p_calibrated = 0;
		wrpc_wr_lock_unlocked_count++;
		wrpc_wr_lock_last_result = 1;
		return WRH_SPLL_UNLOCKED;
	}
	if(!t24p_calibrated) {
		/*run t24p calibration if needed*/
		if (calib_t24p() < 0) {
			wrpc_wr_lock_calibration_fail_count++;
			wrpc_wr_lock_last_result = 2;
			return WRH_SPLL_UNLOCKED;
		}
		t24p_calibrated = 1;
	}

	wrpc_wr_lock_last_result = 0;
	return WRH_SPLL_LOCKED;
}

int wrpc_spll_check_lock_with_timeout(int lock_timeout)
{
	uint32_t start_tics;
	uint32_t current_tics = 0;
	uint32_t iteration_count = 0;
	int last_lock_result = 0;

	start_tics = timer_get_tics();
	current_tics = start_tics;
	wdiags_write_lock_wait_debug(
		WRC_DIAGS_LOCK_WAIT_SUBSTAGE_ENTERED,
		iteration_count, start_tics, current_tics, last_lock_result);

	pp_printf("Locking PLL");

	while (1) {
		/* Preserve the original short-circuit behavior: with a zero timeout,
		 * do not call spll_check_lock(). */
		if (!lock_timeout)
			break;

		last_lock_result = spll_check_lock(0);
		wdiags_write_lock_wait_debug(
			WRC_DIAGS_LOCK_WAIT_SUBSTAGE_AFTER_LOCK_CHECK,
			iteration_count, start_tics, current_tics, last_lock_result);
		if (last_lock_result)
			break;

		iteration_count++;
		wdiags_write_lock_wait_debug(
			WRC_DIAGS_LOCK_WAIT_SUBSTAGE_BEFORE_SPLL_UPDATE,
			iteration_count, start_tics, current_tics, last_lock_result);
		spll_update();
		wdiags_write_lock_wait_debug(
			WRC_DIAGS_LOCK_WAIT_SUBSTAGE_AFTER_SPLL_UPDATE,
			iteration_count, start_tics, current_tics, last_lock_result);

		wdiags_write_lock_wait_debug(
			WRC_DIAGS_LOCK_WAIT_SUBSTAGE_BEFORE_TIMER_DELAY,
			iteration_count, start_tics, current_tics, last_lock_result);
		timer_delay(TICS_PER_SECOND);
		wdiags_write_lock_wait_debug(
			WRC_DIAGS_LOCK_WAIT_SUBSTAGE_AFTER_TIMER_DELAY,
			iteration_count, start_tics, current_tics, last_lock_result);

		current_tics = timer_get_tics();
		wdiags_write_lock_wait_debug(
			WRC_DIAGS_LOCK_WAIT_SUBSTAGE_AFTER_TIMEOUT_CHECK,
			iteration_count, start_tics, current_tics, last_lock_result);
		if (current_tics - start_tics > lock_timeout) {
			pp_printf("\nLock timeout.");
			wdiags_write_lock_wait_debug(
				WRC_DIAGS_LOCK_WAIT_SUBSTAGE_RETURN,
				iteration_count, start_tics, current_tics, last_lock_result);
			return -ETIMEDOUT;
		}
		pp_printf(".");
	}
	pp_printf("\n");
	wdiags_write_lock_wait_debug(
		WRC_DIAGS_LOCK_WAIT_SUBSTAGE_RETURN,
		iteration_count, start_tics, current_tics, last_lock_result);
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
