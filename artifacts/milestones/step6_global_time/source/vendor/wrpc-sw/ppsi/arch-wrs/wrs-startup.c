/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released to the public domain
 */

/*
 * This is the startup thing for hosted environments. It
 * defines main and then calls the main loop.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/timex.h>
#include <signal.h>

#include <minipc.h>

#include <ppsi/ppsi.h>
#include <ppsi-wrs.h>
#include <libwr/shmem.h>

#  define WRSW_HAL_RETRIES 1000

#define WRSW_HAL_TIMEOUT 2000000 /* us */

const struct wrh_operations wrh_oper = {
	.locking_enable = wrs_locking_enable,
	.locking_poll = wrs_locking_poll,
	.locking_disable = wrs_locking_disable,
	.locking_reset = wrs_locking_reset,
	.enable_ptracker = wrs_enable_ptracker,

	.adjust_in_progress = wrs_adjust_in_progress,
	.adjust_counters = wrs_adjust_counters,
	.adjust_phase = wrs_adjust_phase,
	.get_clock_period = wrs_get_clock_period,

	.set_timing_mode= wrs_set_timing_mode,
	.get_timing_mode= wrs_get_timing_mode,
	.get_timing_mode_state= wrs_get_timing_mode_state,
};

struct minipc_ch *hal_ch;
struct minipc_ch *ppsi_ch;
struct hal_port_state *hal_ports;
struct hal_shmem_header *hal_shmem;
int hal_nports;
struct wrs_shm_head *ppsi_head;

extern struct pp_ext_hooks  pp_hooks;

#if CONFIG_HAS_EXT_L1SYNC
/**
 * Enable the l1sync extension for a given ppsi instance
 */
static  int enable_l1Sync(struct pp_instance *ppi, Boolean enable) {
	if ( enable ) {
		ppi->protocol_extension=PPSI_EXT_L1S;
		/* Add L1SYNC extension portDS */
		if ( !(ppi->portDS->ext_dsport =wrs_shm_alloc(ppsi_head, sizeof(l1e_ext_portDS_t))) ) {
			return 0;
		}

		/* Allocate L1SYNC data extension */
		if (! (ppi->ext_data = wrs_shm_alloc(ppsi_head,sizeof(struct l1e_data))) ) {
			return 0;
		}
		/* Set L1SYNC state. Must be done here because the init hook is called only in the initializing state. If
		 * the port is not connected, the initializing is then never called so the L1SYNC state is invalid (0)
		 */
		L1E_DSPOR_BS(ppi)->L1SyncState=L1SYNC_DISABLED;
		L1E_DSPOR_BS(ppi)->L1SyncEnabled=TRUE;
		/* Set L1SYNC extension hooks */
		ppi->ext_hooks=&l1e_ext_hooks;
	}
	return 1;
}
#endif

/**
 * Enable/disable asymmetry correction
 */
void enable_asymmetryCorrection(struct pp_instance *ppi, Boolean enable ) {
	if ( (ppi->asymmetryCorrectionPortDS.enable=enable)==TRUE ) {
		/* Enabled: The delay asymmetry will be calculated */

		ppi->asymmetryCorrectionPortDS.scaledDelayCoefficient =( ppi->cfg.scaledDelayCoefficient != 0) ?
			ppi->cfg.scaledDelayCoefficient :
			(RelativeDifference)(ppi->cfg.delayCoefficient * REL_DIFF_TWO_POW_FRACBITS);
		ppi->portDS->delayAsymCoeff=pp_servo_calculateDelayAsymCoefficient(ppi->asymmetryCorrectionPortDS.scaledDelayCoefficient);
	}
	ppi->asymmetryCorrectionPortDS.constantAsymmetry=picos_to_interval(ppi->cfg.constantAsymmetry_ps);
}

static char *strCodeOpt="CODEOPT=("
#if CONFIG_HAS_CODEOPT_EPC_ENABLED
		" EPC"
#endif
#if CONFIG_HAS_CODEOPT_SO_ENABLED
		" SO"
#endif
#if CONFIG_HAS_CODEOPT_SINGLE_FMASTER
		" SFM"
#endif
#if CONFIG_HAS_CODEOPT_SINGLE_PORT
		" SP"
#endif
		")";

int main(int argc, char **argv)
{
	struct pp_globals *ppg;
	unsigned long seed;
	struct timex t;
	int i, hal_retries;
	struct wrs_shm_head *hal_head;

	setbuf(stdout, NULL);

	pp_printf("PPSi. Commit %s, built on " __DATE__ ", %s\n",
		PPSI_VERSION,
		strCodeOpt);
	/* check if there is another instance of PPSi already running */
	ppsi_head = wrs_shm_get(wrs_shm_ptp, "", WRS_SHM_READ);
	if (!ppsi_head) {
		pp_printf("Unable to open shm for PPSi! Unable to check if "
			  "there is another PPSi instance running. Error: %s\n",
			  strerror(errno));
		exit(1);
	}

	/* check if pid is 0 (shm not filled) or process with provided
	 * pid does not exist (probably crashed) */
	{
		int nbTry=1;

		while ( nbTry >= 0 ) {
			if ((ppsi_head->pid != 0) && (kill(ppsi_head->pid, 0) == 0)) {
				nbTry--;
				sleep(1);
			}
			else
				break;
		}
		if ( nbTry<0 ) {
			wrs_shm_put(ppsi_head);
			pp_printf("Fatal: There is another PPSi instance running. "
				  "Exit...\n\n");
			exit(1);
		}
	}

	/* it will be opened later for write */
	wrs_shm_put(ppsi_head);

	/* try connecting to HAL multiple times in case it's still not ready */
	hal_retries = WRSW_HAL_RETRIES;
	while (hal_retries) { /* may be never, if built without WR extension */
		hal_ch = minipc_client_create(WRSW_HAL_SERVER_ADDR,
					      MINIPC_FLAG_VERBOSE);
		if (hal_ch)
			break;
		hal_retries--;
		usleep(WRSW_HAL_TIMEOUT);
	}

	if (!hal_ch) {
		pp_printf("ppsi: could not connect to HAL RPC");
		exit(1);
	}

	/* If we connected, we also know "for sure" shmem is there */
	hal_head = wrs_shm_get(wrs_shm_hal,"", WRS_SHM_READ);
	if (!hal_head || !hal_head->data_off) {
		pp_printf("ppsi: Can't connect with HAL "
			  "shared memory\n");
		exit(1);
	}
	if (hal_head->version != HAL_SHMEM_VERSION) {
		pp_printf("ppsi: unknown HAL's shm version %i "
			  "(known is %i)\n", hal_head->version,
			  HAL_SHMEM_VERSION);
		exit(1);
	}

	hal_shmem = (void *)hal_head + hal_head->data_off;
	hal_nports = hal_shmem->nports;

	hal_ports = wrs_shm_follow(hal_head, hal_shmem->ports);

	if (!hal_ports) {
		pp_printf("ppsi: unable to follow hal_ports pointer "
			  "in HAL's shmem\n");
		exit(1);
	}

	/* And create your own channel, until we move to shmem too */
	ppsi_ch = minipc_server_create("ptpd", 0);
	if (!ppsi_ch) { /* FIXME should we retry ? */
		pp_printf("ppsi: could not create minipc server");
		exit(1);
	}
	wrs_init_ipcserver(ppsi_ch);

	ppsi_head = wrs_shm_get(wrs_shm_ptp, "ppsi",
				WRS_SHM_WRITE | WRS_SHM_LOCKED);
	if (!ppsi_head) {
		fprintf(stderr, "Fatal: could not create shmem: %s\n",
			strerror(errno));
		exit(1);
	}
	ppsi_head->version = WRS_PPSI_SHMEM_VERSION;

	ppg = wrs_shm_alloc(ppsi_head, sizeof(*ppg));
	ppg->defaultDS = wrs_shm_alloc(ppsi_head, sizeof(*ppg->defaultDS));
	ppg->currentDS = wrs_shm_alloc(ppsi_head, sizeof(*ppg->currentDS));
	ppg->parentDS =  wrs_shm_alloc(ppsi_head, sizeof(*ppg->parentDS));
	ppg->timePropertiesDS = wrs_shm_alloc(ppsi_head,sizeof(*ppg->timePropertiesDS));
	ppg->rt_opts = &__pp_default_rt_opts;

	ppg->max_links = PP_MAX_LINKS;

	ppg->arch_glbl_data = wrs_shm_alloc(ppsi_head, sizeof(wrs_arch_data_t));
	ppg->pp_instances = wrs_shm_alloc(ppsi_head,
				     ppg->max_links * sizeof(struct pp_instance));

	if ((!ppg->arch_glbl_data) || (!ppg->pp_instances)) {
		fprintf(stderr, "ppsi: out of memory\n");
		exit(1);
	}
	/* Set default configuration value for all instances */
	for (i = 0; i < ppg->max_links; i++) {
		memcpy(&INST(ppg, i)->cfg, &__pp_default_instance_cfg,sizeof(__pp_default_instance_cfg));
	}

	/* Set offset here, so config parsing can override it */
	memset(&t, 0, sizeof(t));
	if (adjtimex(&t) >= 0) {
		ppg->timePropertiesDS->currentUtcOffset = (Integer16)t.tai;
	}

	if (pp_parse_cmdline(ppg, argc, argv) != 0)
		return -1;

	/* If no item has been parsed, provide a default file or string */
	if (ppg->cfg.cfg_items == 0)
		pp_config_file(ppg, 0, PP_DEFAULT_CONFIGFILE);
	if (ppg->cfg.cfg_items == 0) {
		/* Default configuration for switch is all ports - Priority given to HA */
		char s[128];

		for (i = 0; i < WRS_NUMBER_PHYSICAL_PORTS; i++) {
			Boolean configured=FALSE;
			if ( CONFIG_HAS_PROFILE_HA )
				sprintf(s, "port %i; iface wri%i; proto raw; profile ha", i + 1, i + 1);
			if ( CONFIG_HAS_PROFILE_WR ) {
				configured=TRUE;
				if ( ! configured )
					sprintf(s, "port %i; iface wri%i; proto raw; profile wr", i + 1, i + 1);
			}
			pp_config_string(ppg, s);
		}
	}
	for (i = 0; i < ppg->nlinks; i++) {
		struct pp_instance *ppi= INST(ppg, i);

		ppi->ch[PP_NP_EVT].fd = -1;
		ppi->ch[PP_NP_GEN].fd = -1;

		ppi->glbs = ppg;
		ppi->vlans_array_len = CONFIG_VLAN_ARRAY_SIZE;
		ppi->iface_name = ppi->cfg.iface_name;
		ppi->port_name = ppi->cfg.port_name;
		ppi->delayMechanism = ppi->cfg.delayMechanism;
		ppi->portDS = wrs_shm_alloc(ppsi_head, sizeof(*ppi->portDS));
		ppi->servo = wrs_shm_alloc(ppsi_head, sizeof(*ppi->servo));
		ppi->ext_hooks=&pp_hooks; /* Default value. Can be overwritten by an extension */
		ppi->ptp_support=TRUE;
		if (ppi->portDS) {
			switch (ppi->cfg.profile) {
			case PPSI_PROFILE_WR :
#if CONFIG_HAS_PROFILE_WR
					ppi->protocol_extension=PPSI_EXT_WR;
					/* Add WR extension portDS */
					if ( !(ppi->portDS->ext_dsport =
							wrs_shm_alloc(ppsi_head, sizeof(struct wr_dsport))) ) {
							goto exit_out_of_memory;
					}

					/* Allocate WR data extension */
					if (! (ppi->ext_data = wrs_shm_alloc(ppsi_head,sizeof(struct wr_data))) ) {
						goto exit_out_of_memory;
					}
					/* Set WR extension hooks */
					ppi->ext_hooks=&wr_ext_hooks;
					enable_asymmetryCorrection(ppi,TRUE);
#else
					fprintf(stderr, "ppsi: Profile WR not supported");
					exit(1);
#endif
				break;
			case PPSI_PROFILE_HA :
#if CONFIG_HAS_PROFILE_HA
				if ( !enable_l1Sync(ppi,TRUE) )
					goto exit_out_of_memory;
				/* Force mandatory attributes - Do not take care of the configuration */
				L1E_DSPOR_BS(ppi)->rxCoherentIsRequired = TRUE;
				L1E_DSPOR_BS(ppi)->txCoherentIsRequired = TRUE;
				L1E_DSPOR_BS(ppi)->congruentIsRequired = TRUE;
				L1E_DSPOR_BS(ppi)->L1SyncEnabled = TRUE;
				L1E_DSPOR_BS(ppi)->optParamsEnabled = FALSE;
				enable_asymmetryCorrection(ppi,TRUE);

#else
				fprintf(stderr, "ppsi: Profile HA not supported");
				exit(1);
#endif
				break;
			case PPSI_PROFILE_PTP :
				/* Do not take care of L1SYNC */
				enable_asymmetryCorrection(ppi,ppi->cfg.asymmetryCorrectionEnable);
				ppi->protocol_extension=PPSI_EXT_NONE;
				break;
			case PPSI_PROFILE_CUSTOM :
#if CONFIG_HAS_PROFILE_CUSTOM
				ppi->protocol_extension=PPSI_EXT_NONE; /* can be changed ...*/
#if CONFIG_HAS_EXT_L1SYNC
				if (ppi->cfg.l1SyncEnabled ) {
					if ( !enable_l1Sync(ppi,TRUE) )
						goto exit_out_of_memory;
					/* Read L1SYNC parameters */
					L1E_DSPOR_BS(ppi)->rxCoherentIsRequired =ppi->cfg.l1SyncRxCoherencyIsRequired;
					L1E_DSPOR_BS(ppi)->txCoherentIsRequired =ppi->cfg.l1SyncTxCoherencyIsRequired;
					L1E_DSPOR_BS(ppi)->congruentIsRequired =ppi->cfg.l1SyncCongruencyIsRequired;
					L1E_DSPOR_BS(ppi)->optParamsEnabled=ppi->cfg.l1SyncOptParamsEnabled;
					if ( L1E_DSPOR_BS(ppi)->optParamsEnabled ) {
						L1E_DSPOR_OP(ppi)->timestampsCorrectedTx=ppi->cfg.l1SyncOptParamsTimestampsCorrectedTx;
					}
				}
				enable_asymmetryCorrection(ppi,ppi->cfg.asymmetryCorrectionEnable);
#endif
#else
					fprintf(stderr, "ppsi: Profile CUSTOM not supported");
					exit(1);
#endif
				break;
			}
			/* Parameters profile independent */
			ppi->timestampCorrectionPortDS.egressLatency=picos_to_interval(ppi->cfg.egressLatency_ps);
			ppi->timestampCorrectionPortDS.ingressLatency=picos_to_interval(ppi->cfg.ingressLatency_ps);
			ppi->timestampCorrectionPortDS.messageTimestampPointLatency=0;
			ppi->portDS->masterOnly= ppi->cfg.masterOnly; /* can be overridden in pp_init_globals() */
		} else {
			goto exit_out_of_memory;
		}

		/* The following default names depend on TIME= at build time */
		ppi->n_ops = &DEFAULT_NET_OPS;
		ppi->t_ops = &DEFAULT_TIME_OPS;

		ppi->__tx_buffer = malloc(PP_MAX_FRAME_LENGTH);
		ppi->__rx_buffer = malloc(PP_MAX_FRAME_LENGTH);

		if (!ppi->__tx_buffer || !ppi->__rx_buffer) {
			goto exit_out_of_memory;
		}
	}

	pp_init_globals(ppg, &__pp_default_rt_opts);

	{
		int nbRetry;
		int enablePPS;
		wrh_timing_mode_pll_state_t timing_mode_pll_state;
		struct pp_instance *ppi=INST(ppg,0);
		wrh_timing_mode_t current_timing_mode;
		int ret=WRH_OPER()->get_timing_mode(ppg,&current_timing_mode);

		if (ret<0) {
			fprintf(stderr, "ppsi: Cannot get current timing mode\n");
			exit(1);
		}

		WRS_ARCH_G(ppg)->timingModeLockingState=WRH_TM_LOCKING_STATE_LOCKING;

		switch (current_timing_mode) {
		case WRH_TM_FREE_MASTER :
			// FR mode is OK for starting in all cases. We are not going to touch it
			// -> GM will be set in the main loop
			// -> BC will be set when a port will become slave
			WRS_ARCH_G(ppg)->timingMode=WRH_TM_FREE_MASTER; // set here because set_timing_mode() is not called
			break;
		case WRH_TM_GRAND_MASTER :
			if ( ppg->defaultDS->clockQuality.clockClass == PP_PTP_CLASS_GM_LOCKED  ) {
				// Already the correct timing mode. Not touched to avoid an unlock of the PLL
				WRS_ARCH_G(ppg)->timingMode=WRH_TM_GRAND_MASTER; // set here because set_timing_mode() is not called
				break;
			}
			// No break here to set the timing mode to FR
		case WRH_TM_BOUNDARY_CLOCK :
		case WRH_TM_DISABLED :
			// Must be reseted to FR
			WRH_OPER()->set_timing_mode(ppg,WRH_TM_FREE_MASTER);
			break;
		}

		/* Waiting for PLL locking. We do not need a precise time-out here */
		/* We are waiting up to 3s for PLL locking.
		 * We do that to avoid to jump too quickly to a degraded clock class.
		 */
		nbRetry=2;
		while(nbRetry>0) {
			int ret=WRH_OPER()->get_timing_mode_state(ppg,&timing_mode_pll_state);
			if ( ret==0 && timing_mode_pll_state==WRH_TM_PLL_STATE_LOCKED )
				break;
			sleep(1); // wait 1s
			nbRetry--;
		}
		if ( timing_mode_pll_state==WRH_TM_PLL_STATE_UNLOCKED) {
				WRS_ARCH_G(ppg)->timingModeLockingState = WRH_TM_LOCKING_STATE_LOCKING;
		} else if (timing_mode_pll_state==WRH_TM_PLL_STATE_LOCKED) {
			TOPS(ppi)->set(ppi,NULL); // GM locked: set the time
			WRS_ARCH_G(ppg)->timingModeLockingState = WRH_TM_LOCKING_STATE_LOCKED;
		}

		/* Enable the PPS generation only if
		 * - Grand master and PLL is locked
		 * OR
		 * - Free running master (no condition required)
		 * OR
		 * - Timing output is forced (for testing only)
		 */
		enablePPS=(WRS_ARCH_G(ppg)->timingModeLockingState== WRH_TM_LOCKING_STATE_LOCKED &&
				ppg->defaultDS->clockQuality.clockClass == PP_PTP_CLASS_GM_LOCKED) ||
				GOPTS(ppg)->forcePpsGen;
		TOPS(ppi)->enable_timing_output(ppg,enablePPS);
	}

	seed = (unsigned long) time(NULL);
	if (getenv("PPSI_DROP_SEED"))
		seed = (unsigned long) atoi(getenv("PPSI_DROP_SEED"));
	ppsi_drop_init(ppg, seed);

	/* release lock from wrs_shm_get */
	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);

	wrs_main_loop(ppg);
	return 0; /* never reached */

	exit_out_of_memory:;
	fprintf(stderr, "ppsi: out of memory\n");
	exit(1);
}
