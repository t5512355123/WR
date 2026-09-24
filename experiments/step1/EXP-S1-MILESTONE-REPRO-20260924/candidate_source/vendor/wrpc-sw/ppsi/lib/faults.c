/*
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Jean-Claude BAU
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */


#if CONFIG_HAS_FAULT_INJECTION_MECHANISM

struct pp_time faulty_stamps[6]; /* if unused, dropped at link time */

#if CONFIG_ARCH_IS_WRPC
int frame_rx_delay_us; /* set by faults.c */
#endif

#endif
