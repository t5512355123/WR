#include <ppsi/ppsi.h>

/* ext-whiterabbit must offer its own hooks */

// Used to store data in the ext_specific field of the pp_frgn_master an MsgAnnounce structure
// This structure must not exceed the size of an 'MsgAnnounce.ext_specific'
typedef struct {
	UInteger16 notTreated; /* The WR flags must be treated only one time */
	UInteger16 wrFlags;
}wr_announce_field_t;

#if 0
// Useful function used for debugging
#include <stdio.h>
static char * getPortIdentityAsString ( PortIdentity *pid, UInteger16 seqId) {
	static char text[52];

	sprintf(text,"%02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x %04x %d",
			pid->clockIdentity.id[0], pid->clockIdentity.id[1],
			pid->clockIdentity.id[2], pid->clockIdentity.id[3],
			pid->clockIdentity.id[4], pid->clockIdentity.id[5],
			pid->clockIdentity.id[6], pid->clockIdentity.id[7],
			pid->portNumber, seqId);
	return text;
}
#endif

static int wr_init(struct pp_instance *ppi, void *buf, int len)
{
	pp_diag(ppi, ext, 2, "hook: %s\n", __func__);

	pp_timeout_get_timer(ppi,PP_TO_WR_EXT_0,TO_RAND_NONE);

	wr_reset_process(ppi,WR_ROLE_NONE);
	ppi->pdstate = PP_PDSTATE_WAIT_MSG;

#ifdef CONFIG_ABSCAL
	/* absolute calibration only exists in arch-wrpc, so far */
	if (wrc_ptp_is_abscal())
		ppi->next_state = WRS_WR_LINK_ON;
#endif

	return 0;
}

/* open hook called only for each WR pp_instances */
static int wr_open(struct pp_instance *ppi, struct pp_runtime_opts *rt_opts)
{
	pp_diag(NULL, ext, 2, "hook: %s\n", __func__);

	if ( is_slaveOnly(DSDEF(ppi)) ||
			( is_externalPortConfigurationEnabled(DSDEF(ppi)) &&
					ppi->externalPortConfigurationPortDS.desiredState==PPS_SLAVE)
	   ){
		WR_DSPOR(ppi)->wrConfig = WR_S_ONLY;
	} else {
		WR_DSPOR(ppi)->wrConfig = (is_masterOnly(ppi->portDS) ||
				( is_externalPortConfigurationEnabled(DSDEF(ppi)) &&
						ppi->externalPortConfigurationPortDS.desiredState==PPS_MASTER)) ?
								WR_M_ONLY :
								WR_M_AND_S;
	}
	return 0;
}

static int wr_handle_resp(struct pp_instance *ppi)
{
	pp_diag(ppi, ext, 2, "hook: %s\n", __func__);

	/* This correction_field we received is already part of t4 */
	if ( ppi->extState==PP_EXSTATE_ACTIVE ) {
		wr_servo_got_resp(ppi);
		if ( ppi->pdstate==PP_PDSTATE_PDETECTED)
			pdstate_set_state_pdetected(ppi); // Maintain state Protocol detected on MASTER side
	}
	else {
		pp_servo_got_resp(ppi,OPTS(ppi)->ptpFallbackPpsGen);
	}
	return 0;
}

static int wr_handle_dreq(struct pp_instance *ppi)
{
	pp_diag(ppi, ext, 2, "hook: %s\n", __func__);
	if ( ppi->extState==PP_EXSTATE_ACTIVE ) {
		if ( ppi->pdstate==PP_PDSTATE_PDETECTED)
			pdstate_set_state_pdetected(ppi); // Maintain state Protocol detected on MASTER side
	}

	return 0;
}

static int  wr_sync_followup(struct pp_instance *ppi) {

	if ( ppi->extState==PP_EXSTATE_ACTIVE ) {
		wr_servo_got_sync(ppi);
	}
	else {
		pp_servo_got_sync(ppi,OPTS(ppi)->ptpFallbackPpsGen);
	}
	return 1; /* the caller returns too */
}

static int wr_handle_sync(struct pp_instance *ppi)
{
	/* This handle is called in case of one step clock */
	pp_diag(ppi, ext, 2, "hook: %s\n", __func__);
	return wr_sync_followup(ppi);
}

static int wr_handle_followup(struct pp_instance *ppi)
{
	/* This handle is called in case of two step clock */
	pp_diag(ppi, ext, 2, "hook: %s\n", __func__);
	return wr_sync_followup(ppi);
}

__attribute__((unused)) static int wr_handle_presp(struct pp_instance *ppi)
{
	if ( ppi->extState==PP_EXSTATE_ACTIVE ) {
		wr_servo_got_presp(ppi);
		if ( ppi->pdstate==PP_PDSTATE_PDETECTED)
			pdstate_set_state_pdetected(ppi); // Maintain state Protocol detected on MASTER side
	}
	else
		pp_servo_got_presp(ppi);
	return 0;
}

static int wr_pack_announce(struct pp_instance *ppi)
{
	pp_diag(ppi, ext, 2, "hook: %s\n", __func__);
	/* Even though the extension is disable we continue to send WR TLV */
	if ( WR_DSPOR(ppi)->wrConfig != WR_S_ONLY) {
		msg_pack_announce_wr_tlv(ppi);
		return WR_ANNOUNCE_LENGTH;
	}
	return PP_ANNOUNCE_LENGTH;
}

static void wr_unpack_announce(struct pp_instance *ppi,void *buf, MsgAnnounce *ann)
{
	int msg_len = ntohs(*(UInteger16 *) (buf + 2));
	wr_announce_field_t *wrExtSpec=(wr_announce_field_t *)&ann->ext_specific[0];

	pp_diag(ppi, ext, 2, "hook: %s\n", __func__);
	UInteger16 wr_flags=0;

	if ( msg_len >= WR_ANNOUNCE_LENGTH )
		msg_unpack_announce_wr_tlv(buf, ann, &wr_flags);
	wrExtSpec->notTreated=TRUE;
	wrExtSpec->wrFlags=wr_flags;
}

// Called by S1 treatment (BMCA or slave state)
// Assumptions when this hook is called
// - State= Slave or Uncalibrated
// - frgn_master passed in parameter is the erBest
// - WR data field of the announce message is stored in the field ext_specific of the frgn_master


static int wr_bmca_s1(struct pp_instance * ppi,
		      struct pp_frgn_master *frgn_master)
{
	struct wr_dsport *wrp = WR_DSPOR(ppi);
	Boolean newParentDectected;

	pp_diag(ppi, ext, 2, "hook: %s\n", __func__);
	wr_announce_field_t *wrExtSpec=(wr_announce_field_t *)frgn_master->ext_specific;

	if ( wrExtSpec->notTreated ) {
		wrh_servo_t *s=WRH_SRV(ppi);
		UInteger16 wr_flags=wrExtSpec->wrFlags;
		Boolean parentIsWRnode=(wr_flags & WR_NODE_MODE)!=NON_WR;
		int samePid=0;
		Boolean contSeqId=FALSE;

		if ( !s->doRestart ) {
			samePid= bmc_pidcmp(&frgn_master->receivePortIdentity, &wrp->parentAnnPortIdentity)==0;
			if (samePid ) {
				// We check for a continuous sequence ID (With a margin of 1)
				contSeqId=frgn_master->sequenceId==(UInteger16) (wrp->parentAnnSequenceId+1) ||
						frgn_master->sequenceId==(UInteger16) (wrp->parentAnnSequenceId+2);
			}
			newParentDectected = !samePid  ||(samePid && !contSeqId);
		} else {
			// Force a restart - simulate a new parent
			s->doRestart=FALSE;
			newParentDectected=TRUE;
		}

		if ( parentIsWRnode ) {
			// Announce message from a WR node

			if ( newParentDectected && wrp->parentDetection!=PD_WR_PARENT ) {
				// New WR parent detected - keep only wrConfig part
				wr_flags&=WR_NODE_MODE;

				// Check if parent is WR Master-enabled
				if ( wr_flags==WR_MASTER || wr_flags==WR_M_AND_S ) {

					wrp->parentDetection=PD_WR_PARENT;
				}
			}
		} else	{
			if ( newParentDectected && wrp->parentDetection!=PD_NOT_WR_PARENT ) {
				wrp->parentDetection=PD_NOT_WR_PARENT;
			}
			wr_flags=0;
		}

		// Update WR parent flags
		wrp->parentIsWRnode = (wr_flags & WR_NODE_MODE)!=NON_WR;
		wrp->parentWrModeOn = (wr_flags & WR_IS_WR_MODE) != 0;
		wrp->parentCalibrated =(wr_flags & WR_IS_CALIBRATED) != 0;
		wrp->parentWrConfig = wr_flags & WR_NODE_MODE;

		// Save parent identity and the sequence Id to be used next time
		memcpy(&wrp->parentAnnPortIdentity,&frgn_master->receivePortIdentity,sizeof(PortIdentity));
		wrp->parentAnnSequenceId=frgn_master->sequenceId;

		wrExtSpec->notTreated=0;
	}
	return 0;
}


static void wr_state_change(struct pp_instance *ppi)
{
	struct wr_dsport *wrp = WR_DSPOR(ppi);
	
	pp_diag(ppi, ext, 2, "hook: %s\n", __func__);

	if (ppi->state == PPS_SLAVE &&
			ppi->next_state==PPS_UNCALIBRATED &&
			wrp->parentIsWRnode) {
		pdstate_enable_extension(ppi); // Re-enable the extension
	}

	if ( ppi->extState==PP_EXSTATE_ACTIVE ) {

		// Check leaving state
		if ( wrp->wrModeOn &&
				((ppi->state == PPS_SLAVE) ||
						(ppi->state == PPS_MASTER))) {
			/* if we are leaving the MASTER or SLAVE state */
			wr_reset_process(ppi,WR_ROLE_NONE);
		}

		// Check entering state
		switch (ppi->next_state) {
		case PPS_MASTER : /* Enter in MASTER_STATE */
			wrp->next_state=WRS_IDLE;
			wr_reset_process(ppi,WR_MASTER);
			break;
		case PPS_UNCALIBRATED : /* Enter in UNCALIBRATED state */
			if ( ppi->state == PPS_SLAVE ) {
				// This part must be done if doRestart() is called in the servo
				if ( wrp->parentWrConfig==WR_MASTER || wrp->parentWrConfig==WR_M_AND_S ) {
					wrp->next_state=WRS_PRESENT;
					wr_reset_process(ppi,WR_SLAVE);
				}
			} else {
				// This force the transition from UNCALIBRATED to SLAVE at startup if
				// no parent is detected.
				if ( !(wrp->parentWrConfig==WR_MASTER || wrp->parentWrConfig==WR_M_AND_S) ) {
					wr_handshake_fail(ppi);
				}
			}
			break;
		case PPS_LISTENING : /* Enter in LISTENING state */
			wr_reset_process(ppi,WR_ROLE_NONE);
			break;
		}

	} else {
		wr_reset_process(ppi,WR_ROLE_NONE);
	}

	if (ppi->state == PPS_SLAVE) {
		/* We are leaving SLAVE state, so we must reset locking
		 * This must be done on all cases (extension ACTIVE or NOT) because it may be possible we entered
		 * in SLAVE state with the extension active and now it can be inactive
		 */
		WRH_OPER()->locking_reset(ppi);
		if ( ppi->next_state!=PPS_UNCALIBRATED ) {
			/* Leave SLAVE/UNCALIB states : We must stop the PPS generation */
			if ( !GOPTS(GLBS(ppi))->forcePpsGen )
				TOPS(ppi)->enable_timing_output(GLBS(ppi),0);
		}
	}
}

int wr_ready_for_slave(struct pp_instance *ppi) {
	if ( ppi->extState==PP_EXSTATE_ACTIVE ) {
		struct wr_dsport *wrp = WR_DSPOR(ppi);
		return wrp->wrModeOn && wrp->parentWrModeOn && wrp->state == WRS_IDLE;
	} else
		return 1; /* Allow to go to slave state as we will not do a WR handshake */
}


static int wr_require_precise_timestamp(struct pp_instance *ppi) {
	return ppi->extState==PP_EXSTATE_ACTIVE && WR_DSPOR(ppi)->wrModeOn;
}

static int wr_get_tmo_lstate_detection(struct pp_instance *ppi) {
	/* The WR protocol detection comes :
	 * - for a SLAVE: from the announce message (WR TLV)
	 * - for a MASTER: from the reception of the WR_PRESENT message
	 * To cover this 2 cases we will use 2 times the announce receipt time-out
	 */
	return is_externalPortConfigurationEnabled(DSDEF(ppi)) ?
			20000 : /* 20s: externalPortConfiguration enable means no ANN_RECEIPT timeout */
			pp_timeout_get(ppi,PP_TO_ANN_RECEIPT)<<3;
}

static TimeInterval wr_get_latency (struct pp_instance *ppi) {
	return 0;
}

/* WR extension is not compliant with the standard concerning the contents of the correction fields */
static int wr_is_correction_field_compliant (struct pp_instance *ppi) {
	return 0;
}

static int wr_extension_state_changed( struct pp_instance * ppi) {
	if ( ppi->extState==PP_EXSTATE_DISABLE || ppi->extState==PP_EXSTATE_PTP) {
		wr_reset_process(ppi,WR_ROLE_NONE);
	}
	return 0;
}

static int wr_new_slave (struct pp_instance *ppi, void *buf, int len) {
	if ( ppi->extState==PP_EXSTATE_ACTIVE ) {
		wr_servo_init(ppi);

		/* To avoid comparison of sequenceId with parentAnnSequenceId
		 * and portIndentity with parentAnnPortIdentity set
		 * doRestart as TRUE*/
		if (ppi->ext_data)
			WRH_SRV(ppi)->doRestart = TRUE;

	}
	return 0;
}


const struct pp_ext_hooks wr_ext_hooks = {
	.init = wr_init,
	.open = wr_open,
	.handle_resp = wr_handle_resp,
	.handle_dreq = wr_handle_dreq,
	.handle_sync = wr_handle_sync,
	.handle_followup = wr_handle_followup,
	.ready_for_slave = wr_ready_for_slave,
	.run_ext_state_machine = wr_run_state_machine,
	.new_slave = wr_new_slave,
#if CONFIG_HAS_P2P
	.handle_presp = wr_handle_presp,
#endif
	.pack_announce = wr_pack_announce,
	.unpack_announce = wr_unpack_announce,
	.state_change = wr_state_change,
	.servo_reset= wr_servo_reset,
	.require_precise_timestamp=wr_require_precise_timestamp,
	.get_tmo_lstate_detection=wr_get_tmo_lstate_detection,
	.get_ingress_latency=wr_get_latency,
	.get_egress_latency=wr_get_latency,
	.is_correction_field_compliant=wr_is_correction_field_compliant,
	.extension_state_changed= wr_extension_state_changed,
	.bmca_s1=wr_bmca_s1
};
