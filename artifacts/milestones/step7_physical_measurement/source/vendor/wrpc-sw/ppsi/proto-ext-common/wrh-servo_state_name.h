/*
 * Copyright (C) 2023 CERN (www.cern.ch)
 * Author: Jean-Claude BAU & Maciej Lipinski
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

/* Define wrh_servo_state_name as it is used by some other tools
 * (e.g. in WRS) */

static const char * const wrh_servo_state_name[] = {
	[WRH_UNINITIALIZED] = "Uninitialized",
	[WRH_SYNC_NSEC] = "SYNC_NSEC",
	[WRH_SYNC_TAI] = "SYNC_TAI",
	[WRH_SYNC_PHASE] = "SYNC_PHASE",
	[WRH_TRACK_PHASE] = "TRACK_PHASE",
	[WRH_WAIT_OFFSET_STABLE] = "WAIT_OFFSET_STABLE",
};
