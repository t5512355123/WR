/*
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on ptp-noposix project (see AUTHORS for details)
 *
 * Released to the public domain
 */

#include <ppsi/ppsi.h>

/* 
 * WR slave: got here from WRS_S_LOCK: send LOCKED, wait for CALIBRATE.
 * On timeout resend.
 */
#define WR_TMO_NAME "WR_LOCKED"
#define WR_TMO_MS WR_LOCKED_TIMEOUT_MS

int wr_locked(struct pp_instance *ppi, void *buf, int len, int new_state)
{
	int sendmsg = 0;
	struct wr_dsport *wrp = WR_DSPOR(ppi);

	if (new_state) {
		wrp->wrStateRetry = WR_STATE_RETRY;
		WRH_SRV(ppi)->readyForSync=TRUE; /* We can start synchronization in the servo */
		pp_timeout_set_rename(ppi, PP_TO_WR_EXT_0, WR_TMO_MS*(WR_STATE_RETRY+1));
		sendmsg = 1;
	} else {
		if (ppi->received_ptp_header.messageType == PPM_SIGNALING) {
			Enumeration16 wrMsgId;
			MsgSignaling wrsig_msg;

			if ( msg_unpack_wrsig(ppi, buf, &wrsig_msg, &wrMsgId) ) {
				if ( wrMsgId == CALIBRATE ) {
					wrp->next_state=  WRS_RESP_CALIB_REQ;
				} else {
					pp_diag(ppi, ext, 1, "WR: Invalid msgId(x%04x) received. %s was expected\n",wrMsgId, "CALIBRATE");
				}
				return 0;
			}
		}

		{ /* Check remaining time */
			int rms=pp_next_delay_1(ppi, PP_TO_WR_EXT_0);
			if ( rms<=(wrp->wrStateRetry*WR_TMO_MS)) {
				if ( !rms ) {
					pp_diag(ppi, time, 1, "timeout expired: %s\n", WR_TMO_NAME);
					wr_handshake_fail(ppi);
					return 0; /* non-wr already */
				}
				if (wr_handshake_retry(ppi))
					sendmsg = 1;
			}
		}
	}

	if (sendmsg) {
		msg_issue_wrsig(ppi, LOCKED);
	}

	return pp_next_delay_1(ppi,PP_TO_WR_EXT_0)-wrp->wrStateRetry*WR_TMO_MS;
}
