/*
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on ptp-noposix project (see AUTHORS for details)
 *
 * Released to the public domain
 */

#include <ppsi/ppsi.h>

/*
 * This is the last WR state: ack the other party and go master or slave.
 * There is no timeout nor a check for is_new_state: we just do things once
 */
int wr_link_on(struct pp_instance *ppi, void *buf, int len, int new_state)
{
	struct wr_dsport *wrp = WR_DSPOR(ppi);

	if (wrp->wrMode == WR_MASTER)
		if ( msg_issue_wrsig(ppi, WR_MODE_ON) )
			return 0; /* Retry next time */

	// Success
	WRH_OPER()->enable_ptracker(ppi);
	wrp->wrModeOn =
			wrp->parentWrModeOn = TRUE;
	wrp->next_state=WRS_IDLE;

	return 0;
}
