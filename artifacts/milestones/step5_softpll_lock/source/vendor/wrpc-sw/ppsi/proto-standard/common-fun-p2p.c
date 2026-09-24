/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on PTPd project v. 2.1.0 (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>
#include "common-fun.h"
#include "../lib/network_types.h"

#if CONFIG_HAS_P2P


static int presp_call_servo(struct pp_instance *ppi)
{
	int ret = 0;

	if (is_incorrect(&ppi->t4))
		return 0; /* not an error, just no data */

	if (is_ext_hook_available(ppi,handle_presp))
		ret = ppi->ext_hooks->handle_presp(ppi);
	else {
		pp_servo_got_presp(ppi);
	}
	if ( ppi->state==PPS_MASTER) {
		/* Called to update meanLinkDelay
		 * No risk of interaction with the slave servo.
		 * Each instance has its own servo structure
		 */
		pp_servo_calculate_delays(ppi);
	}
	return ret;
}

int st_com_peer_handle_pres(struct pp_instance *ppi, void *buf,
			    int len)
{
	MsgPDelayResp resp;
	MsgHeader *hdr = &ppi->received_ptp_header;
	int e = 0;

	/* if not in P2P mode, just return */
	if (ppi->delayMechanism != MECH_P2P)
		return 0;
	
	msg_unpack_pdelay_resp(buf, &resp);

	if ((bmc_idcmp(&DSPOR(ppi)->portIdentity.clockIdentity,
		    &resp.requestingPortIdentity.clockIdentity) == 0) &&
	    ((ppi->sent_seq[PPM_PDELAY_REQ]) ==
	     hdr->sequenceId) &&
	    (DSPOR(ppi)->portIdentity.portNumber ==
	     resp.requestingPortIdentity.portNumber) ) {

		/* Check for multiple answers */
		if ( ppi->received_dresp ) {
			/* Response already received */
			/* Clause 11.4.3.C.1 When multiple Pdelay_Resp messages are received, PTP Instance-A shall ..
			 * enter the FAULTY state ...
			 */
			if ( !is_externalPortConfigurationEnabled(DSDEF(ppi)) ) {
				ppi->next_state = PPS_FAULTY;
				return 0;
			} else {
				/* externalPortConfiguration is enabled. We cannot change the state */
				pp_diag(ppi, frames, 2, "%s: "
					"Multiple PDelay Response received for the same request\n",__func__);
			}
		}
		ppi->received_dresp=1;
		ppi->t4 = resp.requestReceiptTimestamp;
		if ( is_ext_hook_available(ppi,is_correction_field_compliant) &&
				!ppi->ext_hooks->is_correction_field_compliant(ppi) ) {
			/* Not compliant with CF */
			pp_time_add(&ppi->t4, &hdr->cField);
		} else{
			/* We subtract the received CF and the current delayAsymmetry */
			struct pp_time delayAsym={
					.secs=0,
					.scaled_nsecs=ppi->portDS->delayAsymmetry
			};

			pp_time_sub(&ppi->t4, &hdr->cField);
			pp_time_sub(&ppi->t4, &delayAsym);
		}
		/* WARNING: should be "sub" (see README-cfield::BUG)  */
		ppi->t6 = ppi->last_rcv_time;
		if ((hdr->flagField[0] & PP_TWO_STEP_FLAG) != 0)
			ppi->flags |= PPI_FLAG_WAITING_FOR_RF_UP;
		else {
			ppi->flags &= ~PPI_FLAG_WAITING_FOR_RF_UP;
			/*
			 * Make sure responseOriginTimestamp is forced to 0
			 * for one-step responders
			 */
			memset(&ppi->t5, 0, sizeof(ppi->t5));
		}

		if (!(hdr->flagField[0] & PP_TWO_STEP_FLAG))
			e = presp_call_servo(ppi);

		/* Save active peer MAC address */
		memcpy(ppi->activePeer,ppi->peer, sizeof(ppi->activePeer));

	} else {
		pp_diag(ppi, frames, 2, "pp_pclock : "
			"PDelay Resp doesn't match PDelay Req\n");
	}
	return e;
}

int st_com_peer_handle_pres_followup(struct pp_instance *ppi,
				     void *buf, int len)
{
	MsgHeader *hdr = &ppi->received_ptp_header;
	MsgPDelayRespFollowUp respFllw;
	int e = 0;

	/* if not in P2P mode, just return */
	if (ppi->delayMechanism != MECH_P2P)
		return 0;
	
	msg_unpack_pdelay_resp_follow_up(buf, &respFllw);

	if ((bmc_idcmp(&DSPOR(ppi)->portIdentity.clockIdentity,
		    &respFllw.requestingPortIdentity.clockIdentity) == 0) &&
	    ((ppi->sent_seq[PPM_PDELAY_REQ]) ==
	     hdr->sequenceId) &&
	    (DSPOR(ppi)->portIdentity.portNumber ==
	     respFllw.requestingPortIdentity.portNumber) ) {

		/* Check for multiple answers */
		if ( ppi->received_dresp_fup ) {
			/* Response already received */
			/* Clause 11.4.3.C.1 When multiple Pdelay_Resp messages are received, PTP Instance-A shall ..
			 * enter the FAULTY state ...
			 */
			if ( !is_externalPortConfigurationEnabled(DSDEF(ppi)) ) {
				ppi->next_state = PPS_FAULTY;
				return 0;
			} else {
				/* externalPortConfiguration is enabled. We cannot change the state */
				pp_diag(ppi, frames, 2, "%s: "
					"Multiple PDelay Response Follow Up received for the same request\n",__func__);
			}
		}
		ppi->received_dresp_fup=1;
		ppi->t5 = respFllw.responseOriginTimestamp;
		pp_time_add(&ppi->t5, &hdr->cField);

		e = presp_call_servo(ppi);
	} else {
		pp_diag(ppi, frames, 2, "%s: "
			"PDelay Resp F-up doesn't match PDelay Req\n",
			__func__);
	}
	return e;
}

int st_com_peer_handle_preq(struct pp_instance *ppi, void *buf,
			    int len)
{
	int e = 0;

	/* if not in P2P mode, just return */
	if (ppi->delayMechanism != MECH_P2P)
		return 0;
	
	if (is_ext_hook_available(ppi,handle_preq))
		e = ppi->ext_hooks->handle_preq(ppi);
	if (e)
		return e;

	msg_issue_pdelay_resp(ppi, &ppi->last_rcv_time);
	msg_issue_pdelay_resp_followup(ppi, &ppi->last_snt_time);

	return 0;
}

/* Update currentDS.meanDelay and portDS.meanLinkDelay
 * This function overwrite the one declared if the P2P mechanism is not compiled
 */
void update_meanDelay(struct pp_instance *ppi, TimeInterval meanDelay) {
	/* clause 11.4.2.d.f : the <meanLinkDelay> shall be stored ... for the P2P port in the PTP SLAVE state in currentDS.meanDelay.*/
	if (ppi->delayMechanism == MECH_P2P) {
		DSPOR(ppi)->meanLinkDelay=meanDelay;
		if ( ppi->state != PPS_SLAVE )
			return;
	}
	if (ppi->state == PPS_SLAVE )
		DSCUR(ppi)->meanDelay=meanDelay;
}


#endif
