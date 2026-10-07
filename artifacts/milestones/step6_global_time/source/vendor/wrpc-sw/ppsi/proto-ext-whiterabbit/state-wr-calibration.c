/*
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on ptp-noposix project (see AUTHORS for details)
 *
 * Released to the public domain
 */

#include <ppsi/ppsi.h>

/*
 * We enter this state from  WRS_M_LOCK or WRS_RESP_CALIB_REQ.
 * We send CALIBRATE and do the hardware steps; finally we send CALIBRATED.
 */
#define WR_TMO_NAME "WR_CALIBRATION"
#define WR_TMO_MS wrp->calPeriod

int wr_calibration(struct pp_instance *ppi, void *buf, int len, int new_state)
{
	struct wr_dsport *wrp = WR_DSPOR(ppi);
	wr_servo_ext_t *se =WRE_SRV(ppi);
	FixedDelta *delta;
	TimeInterval ti;

	/* Calculate deltaTx and update servo*/
	delta = &wrp->deltaTx;
	ti = ppi->timestampCorrectionPortDS.egressLatency*1000;
	delta->scaledPicoseconds.msb = ti >> 32;
	delta->scaledPicoseconds.lsb = ti & 0xFFFFFFFF;
	pp_diag(ppi, ext, 1, "%s: msb=0x%x lsb=0x%x\n", "deltaTx",
		wrp->deltaTx.scaledPicoseconds.msb,
		wrp->deltaTx.scaledPicoseconds.lsb);
	fixedDelta_to_pp_time(*delta, &se->delta_txs);/* Update servo specific data */

	/* Calculate deltaRx and update servo*/
	delta = &wrp->deltaRx;
	ti= ((ppi->timestampCorrectionPortDS.ingressLatency +
				ppi->timestampCorrectionPortDS.semistaticLatency) * 1000);
	delta->scaledPicoseconds.msb = ti >> 32;
	delta->scaledPicoseconds.lsb = ti & 0xFFFFFFFF;
	pp_diag(ppi, ext, 1, "%s: msb=0x%x lsb=0x%x\n", "deltaRx",
		wrp->deltaRx.scaledPicoseconds.msb,
		wrp->deltaRx.scaledPicoseconds.lsb);
	fixedDelta_to_pp_time(*delta, &se->delta_rxs);/* Update servo specific data */

	/* Go to the next state */
	wrp->next_state = WRS_CALIBRATED;
	wrp->calibrated = TRUE;

	/* Send CLALIBRATE message */
	msg_issue_wrsig(ppi, CALIBRATE);
	wrp->wrPortState = 0; /* No longer used */

	return 0;
}
