/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on PTPd project v. 2.1.0 (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>

/*
 * Initialize parentDS
 */
static void init_parent_ds(struct pp_instance *ppi)
{	

	/* 8.2.3.2 */
	DSPAR(ppi)->parentPortIdentity.clockIdentity =
		DSDEF(ppi)->clockIdentity;
	DSPAR(ppi)->parentPortIdentity.portNumber = 0;
	/* 8.2.3.3 skipped (parentStats is not used) */
	/* 8.2.3.4 */
	DSPAR(ppi)->observedParentOffsetScaledLogVariance = 0xffff;
	/* 8.2.3.5 */
	DSPAR(ppi)->observedParentClockPhaseChangeRate = 0x7fffffffUL;
	/* 8.2.3.6 */
	DSPAR(ppi)->grandmasterIdentity = DSDEF(ppi)->clockIdentity;
	/* 8.2.3.7 */
	DSPAR(ppi)->grandmasterClockQuality = DSDEF(ppi)->clockQuality;
	/* 8.2.3.8 */
	DSPAR(ppi)->grandmasterPriority1 = DSDEF(ppi)->priority1;
	/* 8.2.3.9 */
	DSPAR(ppi)->grandmasterPriority2 = DSDEF(ppi)->priority2;
}

/*
 * Initializes network and other stuff
 */

int pp_initializing(struct pp_instance *ppi, void *buf, int len)
{
	portDS_t *port = DSPOR(ppi);
	struct pp_globals *ppg = GLBS(ppi);
	int ret = 0;
	int i;
	int initds = 1;

	if ( ppg->rt_opts->clock_quality_clockClass == PP_PTP_CLASS_GM_LOCKED  &&
			DSDEF(ppi)->clockQuality.clockClass != PP_PTP_CLASS_GM_LOCKED) {
		// GM not locked
		goto failure;
	}
	if (ppi->n_ops->init(ppi) < 0) /* it must handle being called twice */
		goto failure;

	/* only fill in the data set when initializing */
	if ( get_numberPorts(GDSDEF(ppg)) > 1) {
		for (i = 0; i < get_numberPorts(GDSDEF(ppg)); i++) {
			if ((INST(ppg, i)->state != PPS_INITIALIZING) && (INST(ppg, i)->link_up == TRUE)) 
				initds = 0;
		}			
	}
					
	/*
	 * Initialize default and parent data set
	 */
	if (initds) 
	{
		unsigned char mac_port1[PP_MAC_ADRESS_SIZE];
		unsigned char *mac;
		unsigned char *pci;
		unsigned char portIdx=ppi-ppi->glbs->pp_instances;

		if (get_numberPorts(GDSDEF(ppg)) > 1 && portIdx!=0) {
			/* Clock identity comes from mac address with 0xff:0xfe intermixed */
			/* calculate MAC of Port 0 */

			unsigned char *mac = ppi->ch[PP_NP_GEN].addr;
			unsigned char remainder = portIdx;
			for (i = sizeof(mac_port1)-1; i >= 0; i--) {
				mac_port1[i] = mac[i] - remainder;
				if (mac[i] >= remainder)
					remainder = 0;
				else
					remainder = 1;
			}
		} else {
			memcpy (mac_port1,ppi->ch[PP_NP_GEN].addr,sizeof(mac_port1));
		}
		pci=DSDEF(ppi)->clockIdentity.id;
		mac=mac_port1;
		*(pci++)=*(mac++);*(pci++)=*(mac++); *(pci++)=*(mac++);
		*(pci++)= 0xff;
		*(pci++)= 0xfe;
		*(pci++)=*(mac++); *(pci++)=*(mac++); *pci=*mac;

		init_parent_ds(ppi);
	}
		
	/*
	 * Initialize port data set
	 */
	memcpy(&port->portIdentity.clockIdentity,
		&DSDEF(ppi)->clockIdentity, PP_CLOCK_IDENTITY_LENGTH);
	/* 1-based port number =  index of this ppi in the global array */
	port->portIdentity.portNumber = 1 + ppi - ppi->glbs->pp_instances;
	port->versionNumber = PP_VERSION_PTP;
	port->minorVersionNumber = PP_MINOR_VERSION_PTP;

	/* Init timers */
	port->logAnnounceInterval=(Integer8)ppi->cfg.announce_interval;
	port->announceReceiptTimeout=(UInteger8)ppi->cfg.announce_receipt_timeout;
	port->logSyncInterval=(Integer8)ppi->cfg.sync_interval;
	port->logMinDelayReqInterval=(Integer8)ppi->cfg.min_delay_req_interval;
	port->logMinPdelayReqInterval=(Integer8)ppi->cfg.min_pdelay_req_interval;
	pp_timeout_init(ppi);
	pp_timeout_setall(ppi);

	/* Foreign master time window */
	ppi->frgn_master_time_window_ms= pp_timeout_log_to_ms(DSPOR(ppi)->logAnnounceInterval)*PP_FOREIGN_MASTER_TIME_WINDOW;

	ppi->pdstate = PP_PDSTATE_NONE; // Default value for PTP. Can be overwritten in specific init
	ppi->extState=(ppi->protocol_extension==PPSI_EXT_NONE) ? PP_EXSTATE_DISABLE : PP_EXSTATE_ACTIVE;

	if (is_ext_hook_available(ppi,init))
		ret = ppi->ext_hooks->init(ppi, buf, len);
	if (ret) {
		pp_diag(ppi, ext, 1, "%s: can't init extension\n", __func__);
		goto failure;
	}

	pp_diag(ppi, bmc, 1, "clock class = %d\n",
			DSDEF(ppi)->clockQuality.clockClass);
	pp_diag(ppi, bmc, 1, "clock accuracy = %d\n",
			DSDEF(ppi)->clockQuality.clockAccuracy);

	msg_init_header(ppi, ppi->tx_ptp); /* This is used for all tx */
	
#ifdef CONFIG_ABSCAL
	/* absolute calibration only exists in arch-wrpc, so far */
	if (wrc_ptp_is_abscal()) {
		ppi->next_state = PPS_ABSCAL;
		return 0;
	}
#endif
	if (is_externalPortConfigurationEnabled(DSDEF(ppi))) {
		/* Clause 17.6.5.2 : the member portDS.portState shall be set to
		 * the value of the member externalPortConfigurationPortDS.desiredState
		 */
		Enumeration8 desiredState=ppi->externalPortConfigurationPortDS.desiredState;

		if ( DSDEF(ppi)->clockQuality.clockClass<128  &&
				(desiredState == PPS_SLAVE || desiredState == PPS_UNCALIBRATED)
				) {
			ppi->next_state=PPS_FAULTY;
		} else {
			if ( ppi->externalPortConfigurationPortDS.desiredState==PPS_SLAVE) {
				ppi->next_state=PPS_UNCALIBRATED;
			}
			else
				ppi->next_state = ppi->externalPortConfigurationPortDS.desiredState;
		}
	}
	else
		ppi->next_state = PPS_LISTENING;


	return 0;

failure:
	ppi->next_delay = 1000; /* wait 1s before retrying */
	return 0;
}
