#include <stdio.h>
#include <ppsi/ppsi.h>
#include <ppsi-wrs.h>
#include <time_lib.h>
#include "dump-info_ppsi.h"
#include "wrs_dump_shmem.h"

/* map for fields of ppsi structures */
#undef DUMP_STRUCT
#define DUMP_STRUCT struct pp_globals
struct dump_info ppg_info [] = {
	DUMP_FIELD(pointer, pp_instances),	/* FIXME: follow this */
	DUMP_FIELD(pointer, rt_opts),
	DUMP_FIELD(pointer, defaultDS),
	DUMP_FIELD(pointer, currentDS),
	DUMP_FIELD(pointer, parentDS),
	DUMP_FIELD(pointer, timePropertiesDS),
	DUMP_FIELD(int, ebest_idx),
	DUMP_FIELD(int, ebest_updated),
	DUMP_FIELD(int, nlinks),
	DUMP_FIELD(int, max_links),
	/* substructure pp_globals_cfg */
	DUMP_FIELD(int, cfg.cfg_items),
	DUMP_FIELD(int, cfg.cur_ppi_n),
	
	DUMP_FIELD(int, rxdrop),
	DUMP_FIELD(int, txdrop),
	DUMP_FIELD(pointer, arch_glbl_data),
	DUMP_FIELD(pointer, global_ext_data),
};

#undef DUMP_STRUCT
#define DUMP_STRUCT defaultDS_t /* Horrible typedef */
struct dump_info dsd_info [] = {
	DUMP_FIELD(ClockIdentity, clockIdentity),
	DUMP_FIELD(UInteger16, numberPorts),
	DUMP_FIELD(ClockQuality, clockQuality),
	DUMP_FIELD(UInteger8, priority1),
	DUMP_FIELD(UInteger8, priority2),
	DUMP_FIELD(UInteger8, domainNumber),
	DUMP_FIELD(yes_no_Boolean, slaveOnly),
	DUMP_FIELD(Timestamp, currentTime),
	DUMP_FIELD(yes_no_Boolean, instanceEnable),
	DUMP_FIELD(yes_no_Boolean, externalPortConfigurationEnabled),
	DUMP_FIELD(Enumeration8, maxStepsRemoved),
	DUMP_FIELD(Enumeration8, instanceType),
};

#undef DUMP_STRUCT
#define DUMP_STRUCT currentDS_t/* Horrible typedef */
struct dump_info dsc_info [] = {
	DUMP_FIELD(UInteger16, stepsRemoved),
	DUMP_FIELD(TimeInterval, offsetFromMaster),
	DUMP_FIELD(TimeInterval, meanDelay), /* oneWayDelay */
};

#undef DUMP_STRUCT
#define DUMP_STRUCT parentDS_t /* Horrible typedef */
struct dump_info dsp_info [] = {
	DUMP_FIELD(PortIdentity, parentPortIdentity),
	DUMP_FIELD(UInteger16, observedParentOffsetScaledLogVariance),
	DUMP_FIELD(Integer32, observedParentClockPhaseChangeRate),
	DUMP_FIELD(ClockIdentity, grandmasterIdentity),
	DUMP_FIELD(ClockQuality, grandmasterClockQuality),
	DUMP_FIELD(UInteger8, grandmasterPriority1),
	DUMP_FIELD(UInteger8, grandmasterPriority2),
	DUMP_FIELD(yes_no_Boolean, newGrandmaster),
};

#undef DUMP_STRUCT
#define DUMP_STRUCT timePropertiesDS_t /* Horrible typedef */
struct dump_info dstp_info [] = {
	DUMP_FIELD(Integer16, currentUtcOffset),
	DUMP_FIELD(yes_no_Boolean, currentUtcOffsetValid),
	DUMP_FIELD(yes_no_Boolean, leap59),
	DUMP_FIELD(yes_no_Boolean, leap61),
	DUMP_FIELD(yes_no_Boolean, timeTraceable),
	DUMP_FIELD(yes_no_Boolean, frequencyTraceable),
	DUMP_FIELD(yes_no_Boolean, ptpTimescale),
	DUMP_FIELD(Enumeration8, timeSource),
};

#undef DUMP_STRUCT
#define DUMP_STRUCT struct pp_servo
struct dump_info servo_state_info [] = {
	DUMP_FIELD(pp_servo_state , state),
	DUMP_FIELD(time, delayMM),
	DUMP_FIELD(time, delayMS),
	DUMP_FIELD(long_long, obs_drift),
	DUMP_FIELD(Integer64, mpd_fltr.m),
	DUMP_FIELD(Integer64, mpd_fltr.y),
	DUMP_FIELD(Integer64, mpd_fltr.s_exp),
	DUMP_FIELD(time, meanDelay),
	DUMP_FIELD(time, offsetFromMaster),
	DUMP_FIELD(pp_servo_flag,      flags),
	DUMP_FIELD(time, update_time),
	DUMP_FIELD(UInteger32, update_count),
	DUMP_FIELD(time, t1),
	DUMP_FIELD(time, t2),
	DUMP_FIELD(time, t3),
	DUMP_FIELD(time, t4),
	DUMP_FIELD(time, t5),
	DUMP_FIELD(time, t6),
	DUMP_FIELD_SIZE(char, servo_state_name,32),
	DUMP_FIELD(yes_no, servo_locked),
	DUMP_FIELD(yes_no, got_sync),
};

#if CONFIG_HAS_EXT_L1SYNC || CONFIG_HAS_EXT_WR
#undef DUMP_STRUCT
#define DUMP_STRUCT wrh_servo_t
struct dump_info wrh_servo_info [] = {
	DUMP_FIELD(Integer32, clock_period_ps),
	DUMP_FIELD(Integer64, delayMM_ps),
	DUMP_FIELD(Integer32, cur_setpoint_ps),
	DUMP_FIELD(Integer64, delayMS_ps),
	DUMP_FIELD(int,       tracking_enabled),
	DUMP_FIELD(Integer64, skew_ps),
	DUMP_FIELD(Integer64, offsetMS_ps),
	DUMP_FIELD(UInteger32, n_err_state),
	DUMP_FIELD(UInteger32, n_err_offset),
	DUMP_FIELD(UInteger32, n_err_delta_rtt),
	DUMP_FIELD(Integer64, prev_delayMS_ps),
	DUMP_FIELD(int, missed_iters),
};

#endif

#if CONFIG_HAS_EXT_L1SYNC
#undef DUMP_STRUCT
#define DUMP_STRUCT l1e_ext_portDS_t
struct dump_info l1e_ext_portDS_info [] = {
	DUMP_FIELD(Boolean,  basic.L1SyncEnabled),
	DUMP_FIELD(Boolean,  basic.txCoherentIsRequired),
	DUMP_FIELD(Boolean,  basic.rxCoherentIsRequired),
	DUMP_FIELD(Boolean,  basic.congruentIsRequired),
	DUMP_FIELD(Boolean,  basic.optParamsEnabled),
	DUMP_FIELD(Integer8, basic.logL1SyncInterval),
	DUMP_FIELD(Integer8, basic.L1SyncReceiptTimeout),
	DUMP_FIELD(Boolean,  basic.L1SyncLinkAlive),
	DUMP_FIELD(Boolean,  basic.isTxCoherent),
	DUMP_FIELD(Boolean,  basic.isRxCoherent),
	DUMP_FIELD(Boolean,  basic.isCongruent),
	DUMP_FIELD(Enumeration8,  basic.L1SyncState),
	DUMP_FIELD(Boolean,  basic.peerTxCoherentIsRequired),
	DUMP_FIELD(Boolean,  basic.peerRxCoherentIsRequired),
	DUMP_FIELD(Boolean,  basic.peerCongruentIsRequired),
	DUMP_FIELD(Boolean,  basic.peerIsTxCoherent),
	DUMP_FIELD(Boolean,  basic.peerIsRxCoherent),
	DUMP_FIELD(Boolean,  basic.peerIsCongruent),
	DUMP_FIELD(Enumeration8,  basic.next_state),
	DUMP_FIELD(Boolean,  opt_params.timestampsCorrectedTx),
	DUMP_FIELD(Boolean,  opt_params.phaseOffsetTxValid),
	DUMP_FIELD(Boolean,  opt_params.frequencyOffsetTxValid),
	DUMP_FIELD(time,     opt_params.phaseOffsetTx),
	DUMP_FIELD(Timestamp,opt_params.phaseOffsetTxTimesatmp),
	DUMP_FIELD(time,     opt_params.frequencyOffsetTx),
	DUMP_FIELD(Timestamp,opt_params.frequencyOffsetTxTimesatmp),
};


#undef DUMP_STRUCT
#define DUMP_STRUCT l1e_ext_portDS_t
l1e_ext_portDS_t l1eLocalPortDS= { /* Local structure used only to print that L1Sync is disabled */
		.basic.L1SyncEnabled=0,
		.basic.L1SyncState=L1SYNC_DISABLED
};
struct dump_info l1e_local_portDS_info [] = {
		DUMP_FIELD(Boolean,  basic.L1SyncEnabled),
		DUMP_FIELD(Enumeration8,  basic.L1SyncState),
};

#endif

#if CONFIG_HAS_EXT_WR == 1
#undef DUMP_STRUCT
#define DUMP_STRUCT wr_servo_ext_t
struct dump_info wr_servo_ext_info [] = {
	DUMP_FIELD(time, delta_txm),
	DUMP_FIELD(time, delta_rxm),
	DUMP_FIELD(time, delta_txs),
	DUMP_FIELD(time, delta_rxs),
	DUMP_FIELD(time, rawT1),
	DUMP_FIELD(time, rawT2),
	DUMP_FIELD(time, rawT3),
	DUMP_FIELD(time, rawT4),
	DUMP_FIELD(time, rawT5),
	DUMP_FIELD(time, rawT6),
	DUMP_FIELD(time, rawDelayMM),
};
#endif

#undef DUMP_STRUCT
#define DUMP_STRUCT portDS_t
struct dump_info portDS_info [] = {
	DUMP_FIELD(PortIdentity, portIdentity),
	DUMP_FIELD(Integer8, logMinDelayReqInterval),
	DUMP_FIELD(Integer8, logAnnounceInterval),
	DUMP_FIELD(UInteger8, announceReceiptTimeout),
	DUMP_FIELD(Integer8, logSyncInterval),
	DUMP_FIELD(pointer, ext_dsport),
	DUMP_FIELD(Integer8, logMinPdelayReqInterval),
	DUMP_FIELD(TimeInterval, meanLinkDelay),
	DUMP_FIELD(UInteger4, versionNumber),
	DUMP_FIELD(UInteger4, minorVersionNumber),
	DUMP_FIELD(TimeInterval, delayAsymmetry),
	DUMP_FIELD(RelativeDifference, delayAsymCoeff),
	DUMP_FIELD(yes_no_Boolean, portEnable),
	DUMP_FIELD(yes_no_Boolean, masterOnly)
};

#undef DUMP_STRUCT
#define DUMP_STRUCT struct pp_frgn_master
struct dump_info dsfm_info [] = {
	DUMP_FIELD(PortIdentity, sourcePortIdentity),
	DUMP_FIELD(PortIdentity, receivePortIdentity),
	DUMP_FIELD(ClockQuality, grandmasterClockQuality),
	DUMP_FIELD(ClockIdentity, grandmasterIdentity),
	DUMP_FIELD(UInteger8, grandmasterPriority1),
	DUMP_FIELD(UInteger8, grandmasterPriority2),
	DUMP_FIELD_SIZE(UInteger8, flagField,2),
	DUMP_FIELD(Enumeration8, timeSource),
	DUMP_FIELD(UInteger16, sequenceId),
	DUMP_FIELD(UInteger16, stepsRemoved),
	DUMP_FIELD(Integer16, currentUtcOffset),
	DUMP_FIELD(yes_no_Boolean, qualified),
	DUMP_FIELD(unsigned_long, lastAnnounceMsgMs),
	DUMP_FIELD_SIZE(bina, peer_mac, 6),
};

#undef DUMP_STRUCT
#define DUMP_STRUCT struct pp_instance
struct dump_info ppi_info [] = {
	DUMP_FIELD(ppi_state, state),
	DUMP_FIELD(ppi_state, next_state),
	DUMP_FIELD(int, next_delay),
	DUMP_FIELD(yes_no, is_new_state),
	DUMP_FIELD(exstate,extState),
	DUMP_FIELD(pp_pdstate,pdstate),
	DUMP_FIELD(pointer, arch_inst_data),
	DUMP_FIELD(pointer, ext_data),
	DUMP_FIELD(protocol_extension, protocol_extension),
	DUMP_FIELD(pointer, ext_hooks),
	DUMP_FIELD(pointer, servo),		/* FIXME: follow this */
	DUMP_FIELD(unsigned_long, d_flags),
	DUMP_FIELD(ppi_flag, flags),
	DUMP_FIELD(ppi_proto, proto),
	DUMP_FIELD(delay_mechanism, delayMechanism),
	DUMP_FIELD(pointer, glbs),
	DUMP_FIELD(pointer, n_ops),
	DUMP_FIELD(pointer, t_ops),
	DUMP_FIELD(pointer, __tx_buffer),
	DUMP_FIELD(pointer, __rx_buffer),
	DUMP_FIELD(pointer, tx_frame),
	DUMP_FIELD(pointer, rx_frame),
	DUMP_FIELD(pointer, tx_ptp),
	DUMP_FIELD(pointer, rx_ptp),

	/* This is a sub-structure */
	DUMP_FIELD(int, ch[0].fd),
	DUMP_FIELD(pointer, ch[0].custom),
	DUMP_FIELD(pointer, ch[0].arch_chan_data),
	DUMP_FIELD_SIZE(bina, ch[0].addr, 6),
	DUMP_FIELD(yes_no, ch[0].pkt_present),
	DUMP_FIELD(int, ch[1].fd),
	DUMP_FIELD(pointer, ch[1].custom),
	DUMP_FIELD(pointer, ch[1].arch_chan_data),
	DUMP_FIELD_SIZE(bina, ch[1].addr, 6),
	DUMP_FIELD(yes_no, ch[1].pkt_present),

	DUMP_FIELD(ip_address, mcast_addr[0]),
	DUMP_FIELD(ip_address, mcast_addr[1]),
	DUMP_FIELD(int, tx_offset),
	DUMP_FIELD(int, rx_offset),
	DUMP_FIELD_SIZE(bina, peer, 6),
	DUMP_FIELD_SIZE(bina, activePeer, 6),
	DUMP_FIELD(uint16_t, peer_vid),

	DUMP_FIELD(time, t1),
	DUMP_FIELD(time, t2),
	DUMP_FIELD(time, t3),
	DUMP_FIELD(time, t4),
	DUMP_FIELD(time, t5),
	DUMP_FIELD(time, t6),
	DUMP_FIELD(uint64_t, syncCF),
	DUMP_FIELD(time, last_rcv_time),
	DUMP_FIELD(time, last_snt_time),
	DUMP_FIELD(UInteger16, frgn_rec_num),
	DUMP_FIELD(Integer16,  frgn_rec_best),
	DUMP_FIELD(UInteger32, frgn_master_time_window_ms),
	DUMP_FIELD(pointer,frgn_master),
	DUMP_FIELD(pointer, portDS),
	DUMP_FIELD(yes_no_Boolean,asymmetryCorrectionPortDS.enable),
	DUMP_FIELD(TimeInterval,asymmetryCorrectionPortDS.constantAsymmetry),
	DUMP_FIELD(RelativeDifference,asymmetryCorrectionPortDS.scaledDelayCoefficient),
	DUMP_FIELD(TimeInterval,timestampCorrectionPortDS.egressLatency),
	DUMP_FIELD(TimeInterval,timestampCorrectionPortDS.ingressLatency),
	DUMP_FIELD(TimeInterval,timestampCorrectionPortDS.messageTimestampPointLatency),
	DUMP_FIELD(TimeInterval,timestampCorrectionPortDS.semistaticLatency),
	DUMP_FIELD(ppi_state_Enumeration8,externalPortConfigurationPortDS.desiredState),

	//DUMP_FIELD(unsigned long tmo_cfg[PP_TO_COUNT]), /* dump separately */
	DUMP_FIELD(UInteger16, recv_sync_sequence_id),
	//DUMP_FIELD(UInteger16 sent_seq[__PP_NR_MESSAGES_TYPES]),
	DUMP_FIELD_SIZE(bina, received_ptp_header, sizeof(MsgHeader)),
	DUMP_FIELD(yes_no_Boolean, link_up),

	DUMP_FIELD_SIZE(pointer, iface_name,16),
	DUMP_FIELD_SIZE(pointer, port_name,16),
	DUMP_FIELD(int, port_idx),
	DUMP_FIELD(int, vlans_array_len),
	/* pass the size of a vlans array in the nvlans field */
	DUMP_FIELD_SIZE(array_int, vlans, offsetof(DUMP_STRUCT, nvlans)),
	DUMP_FIELD(int, nvlans),

	/* sub structure */
	DUMP_FIELD_SIZE(char, cfg.port_name, 16),
	DUMP_FIELD_SIZE(char, cfg.iface_name, 16),
	DUMP_FIELD(ppi_profile, cfg.profile),
	DUMP_FIELD(delay_mechanism, cfg.delayMechanism),

	DUMP_FIELD(unsigned_long, ptp_tx_count),
	DUMP_FIELD(unsigned_long, ptp_rx_count),
};

#undef DUMP_STRUCT
#define DUMP_STRUCT timeOutInstCnt_t
struct dump_info timeouts_info [] = {
	DUMP_FIELD(int, which_rand),
	DUMP_FIELD(int, initValueMs),
	DUMP_FIELD(unsigned_long, tmo),
};

#if CONFIG_HAS_EXT_WR == 1
#undef DUMP_STRUCT
#define DUMP_STRUCT struct wr_dsport
struct dump_info wr_ext_portDS_info [] = {
	DUMP_FIELD(wr_state,state),
	DUMP_FIELD(wr_state, next_state),
	DUMP_FIELD(yes_no_Boolean, wrModeOn),
	DUMP_FIELD(yes_no_Boolean, parentWrModeOn),
	DUMP_FIELD(scaledPicoseconds, deltaTx),
	DUMP_FIELD(scaledPicoseconds, deltaRx),
	DUMP_FIELD(UInteger16, otherNodeCalSendPattern),
	DUMP_FIELD(UInteger8, otherNodeCalRetry),
	DUMP_FIELD(UInteger32, otherNodeCalPeriod),
	DUMP_FIELD(scaledPicoseconds, otherNodeDeltaTx),
	DUMP_FIELD(scaledPicoseconds, otherNodeDeltaRx),
	DUMP_FIELD(wr_config_Enumeration8, wrConfig),
	DUMP_FIELD(wr_config_Enumeration8, parentWrConfig),
	DUMP_FIELD(wr_role_Enumeration8, wrMode),
	DUMP_FIELD(PortIdentity, parentAnnPortIdentity),
	DUMP_FIELD(UInteger16, parentAnnSequenceId),
};
#endif

#if CONFIG_ARCH_IS_WRS
#undef DUMP_STRUCT
#define DUMP_STRUCT struct wrs_arch_data_t
struct dump_info wrs_arch_data_info [] = {
	DUMP_FIELD(timing_mode,timingMode),
	DUMP_FIELD(int,timingModeLockingState),
	DUMP_FIELD(int,gmUnlockErr)
};
#endif

void print_str(char *s);

int dump_one_field_type_ppsi_wrs(int type, int size, void *p)
{
	int i;

	switch(type) {
	case dump_type_yes_no_Boolean:
	case dump_type_ppi_state:
	case dump_type_ppi_state_Enumeration8:
	case dump_type_wr_config:
	case dump_type_wr_config_Enumeration8:
	case dump_type_wr_role:
	case dump_type_wr_role_Enumeration8:
	case dump_type_pp_pdstate:
	case dump_type_exstate:
	case dump_type_pp_servo_flag:
	case dump_type_pp_servo_state:
	case dump_type_wr_state:
	case dump_type_ppi_profile:
	case dump_type_ppi_proto:
	case dump_type_ppi_flag:
		if (size == 1)
			i = *(uint8_t *)p;
		else if (size == 2)
			i = *(uint16_t *)(p);
		else
			i = *(uint32_t *)(p);
		break;
	default:
		i = 0;
	}

	return i;
}

/* create fancy macro to shorten the switch statements, assign val as a string to p */
#define ENUM_TO_P_IN_CASE(val, p) \
				case val: \
				    p = #val;\
				    break;

void dump_one_field_ppsi_wrs(int type, int size, void *p, int i)
{
	struct pp_time *t = p;
	struct PortIdentity *pi = p;
	struct ClockQuality *cq = p;
	TimeInterval *ti=p;
	RelativeDifference *rd=p;
	char buf[128];
	char *char_p;
	Timestamp *ts=p;

	/* check the size of Boolean, which is declared as Enum */
	if (type == dump_type_Boolean) {
		switch(size) {
		case 1:
			type = dump_type_UInteger8;
			break;
		case 2:
			type = dump_type_UInteger16;
			break;
		case 4:
		default:
			type = dump_type_UInteger32;
			break;
		}
	}

	switch(type) {
	case dump_type_UInteger64:
		printf("%lld\n", *(unsigned long long *)p);
		break;
	case dump_type_Integer64:
		printf("%lld\n", *(long long *)p);
		break;
	case dump_type_Integer32:
		printf("%i\n", *(int *)p);
		break;
	case dump_type_UInteger32:
		printf("%u\n", *(uint32_t *)p);
		break;
	case dump_type_UInteger8:
	case dump_type_Integer8:
	case dump_type_Enumeration8:
	case dump_type_Boolean:
		printf("%i\n", *(unsigned char *)p);
		break;
	case dump_type_UInteger4:
		printf("%i\n", *(unsigned char *)p & 0xF);
		break;
	case dump_type_UInteger16:
		printf("%i\n", *(unsigned short *)p);
		break;
	case dump_type_Integer16:
		printf("%i\n", *(short *)p);
		break;
	case dump_type_Timestamp:
		printf("%s\n",timestampToString(ts,buf));
		break;

	case dump_type_TimeInterval:
		printf("%15s, ", timeIntervalToString(*ti, buf));
		printf("raw:  %15lld\n", *(unsigned long long *)p);
		break;
	case dump_type_yes_no_Boolean:
		printf("%d", i);
		if (i == 0)
			print_str("no");
		else if (i == 1)
			print_str("yes");
		else
			print_str("unknown");
		printf("\n");
		break;

	case dump_type_pp_time:
	{
		struct pp_time localt;
		localt.secs = t->secs;
		localt.scaled_nsecs = t->scaled_nsecs;

		printf("correct %i: %25s rawps: 0x%04x\n",
		       !is_incorrect(&localt),
		       timeToString(&localt,buf),
		       (int)(localt.scaled_nsecs & 0xffff)
		      );
		break;
	}
	case dump_type_RelativeDifference:
		printf("%15s, ", relativeDifferenceToString(*rd, buf));
		printf("raw:  %15lld\n", *(unsigned long long *)p);
		break;
	case dump_type_ClockIdentity: /* Same as binary */
		for (i = 0; i < sizeof(ClockIdentity); i++)
			printf("%02x%c", ((unsigned char *)p)[i],
			       i == sizeof(ClockIdentity) - 1 ? '\n' : ':');
		break;

	case dump_type_PortIdentity: /* Same as above plus port */
		for (i = 0; i < sizeof(ClockIdentity); i++)
			printf("%02x%c", ((unsigned char *)p)[i],
			       i == sizeof(ClockIdentity) - 1 ? '.' : ':');
		printf("%04x (%i)\n", pi->portNumber, pi->portNumber);
		break;

	case dump_type_ClockQuality:
		printf("class=%i, accuracy=0x%02x (%i), logvariance=%i\n",
		       cq->clockClass, cq->clockAccuracy, cq->clockAccuracy,
		       cq->offsetScaledLogVariance);
		break;
	case dump_type_scaledPicoseconds:
		printf("%lld\n", (*(unsigned long long *)p)>>16);
		break;


	case dump_type_delay_mechanism:
		i = *(uint32_t *)p;
		switch(i) {
		ENUM_TO_P_IN_CASE(MECH_E2E, char_p);
		ENUM_TO_P_IN_CASE(MECH_P2P, char_p);
		ENUM_TO_P_IN_CASE(MECH_COMMON_P2P, char_p);
		ENUM_TO_P_IN_CASE(MECH_SPECIAL, char_p);
		ENUM_TO_P_IN_CASE(MECH_NO_MECHANISM, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_protocol_extension:
		i = *(uint32_t *)p;
		switch(i) {
		ENUM_TO_P_IN_CASE(PPSI_EXT_NONE, char_p);
		ENUM_TO_P_IN_CASE(PPSI_EXT_WR, char_p);
		ENUM_TO_P_IN_CASE(PPSI_EXT_L1S, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_timing_mode:
		i = *(uint32_t *)p;
		switch(i) {
		ENUM_TO_P_IN_CASE(WRH_TM_GRAND_MASTER, char_p);
		ENUM_TO_P_IN_CASE(WRH_TM_FREE_MASTER, char_p);
		ENUM_TO_P_IN_CASE(WRH_TM_BOUNDARY_CLOCK, char_p);
		ENUM_TO_P_IN_CASE(WRH_TM_DISABLED, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_ppi_state:
	case dump_type_ppi_state_Enumeration8:
		switch(i) {
		ENUM_TO_P_IN_CASE(PPS_INITIALIZING, char_p);
		ENUM_TO_P_IN_CASE(PPS_FAULTY, char_p);
		ENUM_TO_P_IN_CASE(PPS_DISABLED, char_p);
		ENUM_TO_P_IN_CASE(PPS_LISTENING, char_p);
		ENUM_TO_P_IN_CASE(PPS_PRE_MASTER, char_p);
		ENUM_TO_P_IN_CASE(PPS_MASTER, char_p);
		ENUM_TO_P_IN_CASE(PPS_PASSIVE, char_p);
		ENUM_TO_P_IN_CASE(PPS_UNCALIBRATED, char_p);
		ENUM_TO_P_IN_CASE(PPS_SLAVE, char_p);
		ENUM_TO_P_IN_CASE(PPS_LAST_STATE, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_wr_config:
	case dump_type_wr_config_Enumeration8:
		switch(i) {
		ENUM_TO_P_IN_CASE(NON_WR, char_p);
		ENUM_TO_P_IN_CASE(WR_M_ONLY, char_p);
		ENUM_TO_P_IN_CASE(WR_S_ONLY, char_p);
		ENUM_TO_P_IN_CASE(WR_M_AND_S, char_p);
		ENUM_TO_P_IN_CASE(WR_MODE_AUTO, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_wr_role:
	case dump_type_wr_role_Enumeration8:
		switch(i) {
		ENUM_TO_P_IN_CASE(WR_ROLE_NONE, char_p);
		ENUM_TO_P_IN_CASE(WR_MASTER, char_p);
		ENUM_TO_P_IN_CASE(WR_SLAVE, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_pp_pdstate:
		switch(i) {
		ENUM_TO_P_IN_CASE(PP_PDSTATE_NONE, char_p);
		ENUM_TO_P_IN_CASE(PP_PDSTATE_WAIT_MSG, char_p);
		ENUM_TO_P_IN_CASE(PP_PDSTATE_PDETECTION, char_p);
		ENUM_TO_P_IN_CASE(PP_PDSTATE_PDETECTED, char_p);
		ENUM_TO_P_IN_CASE(PP_PDSTATE_FAILURE, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_exstate:
		switch(i) {
		ENUM_TO_P_IN_CASE(PP_EXSTATE_DISABLE, char_p);
		ENUM_TO_P_IN_CASE(PP_EXSTATE_ACTIVE, char_p);
		ENUM_TO_P_IN_CASE(PP_EXSTATE_PTP, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_pp_servo_flag:
		switch(i) {
		ENUM_TO_P_IN_CASE(PP_SERVO_FLAG_VALID, char_p);
		ENUM_TO_P_IN_CASE(PP_SERVO_FLAG_WAIT_HW, char_p);
		ENUM_TO_P_IN_CASE(PP_SERVO_FLAG_VALID | PP_SERVO_FLAG_WAIT_HW, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_pp_servo_state:
		switch(i) {
		ENUM_TO_P_IN_CASE(WRH_UNINITIALIZED, char_p);
		ENUM_TO_P_IN_CASE(WRH_SYNC_TAI, char_p);
		ENUM_TO_P_IN_CASE(WRH_SYNC_NSEC, char_p);
		ENUM_TO_P_IN_CASE(WRH_SYNC_PHASE, char_p);
		ENUM_TO_P_IN_CASE(WRH_TRACK_PHASE, char_p);
		ENUM_TO_P_IN_CASE(WRH_WAIT_OFFSET_STABLE, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_wr_state:
		switch(i) {
		ENUM_TO_P_IN_CASE(WRS_IDLE, char_p);
		ENUM_TO_P_IN_CASE(WRS_PRESENT, char_p);
		ENUM_TO_P_IN_CASE(WRS_S_LOCK, char_p);
		ENUM_TO_P_IN_CASE(WRS_M_LOCK, char_p);
		ENUM_TO_P_IN_CASE(WRS_LOCKED, char_p);
		ENUM_TO_P_IN_CASE(WRS_CALIBRATION, char_p);
		ENUM_TO_P_IN_CASE(WRS_CALIBRATED, char_p);
		ENUM_TO_P_IN_CASE(WRS_RESP_CALIB_REQ, char_p);
		ENUM_TO_P_IN_CASE(WRS_WR_LINK_ON, char_p);
		ENUM_TO_P_IN_CASE(WRS_MAX_STATES, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_ppi_profile:
		switch(i) {
		ENUM_TO_P_IN_CASE(PPSI_PROFILE_PTP, char_p);
		ENUM_TO_P_IN_CASE(PPSI_PROFILE_WR, char_p);
		ENUM_TO_P_IN_CASE(PPSI_PROFILE_HA, char_p);
		ENUM_TO_P_IN_CASE(PPSI_PROFILE_CUSTOM, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_ppi_proto:
		switch(i) {
		ENUM_TO_P_IN_CASE(PPSI_PROTO_RAW, char_p);
		ENUM_TO_P_IN_CASE(PPSI_PROTO_UDP, char_p);
		ENUM_TO_P_IN_CASE(PPSI_PROTO_VLAN, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_ppi_flag:
		switch(i) {
		case 0:
			char_p = "None";
			break;
		ENUM_TO_P_IN_CASE(PPI_FLAG_WAITING_FOR_F_UP, char_p);
		ENUM_TO_P_IN_CASE(PPI_FLAG_WAITING_FOR_RF_UP, char_p);
		case PPI_FLAGS_WAITING:
		    char_p = "PPI_FLAG_WAITING_FOR_F_UP | PPI_FLAG_WAITING_FOR_RF_UP";
		    break;
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;
	}
}

extern struct dump_info shm_head [5];

int dump_ppsi_mem(struct wrs_shm_head *head)
{
	struct pp_globals *ppg;
	struct pp_instance *pp_instances;
	defaultDS_t *dsd;
	currentDS_t *dsc;
	parentDS_t *dsp;
	timePropertiesDS_t *dstp;
	int i;
	char prefix[64];

	if (head->version != WRS_PPSI_SHMEM_VERSION) {
		fprintf(stderr, "dump ppsi: unknown version %i (known is %i)\n",
			head->version, WRS_PPSI_SHMEM_VERSION);
		return -1;
	}
	/* dump shmem header*/
	dump_many_fields(head, shm_head, ARRAY_SIZE(shm_head),"ppsi.shm");

	ppg = (void *)head + head->data_off;
	dump_many_fields(ppg, ppg_info, ARRAY_SIZE(ppg_info),"ppsi.globalDS");

	dsd = wrs_shm_follow(head, ppg->defaultDS);
	dump_many_fields(dsd, dsd_info, ARRAY_SIZE(dsd_info),"ppsi.defaulDS");

	dsc = wrs_shm_follow(head, ppg->currentDS);
	dump_many_fields(dsc, dsc_info, ARRAY_SIZE(dsc_info),"ppsi.currentDS");

	dsp = wrs_shm_follow(head, ppg->parentDS);
	dump_many_fields(dsp, dsp_info, ARRAY_SIZE(dsp_info),"ppsi.parentDS");

	dstp = wrs_shm_follow(head, ppg->timePropertiesDS);
	dump_many_fields(dstp, dstp_info, ARRAY_SIZE(dstp_info),"ppsi.timePropertiesDS");

#if CONFIG_ARCH_IS_WRS
	{
		wrs_arch_data_t *arch_data=wrs_shm_follow(head, WRS_ARCH_G(ppg));
		dump_many_fields(arch_data, wrs_arch_data_info, ARRAY_SIZE(wrs_arch_data_info),"ppsi.arch_inst_data");
	}
#endif


	pp_instances = wrs_shm_follow(head, ppg->pp_instances);
	/* print extension servo data set */
	for (i = 0; i < ppg->nlinks; i++) {
		struct pp_instance * ppi= pp_instances+i;

		sprintf(prefix,"ppsi.inst.%d.portDS",i);
		dump_many_fields( wrs_shm_follow(head, ppi->portDS)
				, portDS_info,
				 ARRAY_SIZE(portDS_info),prefix);

		if ( ppi->state == PPS_SLAVE ) {
			sprintf(prefix,"ppsi.inst.%d.servo",i);
			dump_many_fields( wrs_shm_follow(head, ppi->servo)
					, servo_state_info,
					 ARRAY_SIZE(servo_state_info),prefix);
#if CONFIG_HAS_EXT_WR == 1
			if ( ppi->protocol_extension == PPSI_EXT_WR) {
				struct wr_data *data;
				data = wrs_shm_follow(head, ppi->ext_data);
				sprintf(prefix,"ppsi.inst.%d.servo.wr",i);
				dump_many_fields(&data->servo, wrh_servo_info, ARRAY_SIZE(wrh_servo_info),prefix);
				dump_many_fields(&data->servo_ext, wr_servo_ext_info, ARRAY_SIZE(wr_servo_ext_info),prefix);
			}
#endif
#if CONFIG_HAS_EXT_L1SYNC == 1
			if ( ppi->protocol_extension == PPSI_EXT_L1S) {
				struct l1e_data *data;
				data = wrs_shm_follow(head, ppi->ext_data);
				sprintf(prefix,"ppsi.inst.%d.servo.l1sync",i);
				dump_many_fields(&data->servo, wrh_servo_info, ARRAY_SIZE(wrh_servo_info),prefix);
			}
#endif
		}
	}

	for (i = 0; i < ppg->nlinks; i++) {
		struct pp_instance * ppi= pp_instances+i;
		int tmo_i;

		sprintf(prefix,"ppsi.inst.%d.info",i);
		dump_many_fields(ppi, ppi_info, ARRAY_SIZE(ppi_info),prefix);

		// Print foreign master list
		if ( ppi->frgn_rec_num>0 ) {
			int fm;

			for ( fm=0; fm<ppi->frgn_rec_num && fm<PP_NR_FOREIGN_RECORDS; fm++) {
				sprintf(prefix,"ppsi.inst.%d.frgn_master[%d]",i,fm);
				dump_many_fields( &ppi->frgn_master[fm], dsfm_info, ARRAY_SIZE(dsfm_info),prefix);
			}
		}

		for (tmo_i = 0; tmo_i < PP_TO_COUNT; tmo_i++) {
				sprintf(prefix,"ppsi.inst.%d.tmo_cfgx[%d]", i, tmo_i);
				dump_many_fields(&ppi->tmo_cfg[tmo_i], timeouts_info, ARRAY_SIZE(timeouts_info), prefix);
		}

#if CONFIG_HAS_EXT_L1SYNC == 1
		sprintf(prefix,"ppsi.inst.%d.l1sync_portDS",i);
		if ( ppi->protocol_extension == PPSI_EXT_L1S) {
			portDS_t *portDS=wrs_shm_follow(head, ppi->portDS);
			l1e_ext_portDS_t *data=wrs_shm_follow(head, portDS->ext_dsport);
			dump_many_fields(data, l1e_ext_portDS_info, ARRAY_SIZE(l1e_ext_portDS_info),prefix);
		} else  {
			dump_many_fields(&l1eLocalPortDS, l1e_local_portDS_info, ARRAY_SIZE(l1e_local_portDS_info),prefix);
		}
#endif
#if CONFIG_HAS_EXT_WR
		if ( ppi->protocol_extension == PPSI_EXT_WR) {
			sprintf(prefix,"ppsi.inst.%d.wr",i);
			portDS_t *portDS=wrs_shm_follow(head, ppi->portDS);
			struct wr_dsport *data=wrs_shm_follow(head, portDS->ext_dsport);
			dump_many_fields(data, wr_ext_portDS_info, ARRAY_SIZE(wr_ext_portDS_info),prefix);
		}
#endif
	}
	return 0; /* this is complete */
}
