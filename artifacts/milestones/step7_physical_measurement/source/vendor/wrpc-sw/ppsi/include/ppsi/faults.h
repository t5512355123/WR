/*
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Jean-Claude BAU
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

extern struct pp_time faulty_stamps[6]; /* if unused, dropped at link time */
extern int frame_rx_delay_us; /* set by faults.c */

static inline void apply_faulty_stamp(struct pp_instance *ppi, int index)
{
	if ( CONFIG_HAS_FAULT_INJECTION_MECHANISM ) {
		assert(index >= 1 && index <= 6, "Wrong T index %i\n", index);
		pp_time_add(&SRV(ppi)->t1 + index - 1, faulty_stamps + index - 1);
	}
}
