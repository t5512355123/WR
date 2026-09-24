/*
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on ptp-noposix project (see AUTHORS for details)
 *
 * Released to the public domain
 */

#include <ppsi/ppsi.h>

/*
 * We enter here from WRS_CALIBRATION.  If master we wait for
 * a CALIBRATE message, if slave we wait for LINK_ON.
 */
#define WR_TMO_NAME "WR_CALIBRATED"
#define WR_TMO_MS WR_CALIBRATED_TIMEOUT_MS

int wr_calibrated(struct pp_instance *ppi, void *buf, int len, int new_state)
{
	struct wr_dsport *wrp = WR_DSPOR(ppi);
	int sendmsg = 0;

	if (new_state) {
		wrp->wrStateRetry = WR_STATE_RETRY;
		pp_timeout_set_rename(ppi, PP_TO_WR_EXT_0, WR_TMO_MS*(WR_STATE_RETRY+1));
		sendmsg = 1;
	} else {

		if (ppi->received_ptp_header.messageType == PPM_SIGNALING) {
			Enumeration16 wrMsgId;
			MsgSignaling wrsig_msg;

			if ( msg_unpack_wrsig(ppi, buf, &wrsig_msg, &wrMsgId) ) {

				if ((wrMsgId == CALIBRATE) &&
					(wrp->wrMode == WR_MASTER)) {
					wrp->next_state = WRS_RESP_CALIB_REQ;
				}
				else if ((wrMsgId == WR_MODE_ON) &&
					(wrp->wrMode == WR_SLAVE)) {
					wrp->next_state = WRS_WR_LINK_ON;
				} else {
					pp_diag(ppi, ext, 1, "WR: Invalid msgId(x%04x) received. %s was expected\n", wrMsgId, "CALIBRATE/WR_MODE_ON");
				}
				return 0;

			}
		}
		{
			/* Check if tmo expired */
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

	if (sendmsg){
		msg_issue_wrsig(ppi, CALIBRATED);
    }

	return pp_next_delay_1(ppi,PP_TO_WR_EXT_0)-wrp->wrStateRetry*WR_TMO_MS;
}
