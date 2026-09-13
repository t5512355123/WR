/*
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on ptp-noposix project (see AUTHORS for details)
 *
 * Released to the public domain
 */

#include <ppsi/ppsi.h>
#include <dev/syscon.h>
#include "../arch-wrpc/wrpc.h"
#include <dev/wdiags.h>

#define WR_TMO_NAME "WR_SLOCK"
#define WR_TMO_MS WR_S_LOCK_TIMEOUT_MS

int wr_s_lock(struct pp_instance *ppi, void *buf, int len, int new_state)
{
	struct wr_dsport *wrp = WR_DSPOR(ppi);
	int enable = 0;

	if (new_state) {
		wrp->wrStateRetry = WR_STATE_RETRY;
		pp_timeout_set_rename(ppi, PP_TO_WR_EXT_0, WR_TMO_MS*(WR_STATE_RETRY+1));
		wrpc_wr_s_lock_entry_tics = timer_get_tics();
		wdiags_write_wr_s_lock_debug(1, wrp->wrStateRetry,
			wrpc_wr_s_lock_entry_tics,
			(uint32_t)pp_next_delay_1(ppi, PP_TO_WR_EXT_0),
			WRH_SPLL_UNLOCKED, wrp->state);
		enable = 1;
	} else {

		int poll_ret = WRH_OPER()->locking_poll(ppi);
		if (poll_ret == WRH_SPLL_LOCKED) {
			wrp->next_state = WRS_LOCKED;
			return 0;
		}

		{ /* Check remaining time */
			int rms=pp_next_delay_1(ppi, PP_TO_WR_EXT_0);
			wdiags_write_wr_s_lock_debug(2, wrp->wrStateRetry,
				wrpc_wr_s_lock_entry_tics, (uint32_t)rms,
				poll_ret, wrp->state);
			if ( rms<=(wrp->wrStateRetry*WR_TMO_MS)) {
				WRH_OPER()->locking_disable(ppi);
				if ( rms==0 ) {
					pp_diag(ppi, time, 1, "timeout expired: %s\n", WR_TMO_NAME);
					wdiags_write_wr_s_lock_debug(4, wrp->wrStateRetry,
						wrpc_wr_s_lock_entry_tics, (uint32_t)rms,
						poll_ret, wrp->state);
					wr_handshake_fail_reason(ppi, WR_FAIL_REASON_WR_S_LOCK_TIMEOUT);
					return 0; /* non-wr already */
				}
				if (wr_handshake_retry(ppi)) {
					wdiags_write_wr_s_lock_debug(3, wrp->wrStateRetry,
						wrpc_wr_s_lock_entry_tics, (uint32_t)rms,
						poll_ret, wrp->state);
					enable = 1;
				}
			}
		}
	}

	if (enable) {
		WRH_OPER()->locking_enable(ppi);
	}

	return 0; /* 0ms : If needed we yeld in locking_poll during waiting for the PLL to lock */
}
