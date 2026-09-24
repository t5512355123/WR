/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on PTPd project v. 2.1.0 (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>

#define TIMEOUT_FAULTY_STATE_MS (60*1000) /* define the time to stay on faulty state before to go to initializing state */

/*
 * Fault troubleshooting. Now only comes back to
 * PTP_INITIALIZING state after a grace period.
 */

int pp_faulty(struct pp_instance *ppi, void *buf, int len)
{

	/* If the clockClass is < 128 and externalPortConfigurationEnabled is active,
	 * states SALVE and UNCALIBRATED are not allowed. We must stay in FAULTY state.
	 */
	if (is_externalPortConfigurationEnabled(DSDEF(ppi))) {
		Enumeration8 desiredState=ppi->externalPortConfigurationPortDS.desiredState;

		if ( DSDEF(ppi)->clockQuality.clockClass<128  &&
				(desiredState == PPS_SLAVE || desiredState == PPS_UNCALIBRATED)
				) {
			/*
			 * We set the next delay to an arbitrary value (1s) as we should stay forever
			 * in this state.
			 */
			ppi->next_delay = 1000; /* 1s */
			return 0;
		}
	}
	if ( ppi->is_new_state) {
		pp_timeout_set(ppi,PP_TO_IN_STATE, TIMEOUT_FAULTY_STATE_MS);
	} else {
		/* Check if we can exit from FAULTY state */
		if (pp_timeout(ppi, PP_TO_IN_STATE)) {
			pp_timeout_disable(ppi,PP_TO_IN_STATE);
			ppi->next_state = PPS_INITIALIZING;
			return 0;
		}
	}

	/* We stay on FAULTY state */
	ppi->next_delay = pp_next_delay_1(ppi, PP_TO_IN_STATE);
	return 0;
}
