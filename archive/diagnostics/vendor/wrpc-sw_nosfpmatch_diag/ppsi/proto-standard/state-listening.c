/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on PTPd project v. 2.1.0 (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>
#include "common-fun.h"


static int listening_handle_announce(struct pp_instance *ppi, void *buf, int len);

static pp_action * const actions[] = {
	[PPM_SYNC]		= 0,
	[PPM_DELAY_REQ]		= 0,
#if CONFIG_HAS_P2P
	[PPM_PDELAY_REQ]	= st_com_peer_handle_preq,
	[PPM_PDELAY_RESP]	= st_com_peer_handle_pres,
	[PPM_PDELAY_R_FUP]	= st_com_peer_handle_pres_followup,
#endif
	[PPM_FOLLOW_UP]		= 0,
	[PPM_DELAY_RESP]	= 0,
	[PPM_ANNOUNCE]		= listening_handle_announce,
	[PPM_SIGNALING]		= st_com_handle_signaling,
};

static int listening_handle_announce(struct pp_instance *ppi, void *buf, int len) {

	int ret;

	if ((ret = st_com_handle_announce(ppi, buf, len))!=0)
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

int pp_listening(struct pp_instance *ppi, void *buf, int len)
{
	int e = 0; /* error var, to check errors in msg handling */
	MsgHeader *hdr = &ppi->received_ptp_header;

	if (is_ext_hook_available(ppi,listening)) {
		e=ppi->ext_hooks->listening(ppi, buf, len);
		if ( e ) {
			if (is_externalPortConfigurationEnabled(DSDEF(ppi)) )
				goto epc_out;
			else
				goto out;
		}
	}

	/* when the clock is using peer-delay, listening must send it too */
	if ( is_delayMechanismP2P(ppi) )
		e  = pp_lib_may_issue_request(ppi);
	/*
	 * The management of messages is now table-driven
	 */
	if (hdr->messageType < ARRAY_SIZE(actions)
	    && actions[hdr->messageType]) {
		e = actions[hdr->messageType](ppi, buf, len);
	} else {
		if (len)
			pp_diag(ppi, frames, 1, "Ignored frame %i\n",
				hdr->messageType);
	}

	/* Clause 17.6.5.3 : ExternalPortConfiguration enabled
	 *  - The Announce receipt timeout mechanism (see 9.2.6.12) shall not be active.
	 */
	if ( ! is_externalPortConfigurationEnabled(DSDEF(ppi))) {

		st_com_check_announce_receive_timeout(ppi);

		out:;
		if (e != 0)
			ppi->next_state = PPS_FAULTY;

		ppi->next_delay = is_delayMechanismP2P(ppi) ?
			pp_next_delay_2(ppi,PP_TO_ANN_RECEIPT, PP_TO_REQUEST) :
			pp_next_delay_1(ppi, PP_TO_ANN_RECEIPT);
		return e;
	}

	epc_out:;
	ppi->next_delay = is_delayMechanismP2P(ppi) ?
			pp_next_delay_1(ppi, PP_TO_REQUEST) :
			INT_MAX;
	return e;
}
