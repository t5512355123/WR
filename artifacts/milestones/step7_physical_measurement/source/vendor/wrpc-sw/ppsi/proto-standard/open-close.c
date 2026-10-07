/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>

/*
 * This is a global structure, because commandline and other config places
 * need to change some values in there.
 */
struct pp_runtime_opts __pp_default_rt_opts = {
	.clock_quality_clockClass = PP_CLASS_DEFAULT,
	.clock_quality_clockAccuracy = CONFIG_PTP_OPT_CLOCK_ACCURACY, // Not defined
	.clock_quality_offsetScaledLogVariance = CONFIG_PTP_OPT_CLOCK_ALLAN_VARIANCE, // Not defined
	.timeSource = CONFIG_PTP_OPT_TIME_SOURCE, // Not defined
	.ptpTimeScale=-1, // Not defined
	.frequencyTraceable=-1, // Not defined
	.timeTraceable=-1, // Not defined
	.flags =		PP_DEFAULT_FLAGS,
	.ap =			PP_DEFAULT_AP,
	.ai =			PP_DEFAULT_AI,
	.s =			PP_DEFAULT_DELAY_S,
	.priority1 =		PP_DEFAULT_PRIORITY1,
	.priority2 =		PP_DEFAULT_PRIORITY2,
	.domainNumber =	PP_DEFAULT_DOMAIN_NUMBER,
	.ttl =			PP_DEFAULT_TTL,
	.externalPortConfigurationEnabled = PP_DEFAULT_EXT_PORT_CONFIG_ENABLE,
	.ptpPpsThresholdMs=PP_DEFAULT_PTP_PPSGEN_THRESHOLD_MS,
	.gmDelayToGenPpsSec=PP_DEFAULT_GM_DELAY_TO_GEN_PPS_SEC,
	.forcePpsGen=    FALSE,
	.ptpFallbackPpsGen=FALSE,
	.slaveOnly=FALSE

};

/* Default values used to fill configurable parameters associated to each instance */
/* These parameters can be then overwritten with the config file ppsi.conf */
const struct pp_instance_cfg __pp_default_instance_cfg = {
		.profile=PPSI_PROFILE_PTP,
		.delayMechanism = MECH_E2E,
		.announce_interval=PP_DEFAULT_ANNOUNCE_INTERVAL,
		.announce_receipt_timeout=PP_DEFAULT_ANNOUNCE_RECEIPT_TIMEOUT,
		.sync_interval=PP_DEFAULT_SYNC_INTERVAL,
		.min_delay_req_interval=PP_DEFAULT_MIN_DELAY_REQ_INTERVAL,
		.min_pdelay_req_interval=PP_DEFAULT_MIN_PDELAY_REQ_INTERVAL,
#if CONFIG_HAS_EXT_L1SYNC
		.l1SyncEnabled=FALSE,
		.l1SyncRxCoherencyIsRequired=FALSE,
		.l1SyncTxCoherencyIsRequired=FALSE,
		.l1SyncCongruencyIsRequired=FALSE,
		.l1SyncOptParamsEnabled=FALSE,
		.l1SyncOptParamsTimestampsCorrectedTx=FALSE,
		.l1syncInterval=L1E_DEFAULT_L1SYNC_INTERVAL,
		.l1syncReceiptTimeout=L1E_DEFAULT_L1SYNC_RECEIPT_TIMEOUT,
#endif
		.asymmetryCorrectionEnable=FALSE,
		.egressLatency_ps=0,
		.ingressLatency_ps=0,
		.constantAsymmetry_ps=0,
		.scaledDelayCoefficient=0,
		.delayCoefficient=0,
		.desiredState=PPS_PASSIVE, /* Clause 17.3.6.2 ; The default value should be PASSIVE unless otherwise specified */
		.masterOnly=FALSE
};

/*
 * This file deals with opening and closing an instance. The channel
 * must already have been created. In practice, this initializes the
 * state machine to the first state.
 */

int pp_init_globals(struct pp_globals *ppg, struct pp_runtime_opts *pp_rt_opts)
{
	/*
	 * Initialize default data set
	 */
	int i,ret=0;
	defaultDS_t *def = ppg->defaultDS;
	struct pp_runtime_opts *rt_opts;

	/* if ppg->nlinks == 0, let's assume that the 'pp_links style'
	 * configuration was not used, so we have 1 port */
	def->numberPorts = ppg->nlinks > 0 ? ppg->nlinks : 1;

	if (!ppg->rt_opts)
		ppg->rt_opts = pp_rt_opts;

	rt_opts = ppg->rt_opts;

	// Update the default attributes depending on the clock class in the configuration structure
	bmc_set_default_device_attributes(ppg);
	// Update defaultDS & timePropertiesDS with configured setting (clockClass,...)
	bmc_apply_configured_device_attributes(ppg);

	/* Clause 17.6.5.3 : Clause 9.2.2 shall not be in effect. If implemented, defaultDS.slaveOnly should be FALSE, and
	 * portDS.masterOnly should be FALSE on all PTP Ports of the PTP Instance.
	 */
	def->externalPortConfigurationEnabled=pp_rt_opts->externalPortConfigurationEnabled;
	def->slaveOnly=rt_opts->slaveOnly;
	if ( is_externalPortConfigurationEnabled(def) ) {
		if (is_slaveOnly(def)) {
			pp_printf("ppsi: Incompatible configuration: SlaveOnly  and externalPortConfigurationEnabled\n");
			def->slaveOnly=FALSE;
		}
	}
	def->slaveOnly=is_slaveOnly(def); // Done to take into code optimization in is_slaveOnly() macro

	if ( is_slaveOnly(def) ) {
		if ( get_numberPorts(def) > 1 ) {
			/* Check if slaveOnly is allowed
			 * Only one ppsi instance must exist however n instances on the same physical port
			 * and  using the same protocol must be considered as one. We do this because these
			 * instances are exclusive and will be never enabled at the same time
			 */
			struct pp_instance *ppi = INST(ppg, 0);
			for (i = 1; i < get_numberPorts(def); i++) {
				struct pp_instance *ppi_cmp = INST(ppg, i);
				if ( ppi->proto != ppi_cmp->proto /* different protocol used */
						|| strcmp(ppi->cfg.iface_name,ppi_cmp->cfg.iface_name)!=0 /* Not the same interface */
					) {
					/* remove slaveOnly */
					def->slaveOnly = 0;
					pp_printf("ppsi: SlaveOnly cannot be applied. It is not a ordinary clock\n");
					break; /* No reason to continue */
				}
			}
		}
		if ( is_slaveOnly(def) ) {
			/* Configured clockClass must be also changed to avoid to be set by BMCA bmc_update_clock_quality() */
			rt_opts->clock_quality_clockClass =
					def->clockQuality.clockClass = PP_CLASS_SLAVE_ONLY;
			pp_printf("Slave Only, clock class set to %d\n", def->clockQuality.clockClass);
		}

	}

	for (i = 0; i < get_numberPorts(def); i++) {
		struct pp_instance *ppi = INST(ppg, i);

		ppi->state = PPS_DISABLED;
		ppi->pdstate = PP_PDSTATE_NONE;
		ppi->current_state_item = NULL;
		ppi->port_idx = i;
		ppi->frgn_rec_best = -1;
		pp_timeout_disable_all(ppi); /* By default, disable all timers */
	}

	if ( is_externalPortConfigurationEnabled(GDSDEF(ppg)) ) {
		Boolean isSlavePresent=FALSE;

		for (i = 0; i < get_numberPorts(def); i++) {
			struct pp_instance *ppi = INST(ppg, i);
			Enumeration8 desiradedState=ppi->cfg.desiredState;

			/* Clause 17.6.5.3 : - Clause 9.2.2 shall not be in effect */
			if (is_masterOnly(ppi->portDS)) {
				/* priority given to externalPortConfigurationEnabled */
				ppi->portDS->masterOnly=FALSE;
				pp_printf("ppsi: Wrong configuration: externalPortConfigurationEnabled=masterOnly=TRUE. masterOnly set to FALSE\n");
			}
			ppi->externalPortConfigurationPortDS.desiredState =desiradedState ;
			isSlavePresent|=desiradedState==PPS_SLAVE || desiradedState==PPS_UNCALIBRATED;
		}
		if ( def->clockQuality.clockClass < 128 && isSlavePresent) {
			/* clockClass cannot be < 128 if a port is configured as slave */
			/* Configured clockClass must be also changed to avoid to be set by BMCA bmc_update_clock_quality() */
			rt_opts->clock_quality_clockClass =
					def->clockQuality.clockClass=PP_CLASS_DEFAULT;
			pp_printf("PPSi: GM clock set but slave present. Clock class set to %d\n", def->clockQuality.clockClass);
		}
	}

	for (i = 0; i < get_numberPorts(def); i++) {
		struct pp_instance *ppi = INST(ppg, i);
		int r;

		if (is_ext_hook_available(ppi,open)) {
		   ret=(r=ppi->ext_hooks->open(ppi, rt_opts))==0 ? ret : r;
		}
	}
	return ret;
}

int pp_close_globals(struct pp_globals *ppg)
{
	int i,ret=0;;
	defaultDS_t *def = ppg->defaultDS;

	for (i = 0; i < get_numberPorts(def); i++) {
		struct pp_instance *ppi = INST(ppg, i);
		int r;

		if (is_ext_hook_available(ppi,close) ){
		   ret=(r=ppi->ext_hooks->close(ppi))==0 ? ret : r;
		}
	}
	return ret;

}
