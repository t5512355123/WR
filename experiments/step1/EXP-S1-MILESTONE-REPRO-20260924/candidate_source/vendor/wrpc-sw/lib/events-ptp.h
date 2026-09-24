/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2020 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#ifndef __EVENTS_PTP_H
#define __EVENTS_PTP_H

void wrc_events_ptp_init(void);
int wrc_events_ptp_poll(void);
int wrc_is_timing_up(void);
void wrc_events_ptp_link_down(void);

#endif /* __EVENTS_PTP_H */
