/*
 * Copyright (C) 2012-2020 CERN (www.cern.ch)
 * Author: Aurelio Colosimo, Adam Wujek
 *
 * Released to the public domain
 */

#include "net.h"
#include <ppsi/ppsi.h>
#include <softpll_ng.h>
#include <hal_exports.h>
#include "wrpc.h"
#include "../proto-ext-whiterabbit/wr-constants.h"
#include "board.h"

#include "sfp.h"
#include "dev/endpoint.h"

int32_t wrpc_get_clock_period(void)
{
	return REF_CLOCK_PERIOD_PS;
}

int wrpc_read_calibration_data(struct pp_instance *ppi,
			       TimeInterval *scaledBitSlide,
			       RelativeDifference *scaledDelayCoefficient,
			       TimeInterval *scaledSfpDeltaTx,
			       TimeInterval *scaledSfpDeltaRx)
{
	*scaledDelayCoefficient = (RelativeDifference)sfp_info.sfp_params.alpha;

	*scaledBitSlide = picos_to_interval(ep_get_bitslide(&wrc_endpoint_dev));
	
	/* check if tx is calibrated,
	 * if so read data */
	*scaledSfpDeltaTx = picos_to_interval(sfp_info.sfp_params.dTx);

	/* check if rx is calibrated,
	 * if so read data */
	*scaledSfpDeltaRx = picos_to_interval(sfp_info.sfp_params.dRx);

	return WRH_HW_CALIB_OK;
}
