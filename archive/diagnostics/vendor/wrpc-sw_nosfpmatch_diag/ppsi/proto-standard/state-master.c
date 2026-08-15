/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on PTPd project v. 2.1.0 (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>
#include "common-fun.h"

static int master_handle_delay_request(struct pp_instance *ppi,
				       void *buf, int len);
static int master_handle_announce(struct pp_instance *ppi, void *buf, int len);

static pp_action * const actions[] = {
	[PPM_SYNC]		= 0,
	[PPM_DELAY_REQ]		= master_handle_delay_request,
#if CONFIG_HAS_P2P
	[PPM_PDELAY_REQ]	= st_com_peer_handle_preq,
	[PPM_PDELAY_RESP]	= st_com_peer_handle_pres,
	[PPM_PDELAY_R_FUP]	= st_com_peer_handle_pres_followup,
#endif
	[PPM_FOLLOW_UP]		= 0,
	[PPM_DELAY_RESP]	= 0,
	[PPM_ANNOUNCE]		= master_handle_announce,
	[PPM_SIGNALING]		= st_com_handle_signaling,
	/* skip management, for binary size */
};

static int master_handle_announce(struct pp_instance *ppi, void *buf, int len)
{
	int ret = 0;

	ret = st_com_handle_announce(ppi, buf, len);
	if (ret)
		return ret;

	/* Clause 9.2.2.2 MasterOnly PTP ports :
	 * Announce messages received on a masterOnly PTP Port shall not be considered
	 * in the operation of the best master clock algorithm or in the update of data sets.
	 */
	if (!is_masterOnly(DSPOR(ppi))) {
		struct pp_frgn_master frgn_master;

		bmc_store_frgn_master(ppi, &frgn_master, buf, len);
		bmc_add_frgn_master(ppi, &frgn_master);
	}
	return 0;
}

static int master_handle_delay_request(struct pp_instance *ppi,
				       void *buf, int len)
{
	/* if not in MECH_E2E mode, just return */
	if ( is_delayMechanismE2E(ppi) ) {
		if (ppi->state == PPS_MASTER) { /* not pre-master */
			if ( !msg_issue_delay_resp(ppi, &ppi->last_rcv_time) ) {
				if (is_ext_hook_available(ppi,handle_dreq))
					ppi->ext_hooks->handle_dreq(ppi);

				/* Save active peer MAC address */
				memcpy(ppi->activePeer,ppi->peer, sizeof(ppi->activePeer));
			}
		}
	}
	return 0;
}

/*
 * MASTER and PRE_MASTER have many things in common. This function implements
 * both states. We set "pre" internally to 0 or 1.
 */
int pp_master(struct pp_instance *ppi, void *buf, int len)
{
	int msgtype;
	int pre = (ppi->state == PPS_PRE_MASTER);
	int e = 0; /* error var, to check errors in msg handling */

	/* upgrade from pre-master to master */
	if (!is_externalPortConfigurationEnabled(DSDEF(ppi)) &&
			pre &&
			pp_timeout(ppi, PP_TO_QUALIFICATION)
			) {
		ppi->next_state = PPS_MASTER;
		/* start sending immediately and reenter */
		pp_timeout_reset_N(ppi, PP_TO_SYNC_SEND,0);
		pp_timeout_reset_N(ppi, PP_TO_ANN_SEND,0);
		ppi->next_delay = 0;
		return 0;
	}

	if (!pre) {
		/*
		 * ignore errors; we are not getting FAULTY if not
		 * transmitting
		 */
		pp_lib_may_issue_sync(ppi);
		pp_lib_may_issue_announce(ppi);
	}

	/* when the clock is using peer-delay, the master must send it too */
	if ( is_delayMechanismP2P(ppi) )
		pp_lib_may_issue_request(ppi);

	/*
	 * An extension can do special treatment of this message type,
	 * possibly returning error or eating the message by returning
	 * PPM_NO_MESSAGE
	 */
	msgtype = ppi->received_ptp_header.messageType;

	/*
	 * The management of messages is now table-driven
	 */
	if (msgtype < ARRAY_SIZE(actions)
	    && actions[msgtype]) {
		e = actions[msgtype](ppi, buf, len);
	} else {
		if (len && msgtype != PPM_NO_MESSAGE)
			pp_diag(ppi, frames, 1, "Ignored frame %i\n",
				msgtype);
	}

	if ( is_externalPortConfigurationEnabled(DSDEF(ppi))) {
		if ( e==PP_SEND_ERROR || e==PP_SEND_NO_STAMP )
			e=0;
		if (pre) {
			ppi->next_delay = is_delayMechanismP2P(ppi) ?
					pp_next_delay_1(ppi,PP_TO_REQUEST) :
					INT_MAX;
		} else {
			ppi->next_delay = is_delayMechanismP2P(ppi) ?
					pp_next_delay_3(ppi,PP_TO_ANN_SEND, PP_TO_SYNC_SEND, PP_TO_REQUEST) :
					pp_next_delay_2(ppi,PP_TO_ANN_SEND, PP_TO_SYNC_SEND);
		}
	} else {
		switch(e) {
		case PP_SEND_OK: /* 0 */
			/* Why should we switch to slave? Remove this code? */
			if ( is_slaveOnly(DSDEF(ppi)) )
				ppi->next_state = PPS_LISTENING;
			break;
		case PP_SEND_ERROR:
			/* fall through: a lost frame is not the end of the world */
		case PP_SEND_NO_STAMP:
			/* nothing, just keep the ball rolling */
			e = 0;
			break;
		}
	
		if (pre) {
			ppi->next_delay = is_delayMechanismP2P(ppi) ?
					pp_next_delay_2(ppi,PP_TO_QUALIFICATION, PP_TO_REQUEST) :
					pp_next_delay_1(ppi,PP_TO_QUALIFICATION);
		} else {
			ppi->next_delay = is_delayMechanismP2P(ppi) ?
					pp_next_delay_3(ppi,PP_TO_ANN_SEND, PP_TO_SYNC_SEND, PP_TO_REQUEST) :
					pp_next_delay_2(ppi,PP_TO_ANN_SEND, PP_TO_SYNC_SEND);
		}
	}
	return e;
}

