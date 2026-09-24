/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2020 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <wrpc.h>
#include "board.h"
#include "wrc-debug.h"
#include "wrc-event.h"
#include "event.h"

static int prev_ptp_mode;
static int prev_ptp_state;
static int prev_servo_state;
static int prev_timing_ok;

void wrc_events_ptp_init(void)
{
	prev_ptp_mode = -1;
	prev_ptp_state = -1;
	prev_servo_state = -1;
	prev_timing_ok = 0;
}

int wrc_events_ptp_poll(void)
{
	extern struct pp_instance ppi_static;
	struct pp_instance *ppi = &ppi_static;
	struct pp_servo *ss = SRV(ppi);//= &((struct wr_data *)ppi->ext_data)->servo_state;

	int mode = wrc_ptp_get_mode();

	if( mode != prev_ptp_mode )
	{
		main_dbg("PTP mode changed.\n");
		prev_timing_ok = 0;
		event_post( WRC_EVENT_PTP_MODE_CHANGED );
	}

	prev_ptp_mode = mode;

	// observe the PTP state machine transitions and the servo state - and depending on the mode of 
	// operation (master/slave), send the 'Timing up'/'Timing down' events.
	if( mode == WRC_MODE_MASTER )
	{
		if( ppi->state == PPS_MASTER && prev_ptp_state != PPS_MASTER )
		{
			prev_timing_ok = 1;
			event_post( WRC_EVENT_TIMING_UP );
		}
		else if ( ppi->state != PPS_MASTER && prev_ptp_state == PPS_MASTER )
		{
			prev_timing_ok = 0;
			event_post( WRC_EVENT_TIMING_DOWN );
		}
	}
	else if ( mode == WRC_MODE_SLAVE )
	{
		if( ppi->state == PPS_SLAVE )
		{
			if( ss->state == WRH_TRACK_PHASE && prev_servo_state != WRH_TRACK_PHASE )
			{
				prev_timing_ok = 1;
				event_post( WRC_EVENT_TIMING_UP );
			}
			else if( ss->state != WRH_TRACK_PHASE && prev_servo_state == WRH_TRACK_PHASE )
			{
				prev_timing_ok = 0;
				event_post( WRC_EVENT_TIMING_DOWN );
			}
		}
		else if( ppi->state != PPS_SLAVE && prev_ptp_state == PPS_SLAVE )
		{
			prev_timing_ok = 0;
			event_post( WRC_EVENT_TIMING_DOWN );
		}
	}

	prev_ptp_state = ppi->state;
	prev_servo_state = ss->state;

	return 1;
}

void wrc_events_ptp_link_down(void)
{
	/* TODO: do boards need events NETIF_LINK_WENT_DOWN and
	 * WRC_EVENT_TIMING_DOWN? Isn't enough to have link down?
	 */ 
	if (!BOARD_USE_EVENTS)
		return;

	prev_timing_ok = 0;
}

int wrc_is_timing_up(void)
{
	return prev_timing_ok;
}
