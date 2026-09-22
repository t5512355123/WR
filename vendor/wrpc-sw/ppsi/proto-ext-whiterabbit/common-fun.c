/*
 * Copyright (C) 2014 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include <ppsi/ppsi.h>
#include "../arch-wrpc/wrpc.h"
#include "dev/syscon.h"
#include <dev/wdiags.h>

void wr_reset_process(struct pp_instance *ppi, wr_role_t role) {
	struct wr_dsport *wrp = WR_DSPOR(ppi);

	wrp->wrStateTimeout = WR_DEFAULT_STATE_TIMEOUT_MS;
	wrp->calPeriod = WR_DEFAULT_CAL_PERIOD;
	wrp->wrMode = role;
	wrp->wrModeOn=FALSE;
	wrp->calibrated = !WR_DEFAULT_PHY_CALIBRATION_REQUIRED;
	if ( role != WR_SLAVE ) {
		/* Reset parent data */
		/* For a SLAVE, these info are updated when an Announce message is received */
		wrp->parentWrConfig = NON_WR;
		wrp->parentIsWRnode =
				wrp->parentWrModeOn =
						wrp->parentCalibrated = FALSE;
	}
}

/*
 * A Slave can transiently miss the hardware WR lock even though the WR
 * parent is still present and the rest of the PTP session is healthy.  The
 * historical terminal-fallback path below was correct for a real handshake
 * failure, but it also discarded the parent context for this recoverable
 * S_LOCK timeout.  That left the board in ordinary PTP mode until an
 * explicit "ptp stop/start" command was issued, which also prevented the
 * WR global-time generator from becoming valid again.
 *
 * Re-enter the normal state-machine restart path only for that narrow case.
 * This preserves the existing terminal fallback for every other failure and
 * does not touch the SoftPLL control path.
 */
static int wr_auto_rearm_slave_after_s_lock_timeout(struct pp_instance *ppi,
		uint8_t reason)
{
	struct wr_dsport *wrp = WR_DSPOR(ppi);

	if (reason != WR_FAIL_REASON_WR_S_LOCK_TIMEOUT ||
		ppi->state != PPS_SLAVE ||
		wrp->wrMode != WR_SLAVE ||
		!wrp->parentIsWRnode ||
		!(wrp->parentWrConfig == WR_MASTER ||
			wrp->parentWrConfig == WR_M_AND_S))
		return 0;

	pp_diag(ppi, ext, 1,
		"Recoverable WR S_LOCK timeout: re-arm Slave WR handshake\n");

	/* Keep the parent context and use the same transition as a servo restart. */
	wrp->next_state = WRS_IDLE;
	wr_reset_process(ppi, WR_SLAVE);
	wr_servo_reset(ppi);
	ppi->next_state = PPS_UNCALIBRATED;
	pdstate_enable_extension(ppi);
	return 1;
}

/* The handshake failed: go master or slave in normal PTP mode */
void wr_handshake_fail_reason(struct pp_instance *ppi, uint8_t reason)
{
	struct wr_dsport *wrp = WR_DSPOR(ppi);

	wrpc_wr_handshake_fail_count++;
	wrpc_wr_last_fail_state = (uint8_t)wrp->state;
	wrpc_wr_last_fail_role = (uint8_t)wrp->wrMode;
	wrpc_wr_last_fail_reason = reason;
	wrpc_wr_last_fail_tics = timer_get_tics();

	if (wr_auto_rearm_slave_after_s_lock_timeout(ppi, reason))
		return;

	pp_diag(ppi, ext, 1, "Handshake failure: now non-wr %s\n",
		wrp->wrMode == WR_MASTER ? "master" : "slave");
	wdiags_write_wr_extension_disable_debug(
		WDIAGS_WR_DISABLE_CAUSE_HANDSHAKE_FAILURE,
		ppi->state, ppi->pdstate, ppi->extState, timer_get_tics());
	wrp->next_state=WRS_IDLE;
	wr_reset_process(ppi,WR_ROLE_NONE);
	wr_servo_reset(ppi);
	pdstate_disable_extension(ppi);
}

void wr_handshake_fail(struct pp_instance *ppi)
{
	wr_handshake_fail_reason(ppi, WR_FAIL_REASON_UNKNOWN);
}


/* One of the steps failed: either retry or fail */
int wr_handshake_retry(struct pp_instance *ppi)
{
	struct wr_dsport *wrp = WR_DSPOR(ppi);

	if (wrp->wrStateRetry > 0) {
		wrp->wrStateRetry--;
		pp_diag(ppi, ext, 1, "Retry on timeout\n");
		return 1; /* yes, retry */
	}
	return 0; /* don't retry, we are over already */
}
