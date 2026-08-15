/*
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 *
 * Released to the public domain
 */

#include <ppsi/ppsi.h>
#include <math.h>

#define HAL_EXPORT_STRUCTURES
#include <ppsi-wrs.h>

#include <hal_exports.h>

int32_t wrs_get_clock_period(void)
{
	struct hal_port_state *p = &hal_ports[0];

	if (p && p->clock_period)
		return p->clock_period;
	return HAL_REF_CLOCK_PERIOD_PS; /* REF_CLOCK_PERIOD_PS */
}

int wrs_read_calibration_data(struct pp_instance *ppi, TimeInterval *scaledBitSlide,
		RelativeDifference *scaledDelayCoefficient,
		TimeInterval *scaledSfpDeltaTx, TimeInterval *scaledSfpDeltaRx)
{
	struct hal_port_state *p;

	p = pp_wrs_lookup_port(ppi->iface_name);
	if (!p)
		return WRH_HW_CALIB_ERROR;

	*scaledBitSlide=picos_to_interval( (int64_t) p->calib.bitslide_ps);
	*scaledDelayCoefficient=(RelativeDifference)(p->calib.sfp.alpha * REL_DIFF_TWO_POW_FRACBITS);
	*scaledSfpDeltaTx= picos_to_interval( (int64_t) p->calib.sfp.delta_tx_ps);
	*scaledSfpDeltaRx= picos_to_interval( (int64_t) p->calib.sfp.delta_rx_ps);
	return WRH_HW_CALIB_OK;
}
