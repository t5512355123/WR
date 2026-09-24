/*
 * Copyright (C) 2011-2022 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released to the public domain
 */

/*
 * This is the main loop for unix stuff.
 */
#include <stdlib.h>
#include <errno.h>
#include <sys/select.h>
#include <netinet/if_ether.h>

#include <ppsi/ppsi.h>
#include <common-fun.h>
#include "ppsi-unix.h"

/* Call pp_state_machine for each instance. To be called periodically,
 * when no packets are incoming */
static int run_all_state_machines(struct pp_globals *ppg)
{
	int j;
	int delay_ms = 0, delay_ms_j;

	/* TODO: check if in GM mode and initialized */

	for (j = 0; j < ppg->nlinks; j++) {
		struct pp_instance *ppi = INST(ppg, j);
		int old_lu = ppi->link_up;
		
		/* TODO: add the proper discovery of link_up */
		ppi->link_up = 1;

		if (old_lu != ppi->link_up) {
			pp_diag(ppi, fsm, 1, "iface %s went %s\n",
				ppi->iface_name, ppi->link_up ? "up" : "down");

			if (ppi->link_up) {
				ppi->state = PPS_INITIALIZING;
				/* TODO: Get calibration values here */
			}

		}

		delay_ms_j = pp_state_machine(ppi, NULL, 0);

		/* delay_ms is the least delay_ms among all instances */
		if (j == 0)
			delay_ms = delay_ms_j;
		if (delay_ms_j < delay_ms)
			delay_ms = delay_ms_j;
	}

	/* BMCA must run at least once per announce interval 9.2.6.8 */
	if (pp_gtimeout(ppg, PP_TO_BMC)) {

		 /* Calculation of erbest, ebest, ... */
		bmc_calculate_ebest(ppg);
		pp_gtimeout_reset(ppg, PP_TO_BMC);
		delay_ms = 0;
		/* TODO: Check PLL state if needed/available */
	} else {
		/* check if the BMC timeout is the next to run */
		int delay_bmca;

		if ((delay_bmca = pp_gnext_delay_1(ppg, PP_TO_BMC)) < delay_ms)
			delay_ms = delay_bmca;
	}

	return delay_ms;
}

void unix_main_loop(struct pp_globals *ppg)
{
	struct pp_instance *ppi;
	int delay_ms;
	int j;

	/* Initialize each link's state machine */
	for (j = 0; j < ppg->nlinks; j++) {

		ppi = INST(ppg, j);

		/*
		* The main loop here is based on select. While we are not
		* doing anything else but the protocol, this allows extra stuff
		* to fit.
		*/
		ppi->is_new_state = 1;
	}

	delay_ms = run_all_state_machines(ppg);

	while (1) {
		int packet_available;

		packet_available = unix_net_ops.check_packet(ppg, delay_ms);

		if (packet_available < 0)
			continue;

		if (packet_available == 0) {
			delay_ms = run_all_state_machines(ppg);
			continue;
		}

		/* If delay_ms is -1, the above ops.check_packet will continue
		 * consuming the previous timeout (see its implementation).
		 * This ensures that every state machine is called at least once
		 * every delay_ms */
		delay_ms = -1;

		for (j = 0; j < ppg->nlinks; j++) {
			int tmp_d, i;
			ppi = INST(ppg, j);

			if ((ppi->ch[PP_NP_GEN].pkt_present) ||
			    (ppi->ch[PP_NP_EVT].pkt_present)) {

				i = __recv_and_count(ppi, ppi->rx_frame,
						PP_MAX_FRAME_LENGTH - 4,
						&ppi->last_rcv_time);

				if (i == PP_RECV_DROP) {
					continue; /* dropped or not for us */
				}
				if (i == -1) {
					pp_diag(ppi, frames, 1,
						"Receive Error %i: %s\n",
						errno, strerror(errno));
					continue;
				}

				tmp_d = pp_state_machine(ppi, ppi->rx_ptp,
					i - ppi->rx_offset);

				if ((delay_ms == -1) || (tmp_d < delay_ms))
					delay_ms = tmp_d;
			}
		}
	}
}
