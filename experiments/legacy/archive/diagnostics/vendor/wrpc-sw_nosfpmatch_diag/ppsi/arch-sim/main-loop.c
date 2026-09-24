/*
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Pietro Fezzardi (pietrofezzardi@gmail.com)
 *
 * Released to the public domain
 */

/*
 * This is the main loop for the simulator.
 */
#include <stdlib.h>
#include <errno.h>
#include <sys/select.h>
#include <netinet/if_ether.h>

#include <ppsi/ppsi.h>
#include <common-fun.h>
#include "ppsi-sim.h"

/* Call pp_state_machine for each instance. To be called periodically,
 * when no packets are incoming */
static int run_all_state_machines(struct pp_globals *ppg)
{
	int j;
	int delay_ms = 0, delay_ms_j;

	for (j = 0; j < ppg->nlinks; j++) {
		struct pp_instance *ppi = INST(ppg, j);
		sim_set_global_DS(ppi);
		delay_ms_j = pp_state_machine(ppi, NULL, 0);

		/* delay_ms is the least delay_ms among all instances */
		if (j == 0)
			delay_ms = delay_ms_j;
		if (delay_ms_j < delay_ms)
			delay_ms = delay_ms_j;
	}

	/* BMCA must run at least once per announce interval 9.2.6.8 */
	if (pp_gtimeout(ppg, PP_TO_BMC)) {
		bmc_calculate_ebest(ppg); /* Calculate erbest, ebest,... */
		pp_gtimeout_reset(ppg, PP_TO_BMC);
		delay_ms=0;
	} else {
		/* check if the BMC timeout is the next to run */
		int delay_bmca = pp_gnext_delay_1(ppg,PP_TO_BMC);
		if (delay_bmca < delay_ms)
			delay_ms = delay_bmca;
	}
	return delay_ms;
}


void sim_main_loop(struct pp_globals *ppg)
{
	struct pp_instance *ppi;
	struct sim_ppg_arch_data *data = SIM_PPG_ARCH(ppg);
	int64_t delay_ns, tmp_ns;
	int j, i;

	/* Initialize each link's state machine */
	for (j = 0; j < ppg->nlinks; j++) {
		ppi = INST(ppg, j);
		ppi->is_new_state = 1;
		/* just tell that the links are up */
		ppi->state = PPS_INITIALIZING;
		ppi->link_up = TRUE;
	}

	delay_ns = run_all_state_machines(ppg) * 1000LL * 1000LL;

	while (data->sim_iter_n <= data->sim_iter_max) {
		while (data->n_pending && data->pending->delay_ns <= delay_ns) {
			ppi = INST(ppg, data->pending->which_ppi);

			sim_fast_forward_ns(ppg, data->pending->delay_ns);
			delay_ns -= data->pending->delay_ns;

			i = __recv_and_count(ppi, ppi->rx_frame,
						PP_MAX_FRAME_LENGTH - 4,
						&ppi->last_rcv_time);

			sim_set_global_DS(ppi);
			tmp_ns = 1000LL * 1000LL * pp_state_machine(ppi,
					ppi->rx_ptp, i - ppi->rx_offset);

			if (tmp_ns < delay_ns)
				delay_ns = tmp_ns;
		}
		/* here we have no pending packets or the timeout for a state
		 * machine is expired (so delay_ns == 0). If the timeout is not
		 * expired we just fast forward till it's not expired, since we
		 * know that there are no packets pending. */
		sim_fast_forward_ns(ppg, delay_ns);
		delay_ns = run_all_state_machines(ppg) * 1000LL * 1000LL;
	}
	return;
}
