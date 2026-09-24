/*
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on ptp-noposix project (see AUTHORS for details)
 *
 * Released to the public domain
 */

#include <ppsi/ppsi.h>

/*
 * WRS_IDLE is the entry point for the IDLE state
 */
int wr_idle(struct pp_instance *ppi, void *buf, int len, int new_state)
{
	int delay=1000;// default delay
	struct wr_dsport *wrp = WR_DSPOR(ppi);

	if (  ppi->state==PPS_MASTER ) {
		/* Check the reception of a slave present message.
		 * If it arrives we must restart the WR handshake
		 */

		if (ppi->received_ptp_header.messageType == PPM_SIGNALING) {
			Enumeration16 wrMsgId;
			MsgSignaling wrsig_msg;

			if ( msg_unpack_wrsig(ppi, buf, &wrsig_msg,	&wrMsgId) ) {
				if ( wrMsgId == SLAVE_PRESENT) {
					// Start handshake
					wrp->next_state = WRS_M_LOCK;
					delay=0;
				}
				pdstate_enable_extension(ppi); // Enable extension in all cases
			}
		}
	} else {
		if ( wrp->parentDetection==PD_WR_PARENT ) {
			// New WR parent detected
			if ( ppi->extState==PP_EXSTATE_PTP) {
				pp_diag(ppi, ext, 1, "%s: WR extension enabled.\n",__FUNCTION__);
				pdstate_enable_extension(ppi);
			}
			if ( ppi->extState==PP_EXSTATE_ACTIVE ) {
				if ( wrp->state == WRS_IDLE ) {
					if ( ppi->state==PPS_SLAVE) {
						ppi->next_state=PPS_UNCALIBRATED;
					}
					wr_reset_process(ppi,WR_SLAVE);
					wrp->next_state=WRS_PRESENT;
					wrp->parentDetection=PD_NO_DETECTION;
				}
			} else {
				wrp->parentDetection=PD_NO_DETECTION;
			}
			delay=0;
		}
		else if ( wrp->parentDetection==PD_NOT_WR_PARENT ) {
			if ( ppi->extState==PP_EXSTATE_ACTIVE ) {
				pp_diag(ppi, ext, 1, "%s: WR extension disabled.\n",__FUNCTION__);
				pdstate_disable_extension(ppi);
			}
			if ( ppi->state==PPS_SLAVE) {
				ppi->next_state=PPS_UNCALIBRATED;
			}
			wrp->parentDetection=PD_NO_DETECTION;
		}
	}

	return delay;
}
