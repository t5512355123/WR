/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released to the public domain
 */

/*
 * This is the main loop for the wr-switch architecture. It's amost
 * the same as the unix main loop, but we must serve RPC calls too
 */
#include <stdlib.h>
#include <errno.h>
#include <sys/select.h>
#include <netinet/if_ether.h>
#include <signal.h>
#include <unistd.h>
#include <limits.h>
#include <time.h>
#include <limits.h>

#include <ppsi/ppsi.h>
#include <ppsi-wrs.h>
#include <hal_exports.h>
#include <common-fun.h>

#define UPDATE_PORT_INFO_COUNT 2 // Update the port info every X time of the BMCA trigger

/* Get the PLL state and :
 * - for GM: set time and enable timing output
 * - update timingModeLockingState
 */
static inline void check_PLL_state(struct pp_globals *ppg) {
	wrh_timing_mode_pll_state_t pllState;

	if ( WRH_OPER()->get_timing_mode_state(ppg,&pllState)>=0 ) {
		// Check the PLL for grand master
		if ( WRS_ARCH_G(ppg)->timingMode==WRH_TM_GRAND_MASTER && pllState==WRH_TM_PLL_STATE_LOCKED ) {
			// GM Locked
			if ( WRS_ARCH_G(ppg)->timingModeLockingState==WRH_TM_LOCKING_STATE_LOCKING ||
					WRS_ARCH_G(ppg)->timingModeLockingState==WRH_TM_LOCKING_STATE_ERROR) {
				// Was not locked before
				struct pp_instance *ppi=INST(ppg,0);

				TOPS(ppi)->set(ppi,NULL); // GM locked: set the time
				TOPS(ppi)->enable_timing_output(ppg,1); // Enable timing output
			}
		}
		// Update timingModeLockingState field
		if (pllState==WRH_TM_PLL_STATE_LOCKED) {
			WRS_ARCH_G(ppg)->timingModeLockingState=WRH_TM_LOCKING_STATE_LOCKED;
		} else if ( pllState==WRH_TM_PLL_STATE_UNLOCKED ) {
			if ( WRS_ARCH_G(ppg)->timingModeLockingState==WRH_TM_LOCKING_STATE_LOCKED ) {
				// Was locked before
				WRS_ARCH_G(ppg)->timingModeLockingState=WRH_TM_LOCKING_STATE_ERROR;
				if (WRS_ARCH_G(ppg)->timingMode==WRH_TM_GRAND_MASTER)
					WRS_ARCH_G(ppg)->gmUnlockErr++;
			}
		}
	}

}

/* For GM, we have to wait the initialization of all ports before to set timing mode to GM
 * Returns 0 if initialization has been successfully applied otherwise 1
 */
static inline int grand_master_initialized(struct pp_globals *ppg) {
	static int initialized=0;

	if (!initialized) {
		if (ppg->defaultDS->clockQuality.clockClass != PP_PTP_CLASS_GM_LOCKED) {
			/* Must be done before executing fsm to degrade the clock if needed */
			bmc_update_clock_quality(ppg);
			initialized = 1;
		} else {
			if (hal_shmem->shmemState == HAL_SHMEM_STATE_INITITALIZED) {
				wrh_timing_mode_t current_timing_mode;
				int ret = WRH_OPER()->get_timing_mode(ppg,
						&current_timing_mode);

				if (ret < 0) {
					fprintf(stderr, "ppsi: Cannot get current timing mode\n");
					exit(1);
				}
				/* If read timing mode was GM, then we do not reprogram the hardware because it
				 * may unlock the PLL.
				 */
				if (current_timing_mode != WRH_TM_GRAND_MASTER) {
					/* Timing mode was not GM before */
					WRH_OPER()->set_timing_mode(ppg, WRH_TM_GRAND_MASTER);
					// Leave a delay before to read the PLL state later
				}
				else {
					WRS_ARCH_G(ppg)->timingMode = WRH_TM_GRAND_MASTER; // set here because set_timing_mode() is not called
					/* check if we shall update the clock qualities */
					/* Must be done before executing fsm to degrade the clock if needed */
					bmc_update_clock_quality(ppg);
					initialized = 1;
				}
			}
		}
	}
	return initialized;
}

/* Call pp_state_machine for each instance. To be called periodically,
 * when no packets are incoming */
static unsigned int run_all_state_machines(struct pp_globals *ppg)
{
	static int portInfoTmoIdx=-1;

	int j;
	int delay_ms = 0, delay_ms_j;

	if ( portInfoTmoIdx==-1) {
		pp_gtimeout_get_timer(ppg, PP_TO_WRS_SEND_PORT_INFO, TO_RAND_NONE);
		portInfoTmoIdx=1;
		pp_gtimeout_set(ppg,PP_TO_WRS_SEND_PORT_INFO,2000); // Update interface info every 2 seconds
		pp_gtimeout_set(ppg, PP_TO_BMC,TMO_DEFAULT_BMCA_MS);
	}

	// If GM mode is not initialized, we cannot continue
	if ( !grand_master_initialized(ppg) )
		return PP_DEFAULT_NEXT_DELAY_MS;

	for (j = 0; j < ppg->nlinks; j++) {
		struct pp_instance *ppi = INST(ppg, j);
		int old_lu = ppi->link_up;
		struct hal_port_state *p;

		/* FIXME: we should save this pointer in the ppi itself */
		p = pp_wrs_lookup_port(ppi->iface_name);
		if (!p) {
			fprintf(stderr, "ppsi: can't find %s in shmem\n",
				ppi->iface_name);
			continue;
		}

		ppi->link_up =state_up(p) &&
				hal_shmem->shmemState==HAL_SHMEM_STATE_INITITALIZED;// Up only when all links are initialized

		if (old_lu != ppi->link_up) {

			pp_diag(ppi, fsm, 1, "iface %s went %s\n",
				ppi->iface_name, ppi->link_up ? "up":"down");

			if (ppi->link_up) {
				TimeInterval scaledBitSlide = 0;
				RelativeDifference scaledDelayCoefficient = 0;
				TimeInterval scaledSfpDeltaTx = 0;
				TimeInterval scaledSfpDeltaRx = 0;

				ppi->state = PPS_INITIALIZING;
				if ( wrs_read_calibration_data(ppi,
						&scaledBitSlide,
						&scaledDelayCoefficient,
						&scaledSfpDeltaTx,
						&scaledSfpDeltaRx)!= WRH_HW_CALIB_OK ) {
					pp_diag(ppi, fsm, 1, "Cannot get calibration values (bitslide, alpha, TX/Rx delays\n");
				}
				ppi->timestampCorrectionPortDS.semistaticLatency= scaledBitSlide;
				if (scaledDelayCoefficient>=PP_MIN_DELAY_COEFFICIENT_AS_RELDIFF
				    && scaledDelayCoefficient<=PP_MAX_DELAY_COEFFICIENT_AS_RELDIFF ) {
					/* Scaled delay coefficient is valid then delta tx and rx also */
					if ( ppi->asymmetryCorrectionPortDS.enable ) {
						ppi->cfg.scaledDelayCoefficient=scaledDelayCoefficient;
						enable_asymmetryCorrection(ppi,TRUE);
					}
					ppi->timestampCorrectionPortDS.egressLatency=picos_to_interval(ppi->cfg.egressLatency_ps)+scaledSfpDeltaTx;
					ppi->timestampCorrectionPortDS.ingressLatency=picos_to_interval(ppi->cfg.ingressLatency_ps)+scaledSfpDeltaRx;
				}
			}
			else {
				ppi->next_state = PPS_DISABLED;
				pp_leave_current_state(ppi);
				ppi->n_ops->exit(ppi);
				ppi->frgn_rec_num = 0;
				ppi->frgn_rec_best = -1;
				if (ppg->ebest_idx == ppi->port_idx)
                                {
					if( ppi->ext_hooks->servo_reset)
						(*ppi->ext_hooks->servo_reset)(ppi);
					/* FIXME: this should be done in a different place and in a nicer way.
					   This dirty hack was introduce to force re-doing of WR Link Setup
					   when a link goes down and then up. */
					if (ppi->ext_data)
						WRH_SRV(ppi)->doRestart = TRUE;
                                }
			}
		}

		/* Do not call state machine if link is down */
		delay_ms_j =  ppi->link_up ?
			 pp_state_machine(ppi, NULL, 0) :
			 PP_DEFAULT_NEXT_DELAY_MS;

		/* delay_ms is the least delay_ms among all instances */
		if (j == 0)
			delay_ms = delay_ms_j;
		if (delay_ms_j < delay_ms)
			delay_ms = delay_ms_j;
	}

	/* BMCA must run at least once per announce interval 9.2.6.8 */
	if (pp_gtimeout(ppg, PP_TO_BMC)) {

		bmc_calculate_ebest(ppg); /* Calculation of erbest, ebest ,... */
		pp_gtimeout_reset(ppg, PP_TO_BMC);
		delay_ms=0;
		check_PLL_state(ppg);
	} else {

		/* check if the BMC timeout is the next to run */
		int delay_bmca;
		if ( (delay_bmca=pp_gnext_delay_1(ppg,PP_TO_BMC))<delay_ms )
			delay_ms=delay_bmca;
	}

	if ( pp_gtimeout(ppg, PP_TO_WRS_SEND_PORT_INFO) ) {
		wrs_update_port_info(ppg);
		pp_gtimeout_reset(ppg,PP_TO_WRS_SEND_PORT_INFO);
	}

	return delay_ms;
}

static int  alarmDetected=1;

static void sched_handler(int sig, siginfo_t *si, void *uc)
{
  alarmDetected=1;
}

static void init_alarm(timer_t *timerid) {
	    struct sigevent sev;
	    struct sigaction sa;

	    /* Set the signal handler */
	    sa.sa_flags = SA_SIGINFO;
	    sa.sa_sigaction = sched_handler;
	    sigemptyset(&sa.sa_mask);
	    if (sigaction(SIGALRM, &sa, NULL) == -1) {
			fprintf(stderr, "ppsi: cannot set signal handler\n");
			exit(1);
	    }

	    /* Create the timer */
		sev.sigev_notify = SIGEV_SIGNAL;
		sev.sigev_signo = SIGALRM;
		sev.sigev_value.sival_ptr = timerid;
		if (timer_create(CLOCK_MONOTONIC, &sev, timerid) == -1) {
			fprintf(stderr, "ppsi: Cannot create timer\n");
			exit(1);
		}
}

static void start_alarm(timer_t *timerid, unsigned int delay_ms) {
	struct itimerspec its;

    its.it_value.tv_sec = delay_ms/1000;
    its.it_value.tv_nsec = (delay_ms%1000) * 1000000;
    its.it_interval.tv_sec =
    its.it_interval.tv_nsec = 0;

    if (timer_settime(*timerid, 0, &its, NULL) == -1){
		fprintf(stderr, "ppsi: Cannot start timer. DelayMs=%u. Errno=%d\n",delay_ms, errno);
	}

}

static unsigned int stop_alarm(timer_t *timerid) {
	struct itimerspec its;
	struct itimerspec ito;

    its.it_value.tv_sec =
    its.it_value.tv_nsec =
    its.it_interval.tv_sec =
    its.it_interval.tv_nsec = 0;

    if (timer_settime(*timerid, 0, &its, &ito) == -1){
		fprintf(stderr, "ppsi: Cannot stop timer\n");
		return 0;
	}
    return (int) (ito.it_value.tv_sec*1000+ito.it_value.tv_nsec/1000000);
}


void wrs_main_loop(struct pp_globals *ppg)
{
	struct pp_instance *ppi;
	int skipped_checks=0;
	unsigned int delay_ms;
    timer_t timerid;
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

    /* Create the timer */
	init_alarm(&timerid);

	while (1) {
		int packet_available;

		/* Checking of received frames or minirpc are not done if the delay
		 * is 0 or the scheduling alarm is raised. These checks must be forced sometime
		 * (see skipped_checks)
		 */
		if ( !alarmDetected && (skipped_checks > 10 || delay_ms !=0) ) {
			minipc_server_action(ppsi_ch, 1 /* ms */);
			packet_available = wrs_net_ops.check_packet(ppg, delay_ms);
			skipped_checks=0;
		} else {
			skipped_checks++;
			packet_available=0;
		}

		if ((packet_available<=0) && (alarmDetected || (delay_ms==0))) {
			/* Time to run the state machine */
			stop_alarm(&timerid); /* Clear previous alarm */
		    delay_ms = run_all_state_machines(ppg);
		    /* We force to run the state machine at a minimum rate of PP_DEFAULT_NEXT_DELAY_MS */
			if (delay_ms>PP_DEFAULT_NEXT_DELAY_MS )
				delay_ms=PP_DEFAULT_NEXT_DELAY_MS;
		    alarmDetected=0;
		    if ( delay_ms != 0 ) {
		    	/* Start the alarm */
				start_alarm(&timerid,delay_ms);
		    }
			continue;
		}

		if (packet_available > 0 ) {
			/* If delay_ms is UINT_MAX, the above ops.check_packet will continue
			 * consuming the previous timeout (see its implementation).
			 * This ensures that every state machine is called at least once
			 * every delay_ms */
			delay_ms = UINT_MAX;
			for (j = 0; j < ppg->nlinks; j++) {
				int tmp_d,i;
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
						pp_diag(ppi, frames, 1,	"Receive Error %i: %s\n",errno, strerror(errno));
						continue;
					}

					tmp_d = pp_state_machine(ppi, ppi->rx_ptp,
						i - ppi->rx_offset);

					if ( tmp_d < delay_ms )
						delay_ms = tmp_d;
				}
			}
			if ((delay_ms!=UINT_MAX) &&  !alarmDetected ) {
				int rem_delay_ms=stop_alarm(&timerid); /* Stop alarm and get remaining delay */

				if ( rem_delay_ms < delay_ms) {
					/* Re-adjust delay_ms */
					delay_ms=rem_delay_ms;
				}
				alarmDetected=0;
				start_alarm(&timerid,delay_ms); /* Start alarm */
			}
		}
	}
}
