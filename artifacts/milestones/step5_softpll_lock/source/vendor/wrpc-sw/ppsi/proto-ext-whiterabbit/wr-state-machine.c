/*
 * Copyright (C) 2018 CERN (www.cern.ch)
 * Author: Jean-Claude BAU & Maciej Lipinski
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include "ppsi/ppsi.h"
#include "../proto-standard/common-fun.h"
#include "wr-constants.h"

typedef int (*wr_state_action_t)(struct pp_instance *ppi, void *buf, int len, int new_state);


typedef struct {
	char *name;

}wr_state_machine_t;

static const wr_state_action_t wr_state_actions[] ={
	[WRS_IDLE] = wr_idle,
	[WRS_PRESENT] = wr_present,
	[WRS_M_LOCK] = wr_m_lock,
	[WRS_S_LOCK] = wr_s_lock,
	[WRS_LOCKED] = wr_locked,
	[WRS_CALIBRATION] = wr_calibration,
	[WRS_CALIBRATED] = wr_calibrated,
	[WRS_RESP_CALIB_REQ] = wr_resp_calib_req,
	[WRS_WR_LINK_ON] = wr_link_on,
};

#define MAX_STATE_ACTIONS (sizeof(wr_state_actions)/sizeof(wr_state_machine_t))

static const char * const wr_state_names[] ={
	[WRS_IDLE] = "wr-idle",
	[WRS_PRESENT] = "wr-present",
	[WRS_M_LOCK] = "wr-m-lock",
	[WRS_S_LOCK] = "wr-s-lock",
	[WRS_LOCKED] = "wr-locked",
	[WRS_CALIBRATION] = "wr-calibration",
	[WRS_CALIBRATED] = "wr-calibrated",
	[WRS_RESP_CALIB_REQ] = "wr-resp-calib-req",
	[WRS_WR_LINK_ON] = "wr-link-on",
};

/*
 * This hook is called by fsm to run the extension state machine.
 * It is used to send signaling messages.
 * It returns the ext-specific timeout value
 */
int wr_run_state_machine(struct pp_instance *ppi, void *buf, int len)
{
	struct wr_dsport * wrp=WR_DSPOR(ppi);
	Boolean newState;
	int delay;

	if (wrp->next_state>=MAX_STATE_ACTIONS
	    || ppi->state==PPS_INITIALIZING
	    || !(ppi->extState==PP_EXSTATE_ACTIVE)) {
		wrp->next_state=WRS_IDLE; // Force to IDLE state
	}

	/*
	 * Evaluation of events common to all states
	 */
	newState = wrp->state != wrp->next_state;
	if ( newState ) {
		pp_diag(ppi, ext, 2, "WR state: LEAVE=%s, ENTER=%s\n",
				wr_state_names[wrp->state],
				wr_state_names[wrp->next_state]);
		wrp->state=wrp->next_state;
	}

	delay=(*wr_state_actions[wrp->state]) (ppi, buf,len, newState);

	return delay;
}

