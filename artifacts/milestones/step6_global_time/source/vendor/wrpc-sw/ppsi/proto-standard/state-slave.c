/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Copyright (C) 2014 GSI (www.gsi.de)
 * Author: Cesar Prados
 * Originally based on PTPd project v. 2.1.0
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>
#include "common-fun.h"

static int slave_handle_sync(struct pp_instance *ppi, void *buf, int len);
static int slave_handle_followup(struct pp_instance *ppi, void *buf, int len);
static int slave_handle_response(struct pp_instance *ppi, void *buf, int len);
static int slave_handle_announce(struct pp_instance *ppi, void *buf, int len);

static pp_action * const actions[] = {
	[PPM_SYNC]		= slave_handle_sync,
	[PPM_DELAY_REQ]		= 0,
#if CONFIG_HAS_P2P
	[PPM_PDELAY_REQ]	= st_com_peer_handle_preq,
	[PPM_PDELAY_RESP]	= st_com_peer_handle_pres,
	[PPM_PDELAY_R_FUP]	= st_com_peer_handle_pres_followup,
#endif
	[PPM_FOLLOW_UP]		= slave_handle_followup,
	[PPM_DELAY_RESP]	= slave_handle_response,
	[PPM_ANNOUNCE]		= slave_handle_announce,
	[PPM_SIGNALING]		= st_com_handle_signaling,
	/* skip management, for binary size */
};

static int slave_handle_sync(struct pp_instance *ppi, void *buf,
			     int len)
{
	static int errcount=0;
	MsgHeader *hdr = &ppi->received_ptp_header;
	MsgSync sync;

	if (!msg_from_current_master(ppi)) {
		pp_error("%s: Sync message is not from current parent\n",
			__func__);
		return 0;
	}

	if ( is_delayMechanismE2E(ppi) &&  ppi->t1.scaled_nsecs==0 && ppi->t1.secs==0 ) {
		/* First time we receive the SYNC message in uncalib/slave state
		 * We set the REQUEST time-out to the minDelayReqInterval/2 value (500ms)
		 * in order to provide quickly a DelayReq message
		 */
		pp_timeout_set(ppi, PP_TO_REQUEST, (1000*(1<<PP_MIN_MIN_DELAY_REQ_INTERVAL))/2);
	}
	/* t2 may be overriden by follow-up, save it immediately */
	ppi->t2 = ppi->last_rcv_time;
	msg_unpack_sync(buf, &sync);

	if ((hdr->flagField[0] & PP_TWO_STEP_FLAG) != 0) {
		ppi->flags |= PPI_FLAG_WAITING_FOR_F_UP;
		ppi->recv_sync_sequence_id = hdr->sequenceId;
		/* for two-step, the stamp comes later */
		ppi->t1 = hdr->cField; /* most likely 0 */
	} else {
		/* one-step follows */
		ppi->flags &= ~PPI_FLAG_WAITING_FOR_F_UP;
		ppi->t1 = sync.originTimestamp;
		pp_time_add(&ppi->t1, &hdr->cField);
		ppi->syncCF = 0;
		/* t1 & t2 are saved in the instance. Check if they are correct */
		if (is_timestamp_incorrect_thres(ppi,&errcount,3 /* t1,t2 */))
			return 0;

		/* Call the extension; it may do it all and ask to return */
		if ( is_ext_hook_available(ppi,handle_sync) ) {
			int ret = ppi->ext_hooks->handle_sync(ppi);
			if (ret == 1)
				return 0;
			if (ret < 0)
				return ret;
		}
		pp_servo_got_sync(ppi,1);
	}
	return 0;
}

static int slave_handle_followup(struct pp_instance *ppi, void *buf,
				 int len)
{
	static int errcount=0;
	MsgFollowUp follow;

	MsgHeader *hdr = &ppi->received_ptp_header;

	if (!msg_from_current_master(ppi)) {
		pp_error("%s: Follow up message is not from current parent\n",
			__func__);
		return 0;
	}

	if (!(ppi->flags & PPI_FLAG_WAITING_FOR_F_UP)) {
		pp_error("%s: Slave was not waiting a follow up message\n",
			__func__);
		return 0;
	}

	if (ppi->recv_sync_sequence_id != hdr->sequenceId) {
		pp_error("%s: SequenceID %d doesn't match last Sync message "
			 "%d\n", __func__,
			 hdr->sequenceId, ppi->recv_sync_sequence_id);
		return 0;
	}

	msg_unpack_follow_up(buf, &follow);
	ppi->flags &= ~PPI_FLAG_WAITING_FOR_F_UP;
	/* t1 for calculations is T1 + Csyn + Cful -- see README-cfield */
	pp_time_add(&ppi->t1, &follow.preciseOriginTimestamp);
	pp_time_add(&ppi->t1, &hdr->cField);
	ppi->syncCF = hdr->cField.scaled_nsecs; /* for diag about TC */
	/* t1 & t2 are saved in the instance. Check if they are correct */
	if (is_timestamp_incorrect_thres(ppi,&errcount,3 /* t1,t2 */))
		return 0;
	/* Call the extension; it may do it all and ask to return */
	if (is_ext_hook_available(ppi,handle_followup)) {
		int ret = ppi->ext_hooks->handle_followup(ppi);
		if (ret == 1)
			return 0;
		if (ret < 0)
			return ret;
	}
	/* default servo action */
	pp_servo_got_sync(ppi,0);

	return 0;
}

static int slave_handle_response(struct pp_instance *ppi, void *buf,
				 int len)
{
	MsgHeader *hdr = &ppi->received_ptp_header;
	MsgDelayResp resp;	
	int ret;
	
	msg_unpack_delay_resp(buf, &resp);

	if ((bmc_idcmp(&DSPOR(ppi)->portIdentity.clockIdentity,
		    &resp.requestingPortIdentity.clockIdentity) != 0) ||
	    (ppi->sent_seq[PPM_DELAY_REQ] != hdr->sequenceId)   ||
	    (DSPOR(ppi)->portIdentity.portNumber != resp.requestingPortIdentity.portNumber) ||
	    (!msg_from_current_master(ppi))) {
		pp_diag(ppi, frames, 1, "%s : "
			"Delay Resp doesn't match Delay Req (f %x)\n",__func__,
			ppi->flags);
		return 0;
	}

	ppi->t4 = resp.receiveTimestamp;
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

	if (is_ext_hook_available(ppi,handle_resp)) {
		ret=ppi->ext_hooks->handle_resp(ppi);
	}
	else {
		ret=pp_servo_got_resp(ppi,1);
	}

	if ( ret && DSPOR(ppi)->logMinDelayReqInterval !=hdr->logMessageInterval) {
		DSPOR(ppi)->logMinDelayReqInterval = hdr->logMessageInterval;
		/* new value for logMin */
		pp_timeout_init(ppi);
	}
	return 0;
}

static int slave_handle_announce(struct pp_instance *ppi, void *buf, int len)
{
	int ret;
	struct pp_frgn_master frgn_master;
	struct pp_frgn_master *reg_frgn_master;

	if ((ret = st_com_handle_announce(ppi, buf, len))!=0)
		return ret;

	/* If externalPortConfiguration option is set, we consider that all
	 * announce messages come from the current master.
	 */
	bmc_store_frgn_master(ppi, &frgn_master, buf, len);

	/*  Clause 17.6.5.3 : ExternalPortConfiguration enabled
	 *  - The Announce receipt timeout mechanism (see 9.2.6.12) shall not be active.
	 *  - The specifications of 9.5.3 shall be replaced by the specifications of 17.6.5.5
	 */
	if (!is_externalPortConfigurationEnabled(DSDEF(ppi)) )  {
		if ( !msg_from_current_master(ppi) ) {
			pp_error("%s: Announce message is not from current parent\n",
				__func__);

			/* Clause 9.2.2.2 MasterOnly PTP ports :
			 * Announce messages received on a masterOnly PTP Port shall not be considered
			 * in the operation of the best master clock algorithm or in the update of data sets.
			 */
			if (!is_masterOnly(DSPOR(ppi))) {
				bmc_add_frgn_master(ppi, &frgn_master);
			}

			return 0;
		}
		/* 9.2.6.12 a) reset timeout */
		pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
	}

	/* Add foreign master: Figure 36 & 54 */
	if ( ( reg_frgn_master=bmc_add_frgn_master(ppi, &frgn_master))!=NULL) {
		/* 9.5.3 Figure 36 update data set if announce from current master */
		bmc_s1(ppi, reg_frgn_master);

		/* Save active peer MAC address */
		memcpy(ppi->activePeer,ppi->peer, sizeof(ppi->activePeer));
	}

	return 0;
}

/*
 * SLAVE and UNCALIBRATED have many things in common. This function implements
 * both states. We set "uncalibrated" internally to 0 or 1.
 */
int pp_slave(struct pp_instance *ppi, void *buf, int len)
{
	int ret = PP_SEND_OK; /* error var, to check errors in msg handling */
	Boolean uncalibrated = (ppi->state == PPS_UNCALIBRATED);
	MsgHeader *hdr = &ppi->received_ptp_header;

	/* upgrade from uncalibrated to slave or back*/
	if (uncalibrated) {
		if ( is_ext_hook_available(ppi,ready_for_slave) )  {
			if ( (*ppi->ext_hooks->ready_for_slave)(ppi) ) {
				ppi->next_state = PPS_SLAVE;
			}
		} else {
	           ppi->next_state = PPS_SLAVE;
		}
	} else {

		/* Check if the foreign master has changed */
		if ( DSPAR(ppi)->newGrandmaster ) {
			char gm_str[26];
			// New grandmaster detected

			DSPAR(ppi)->newGrandmaster=FALSE; // Clear it

			// State must transition from SLAVE to UNCALIBRATED
			ppi->next_state = PPS_UNCALIBRATED;

			Octet *id=DSPAR(ppi)->parentPortIdentity.clockIdentity.id;
			pp_info("New grandmaster detected: %s\n", format_hex8(gm_str, id));
		}
	}

	/* Force to stay on desired state if externalPortConfiguration option is enabled */
	if (is_externalPortConfigurationEnabled(DSDEF(ppi)) &&
			ppi->next_state == PPS_SLAVE &&
			ppi->externalPortConfigurationPortDS.desiredState==PPS_UNCALIBRATED)
		ppi->next_state = PPS_UNCALIBRATED; //Force to stay in uncalibrated state

	/* when entering uncalibrated init servo */
	if (uncalibrated && ppi->is_new_state) {
		memset(&ppi->t1, 0, sizeof(ppi->t1));
		pp_diag(ppi, servo, 2, "Entered to uncalibrated, reset servo\n");
		pp_servo_init(ppi);

		if (is_ext_hook_available(ppi,new_slave))
			ret = ppi->ext_hooks->new_slave(ppi, buf, len);
		if (ret!=PP_SEND_OK)
			goto out;
	}

	/* do a delay measurement either in p2p or e2e delay mode */
	pp_lib_may_issue_request(ppi);
	
	/*
	 * The management of messages is now table-driven
	 */
	if (hdr->messageType < ARRAY_SIZE(actions)
	    && actions[hdr->messageType]) {
		ret = actions[hdr->messageType](ppi, buf, len);
	} else {
		if (len)
			pp_diag(ppi, frames, 1, "Ignored frame %i\n",
				hdr->messageType);
	}

	/* Clause 17.6.5.3 : ExternalPortConfiguration enabled
	 *  - The Announce receipt timeout mechanism (see 9.2.6.12) shall not be active.
	 */
	if ( !is_externalPortConfigurationEnabled(DSDEF(ppi)))
		st_com_check_announce_receive_timeout(ppi);

out:
	if ( ret==PP_SEND_NO_STAMP ) {
		ret = PP_SEND_OK;/* nothing, just keep the ball rolling */
	}

	ppi->next_delay = is_externalPortConfigurationEnabled(DSDEF(ppi)) ?
			pp_next_delay_1(ppi,PP_TO_REQUEST) :
			pp_next_delay_2(ppi,PP_TO_ANN_RECEIPT, PP_TO_REQUEST);
	return ret;
}

