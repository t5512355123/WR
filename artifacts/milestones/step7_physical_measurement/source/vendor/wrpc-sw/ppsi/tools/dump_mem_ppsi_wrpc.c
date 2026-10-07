#include <sys/types.h>
#include <ppsi/ppsi.h>
#include <stdio.h>

#include <wrpc.h>
#include <time_lib.h>

#include "dump-info.h"
#include "dump-info_ppsi.h"

struct dump_info  dump_ppsi_info[] = {
/* map for fields of ppsi structures */
#undef DUMP_STRUCT
#define DUMP_STRUCT struct pp_globals

	DUMP_HEADER("pp_globals"),
	DUMP_FIELD(pointer, pp_instances),
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


#undef DUMP_STRUCT
#define DUMP_STRUCT struct pp_runtime_opts /* Horrible typedef */
	DUMP_HEADER("pp_runtime_opts"),
	DUMP_FIELD(uint32_t, updated_fields_mask),
	DUMP_FIELD(int, clock_quality_clockClass),                 // ClockQuality.clockClass
	DUMP_FIELD(int, clock_quality_clockAccuracy),              // ClockQuality.clockAccuracy
	DUMP_FIELD(int, clock_quality_offsetScaledLogVariance),    // ClockQuality.offsetScaledLogVariance
	DUMP_FIELD(int, timeSource),                               // timePropertiesDS_t.timeSource
	DUMP_FIELD(yes_no_Boolean, ptpTimeScale),                         // timePropertiesDS_t.timeScale
	DUMP_FIELD(yes_no_Boolean, frequencyTraceable),                   // timePropertiesDS_t.frequencyTraceable
	DUMP_FIELD(yes_no_Boolean, timeTraceable),                        // timePropertiesDS_t.timeTraceable
	DUMP_FIELD(Integer32, ttl),
	DUMP_FIELD(int, flags),		/* see below */
	DUMP_FIELD(Integer16, ap),
	DUMP_FIELD(Integer16, ai),
	DUMP_FIELD(Integer16, s),
	DUMP_FIELD(int, priority1),
	DUMP_FIELD(int, priority2),
	DUMP_FIELD(int, domainNumber),
	DUMP_FIELD(int, ptpPpsThresholdMs),
	DUMP_FIELD(int, gmDelayToGenPpsSec),
	DUMP_FIELD(yes_no_Boolean, externalPortConfigurationEnabled),
	DUMP_FIELD(yes_no_Boolean, slaveOnly),
	DUMP_FIELD(yes_no_Boolean, forcePpsGen),
	DUMP_FIELD(yes_no_Boolean, ptpFallbackPpsGen),
	DUMP_FIELD(pointer, arch_opts),

#undef DUMP_STRUCT
#define DUMP_STRUCT defaultDS_t /* Horrible typedef */

	DUMP_HEADER("defaultDS_t"),
	DUMP_FIELD(ClockIdentity, clockIdentity),
	DUMP_FIELD(UInteger16, numberPorts),
	DUMP_FIELD(ClockQuality, clockQuality),
	DUMP_FIELD(UInteger8, priority1),
	DUMP_FIELD(UInteger8, priority2),
	DUMP_FIELD(UInteger8, domainNumber),

	DUMP_FIELD(yes_no_Boolean, slaveOnly),
	/** Optional (IEEE1588-2019) */
//	FIXME: DUMP_FIELD(Timestamp, currentTime),
	DUMP_FIELD(yes_no_Boolean, instanceEnable),
	DUMP_FIELD(yes_no_Boolean, externalPortConfigurationEnabled),
	DUMP_FIELD(Enumeration8, maxStepsRemoved),
	DUMP_FIELD(Enumeration8, instanceType),


#undef DUMP_STRUCT
#define DUMP_STRUCT currentDS_t /* Horrible typedef */

	DUMP_HEADER("currentDS_t"),
	DUMP_FIELD(UInteger16, stepsRemoved),
	DUMP_FIELD(TimeInterval, offsetFromMaster),
	DUMP_FIELD(TimeInterval, meanDelay), /* oneWayDelay */


#undef DUMP_STRUCT
#define DUMP_STRUCT parentDS_t /* Horrible typedef */

	DUMP_HEADER("parentDS_t"),
	DUMP_FIELD(PortIdentity, parentPortIdentity),
	DUMP_FIELD(UInteger16, observedParentOffsetScaledLogVariance),
	DUMP_FIELD(Integer32, observedParentClockPhaseChangeRate),
	DUMP_FIELD(ClockIdentity, grandmasterIdentity),
	DUMP_FIELD(ClockQuality, grandmasterClockQuality),
	DUMP_FIELD(UInteger8, grandmasterPriority1),
	DUMP_FIELD(UInteger8, grandmasterPriority2),
	DUMP_FIELD(yes_no_Boolean, newGrandmaster),


#undef DUMP_STRUCT
#define DUMP_STRUCT timePropertiesDS_t /* Horrible typedef */

	DUMP_HEADER("timePropertiesDS_t"),
	DUMP_FIELD(Integer16, currentUtcOffset),
	DUMP_FIELD(yes_no_Boolean, currentUtcOffsetValid),
	DUMP_FIELD(yes_no_Boolean, leap59),
	DUMP_FIELD(yes_no_Boolean, leap61),
	DUMP_FIELD(yes_no_Boolean, timeTraceable),
	DUMP_FIELD(yes_no_Boolean, frequencyTraceable),
	DUMP_FIELD(yes_no_Boolean, ptpTimescale),
	DUMP_FIELD(Enumeration8, timeSource),


#undef DUMP_STRUCT
#define DUMP_STRUCT struct pp_servo

	DUMP_HEADER("pp_servo"),
	DUMP_FIELD(long_long, obs_drift),
	DUMP_FIELD(Integer64, mpd_fltr.m),
	DUMP_FIELD(Integer64, mpd_fltr.y),
	DUMP_FIELD(Integer64, mpd_fltr.s_exp),

	/* Data shared with extension servo */
	DUMP_FIELD(pp_time, delayMM), /* Shared with extension servo */
	DUMP_FIELD(pp_time, delayMS), /* Shared with extension servo */
	DUMP_FIELD(pp_time, meanDelay), /* Shared with extension servo */
	DUMP_FIELD(pp_time, offsetFromMaster), /* Shared with extension servo */
	DUMP_FIELD(pp_servo_flag, flags),

	/* Data used only by extensions */
	DUMP_FIELD(pp_servo_state, state),

	/* Data shared with extension servo */
	DUMP_FIELD(UInteger32, update_count),
	DUMP_FIELD(pp_time, update_time),
	DUMP_FIELD(pp_time, t1),
	DUMP_FIELD(pp_time, t2),
	DUMP_FIELD(pp_time, t3),
	DUMP_FIELD(pp_time, t4),
	DUMP_FIELD(pp_time, t5),
	DUMP_FIELD(pp_time, t6),

	DUMP_FIELD(yes_no, servo_locked),
	DUMP_FIELD(yes_no, got_sync),

#if CONFIG_HAS_EXT_L1SYNC || CONFIG_HAS_EXT_WR
#undef DUMP_STRUCT
#define DUMP_STRUCT wrh_servo_t
	DUMP_HEADER("wrh_servo_t"),
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
#endif

#if CONFIG_HAS_EXT_WR == 1
#undef DUMP_STRUCT
#define DUMP_STRUCT wr_servo_ext_t
	DUMP_HEADER("wr_servo_ext_t"),
	DUMP_FIELD(pp_time, delta_txm),
	DUMP_FIELD(pp_time, delta_rxm),
	DUMP_FIELD(pp_time, delta_txs),
	DUMP_FIELD(pp_time, delta_rxs),
	DUMP_FIELD(pp_time, rawT1),
	DUMP_FIELD(pp_time, rawT2),
	DUMP_FIELD(pp_time, rawT3),
	DUMP_FIELD(pp_time, rawT4),
	DUMP_FIELD(pp_time, rawT5),
	DUMP_FIELD(pp_time, rawT6),
	DUMP_FIELD(pp_time, rawDelayMM),
#endif

#undef DUMP_STRUCT
#define DUMP_STRUCT portDS_t

	DUMP_HEADER("portDS_t"),
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
	DUMP_FIELD(yes_no_Boolean, masterOnly),

#undef DUMP_STRUCT
#define DUMP_STRUCT struct pp_instance

	DUMP_HEADER("pp_instance"),
	DUMP_FIELD(ppi_state, state),
	DUMP_FIELD(ppi_state, next_state),
	DUMP_FIELD(int, next_delay),
	DUMP_FIELD(yes_no, is_new_state),
	DUMP_FIELD(pointer, current_state_item),
	DUMP_FIELD(pointer, arch_inst_data),
	DUMP_FIELD(pointer, ext_data),
	DUMP_FIELD(protocol_extension, protocol_extension),
	DUMP_FIELD(pointer, ext_hooks),
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

	DUMP_FIELD(pp_time, t1),
	DUMP_FIELD(pp_time, t2),
	DUMP_FIELD(pp_time, t3),
	DUMP_FIELD(pp_time, t4),
	DUMP_FIELD(pp_time, t5),
	DUMP_FIELD(pp_time, t6),
	DUMP_FIELD(UInteger64, syncCF),
	DUMP_FIELD(pp_time, last_rcv_time),
	DUMP_FIELD(pp_time, last_snt_time),
	DUMP_FIELD(UInteger16, frgn_rec_num),
	DUMP_FIELD(Integer16,  frgn_rec_best),
	DUMP_FIELD(UInteger32, frgn_master_time_window_ms),
	DUMP_FIELD(dummy /*struct pp_frgn_master */, frgn_master), /* use dummy type just to save the offset */
	DUMP_FIELD(pointer, portDS),
	DUMP_FIELD(pointer, servo),

	/*  dump of substructure asymmetryCorrectionPortDS_t; draft P1588_v_29: page 99*/
	DUMP_FIELD(TimeInterval, asymmetryCorrectionPortDS.constantAsymmetry),
	DUMP_FIELD(RelativeDifference, asymmetryCorrectionPortDS.scaledDelayCoefficient),
	DUMP_FIELD(yes_no_Boolean, asymmetryCorrectionPortDS.enable),

	/* dump of substructure timestampCorrectionPortDS_t; draft P1588_v_29: page 99 */
	DUMP_FIELD(TimeInterval, timestampCorrectionPortDS.egressLatency),
	DUMP_FIELD(TimeInterval, timestampCorrectionPortDS.ingressLatency),
	DUMP_FIELD(TimeInterval, timestampCorrectionPortDS.messageTimestampPointLatency),
	DUMP_FIELD(TimeInterval, timestampCorrectionPortDS.semistaticLatency),

	/* dump of substructure externalPortConfigurationPortDS_t; draft P1588: Clause 17.6.3*/
	DUMP_FIELD(ppi_state_Enumeration8, externalPortConfigurationPortDS.desiredState),
	
// 	timeOutInstCnt_t tmo_cfg[PP_TO_COUNT];
	DUMP_FIELD(UInteger16, recv_sync_sequence_id),

	//DUMP_FIELD(UInteger16 sent_seq[__PP_NR_MESSAGES_TYPES]),

	DUMP_FIELD_SIZE(bina, received_ptp_header, sizeof(MsgHeader)),

	DUMP_FIELD(yes_no_Boolean, link_up),
	DUMP_FIELD_SIZE(char, iface_name, 16), /* for direct actions on hardware */
	DUMP_FIELD_SIZE(char, port_name, 16), /* for diagnostics, mainly */
	DUMP_FIELD(int, port_idx),
	DUMP_FIELD(int, vlans_array_len),
	/* FIXME: array */
// 	int vlans[CONFIG_VLAN_ARRAY_SIZE];
	DUMP_FIELD(int, nvlans),

	/* sub structure */
	DUMP_FIELD_SIZE(char, cfg.port_name, 16),
	DUMP_FIELD_SIZE(char, cfg.iface_name, 16),
	DUMP_FIELD(ppi_profile, cfg.profile),
	DUMP_FIELD(delay_mechanism, cfg.delayMechanism),
	/* FIXME: other fields from cfg */

	DUMP_FIELD(unsigned_long, ptp_tx_count),
	DUMP_FIELD(unsigned_long, ptp_rx_count),
	DUMP_FIELD(yes_no_Boolean, received_dresp), /* Count the number of delay response messages received for a given delay request */
	DUMP_FIELD(yes_no_Boolean, received_dresp_fup), /* Count the number of delay response follow up messages received for a given delay request */
	DUMP_FIELD(yes_no_Boolean, ptp_support), /* True if allow pure PTP support */
	DUMP_FIELD(yes_no_Boolean, bmca_execute), /* True: Ask fsm to run bmca state decision */
	DUMP_FIELD(pp_pdstate, pdstate),  /* Protocol detection state */
	DUMP_FIELD(exstate, extState), /* Extension state */

#undef DUMP_STRUCT
#define DUMP_STRUCT struct pp_frgn_master
	DUMP_HEADER_SIZE("pp_frgn_master", sizeof(struct pp_frgn_master)),
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

#if CONFIG_HAS_EXT_WR == 1
#undef DUMP_STRUCT
#define DUMP_STRUCT struct wr_dsport
	DUMP_HEADER("wr_dsport"),
	DUMP_FIELD(wr_state, state),
	DUMP_FIELD(wr_state, next_state),
	DUMP_FIELD(yes_no_Boolean, wrModeOn),
	DUMP_FIELD(yes_no_Boolean, parentWrModeOn),
	DUMP_FIELD(FixedDelta, deltaTx),
	DUMP_FIELD(FixedDelta, deltaRx),
	DUMP_FIELD(UInteger16, otherNodeCalSendPattern),
	DUMP_FIELD(UInteger8, otherNodeCalRetry),
	DUMP_FIELD(UInteger32, otherNodeCalPeriod),
	DUMP_FIELD(FixedDelta, otherNodeDeltaTx),
	DUMP_FIELD(FixedDelta, otherNodeDeltaRx),
	DUMP_FIELD(wr_config_Enumeration8, wrConfig),
	DUMP_FIELD(wr_config_Enumeration8, parentWrConfig),
	DUMP_FIELD(wr_role_Enumeration8, wrMode),
	/* DUMP_FIELD(Enumeration8, wrPortState), not used*/
#endif


#if CONFIG_ARCH_IS_WRPC
#undef DUMP_STRUCT
#define DUMP_STRUCT struct wrpc_arch_data_t
	DUMP_HEADER("wrpc_arch_data_t"),
	DUMP_FIELD(timing_mode, timingMode),
	DUMP_FIELD(wrpc_mode_cfg, wrpcModeCfg),
#endif

#if CONFIG_HAS_EXT_WR
#undef DUMP_STRUCT
#define DUMP_STRUCT struct wr_data

	DUMP_HEADER("wr_data"),
	/* These are structs not pointers, but we need to know the offset in wr_data structure */
	DUMP_FIELD(pointer,servo),
	DUMP_FIELD(pointer,servo_ext),
#endif
	DUMP_HEADER("end"),

};

void dump_mem_ppsi_wrpc(void *mapaddr, unsigned long ppg_off)
{
	unsigned long ppi_off, servo_off, ds_off, arch_data_offset, tmp_off;
	char *prefix;

	prefix = "ppsi.globalDS";
	if (!ppg_off) {
		printf("%s not found\n", prefix);
		/* global structure not found, can't do more, return */
		return;
	}

	/* print ppg first */
	printf("%s at 0x%lx\n", prefix, ppg_off);
	dump_many_fields(mapaddr + ppg_off, "pp_globals", prefix);

	arch_data_offset = wrpc_get_pointer(mapaddr + ppg_off,
					"pp_globals", "arch_glbl_data");
	if (arch_data_offset) {
		prefix = "ppsi.arch_glbl_data";
		printf("%s at 0x%lx\n", prefix, arch_data_offset);
		dump_many_fields(mapaddr + arch_data_offset, "wrpc_arch_data_t",
				 prefix);
	}
	
	ds_off = ppg_off;

	/* dump global data sets */
	tmp_off = wrpc_get_pointer(mapaddr + ds_off, "pp_globals", "rt_opts");
	if (tmp_off) {
		prefix = "ppsi.rt_opts";
		printf("%s at 0x%lx\n", prefix, tmp_off);
		dump_many_fields(mapaddr + tmp_off, "pp_runtime_opts", prefix);
	}

	tmp_off = wrpc_get_pointer(mapaddr + ds_off, "pp_globals", "defaultDS");
	if (tmp_off) {
		prefix = "ppsi.defaultDS";
		printf("%s at 0x%lx\n", prefix, tmp_off);
		dump_many_fields(mapaddr + tmp_off, "defaultDS_t", prefix);
	}

	tmp_off = wrpc_get_pointer(mapaddr + ds_off, "pp_globals", "currentDS");
	if (tmp_off) {
		prefix = "ppsi.currentDS";
		printf("%s at 0x%lx\n", prefix, tmp_off);
		dump_many_fields(mapaddr + tmp_off, "currentDS_t", prefix);
	}

	tmp_off = wrpc_get_pointer(mapaddr + ds_off, "pp_globals", "parentDS");
	if (tmp_off) {
		prefix = "ppsi.parentDS";
		printf("%s at 0x%lx\n", prefix, tmp_off);
		dump_many_fields(mapaddr + tmp_off, "parentDS_t", prefix);
	}

	tmp_off = wrpc_get_pointer(mapaddr + ds_off, "pp_globals",
				   "timePropertiesDS");
	if (tmp_off) {
		prefix = "ppsi.timePropertiesDS";
		printf("%s at 0x%lx\n", prefix, tmp_off);
		dump_many_fields(mapaddr + tmp_off, "timePropertiesDS_t",
				 prefix);
	}

	/* dump instance's data sets */
	ppi_off = wrpc_get_pointer(mapaddr + ppg_off, "pp_globals",
				   "pp_instances");

	if (ppi_off) {
		int protocol_extension;
		unsigned long portds_off;
		unsigned long frgn_m_off;
		unsigned long frgn_master_struct_size;
		int frgn_rec_num;
		int frgn_m_i;
		char buff[50];
		prefix = "ppsi.inst.0";
		printf("%s at 0x%lx\n", prefix, ppi_off);
		dump_many_fields(mapaddr + ppi_off, "pp_instance", prefix);

		/* FIXME: support multiple servo */
		servo_off = wrpc_get_pointer(mapaddr + ppi_off,
			    "pp_instance", "servo");
		if (servo_off) {
			prefix = "ppsi.inst.0.servo";
			printf("%s at 0x%lx\n", prefix, servo_off);
			dump_many_fields(mapaddr + servo_off, "pp_servo",
					 prefix);
		}

		/* dump foreign masters */
		frgn_rec_num = wrpc_get_16(mapaddr + ppi_off + wrpc_get_offset("pp_instance", "frgn_rec_num"));
		frgn_m_off = ppi_off + wrpc_get_offset("pp_instance", "frgn_master");

		prefix = "ppsi.inst.0.frgn_master";
		printf("%s at 0x%lx\n", prefix, frgn_m_off);

		frgn_master_struct_size = wrpc_get_struct_size("pp_frgn_master");

		for (frgn_m_i = 0; frgn_m_i < frgn_rec_num && frgn_m_i < PP_NR_FOREIGN_RECORDS; frgn_m_i++) {
			snprintf(buff , sizeof(buff), "ppsi.inst.0.frgn_master.%i", frgn_m_i);
			dump_many_fields(mapaddr + frgn_m_off + frgn_m_i * frgn_master_struct_size,
					 "pp_frgn_master", buff);
		}

		protocol_extension = wrpc_get_i32(mapaddr + ppi_off + wrpc_get_offset("pp_instance", "protocol_extension"));
		(void)protocol_extension;
#if CONFIG_HAS_EXT_WR == 1
		if ( protocol_extension == PPSI_EXT_WR) {
			unsigned long ext_data_off;
			unsigned long ext_data_servo_off;
			unsigned long ext_data_servo_ext_off;

			ext_data_off = wrpc_get_pointer(mapaddr + ppi_off,
						"pp_instance", "ext_data");
			ext_data_servo_off = wrpc_get_offset("wr_data", "servo"); /* should be 0, but check it anyway */
			ext_data_servo_ext_off = wrpc_get_offset("wr_data", "servo_ext");

			printf("ppsi.inst.0.ext_date at 0x%lx\n", ext_data_off);
			prefix = "ppsi.inst.0.servo.wr";
			printf("%s at 0x%lx\n", prefix, ext_data_off + ext_data_servo_off);
			dump_many_fields(mapaddr + ext_data_off + ext_data_servo_off, "wrh_servo_t", prefix);
			prefix = "ppsi.inst.0.servo_ext.wr";
			printf("%s at 0x%lx\n", prefix, ext_data_off + ext_data_servo_ext_off);
			dump_many_fields(mapaddr + ext_data_off + ext_data_servo_ext_off, "wr_servo_ext_t", prefix);
		}
#endif
		/* FIXME: support multiple servo */
		portds_off = wrpc_get_pointer(mapaddr + ppi_off, "pp_instance",
					      "portDS");
		if (portds_off) {
			prefix = "ppsi.inst.0.portDS";
			printf("%s at 0x%lx\n", prefix, portds_off);
			dump_many_fields(mapaddr + portds_off, "portDS_t",
					 prefix);
		}
#if CONFIG_HAS_EXT_WR == 1
		if ( protocol_extension == PPSI_EXT_WR) {
			unsigned long ext_dsport_off;

			ext_dsport_off = wrpc_get_pointer(mapaddr + portds_off,
						"portDS_t", "ext_dsport");
			if (ext_dsport_off) {
				prefix = "ppsi.inst.0.wrportDS";
				printf("%s at 0x%lx\n", prefix, ext_dsport_off);
				dump_many_fields(mapaddr + ext_dsport_off,
						 "wr_dsport", prefix);
			}
		}
#endif
	}
}

int dump_one_field_type_ppsi_wrpc(int type, int size, void *p)
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
			i = wrpc_get_16(p);
		else
			i = wrpc_get_l32(p);
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

void dump_one_field_ppsi_wrpc(int type, int size, void *p, int i)
{
	struct pp_time *t = p;
	struct PortIdentity *pi = p;
	struct ClockQuality *cq = p;
	TimeInterval *ti=p;
	RelativeDifference *rd=p;
	char buf[128];
	char *char_p;

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
		printf("%lld\n", wrpc_get_64(p));
		break;

	case dump_type_Integer64:
		printf("%lld\n", wrpc_get_64(p));
		break;

	case dump_type_Integer32:
		printf("%i\n", wrpc_get_i32(p));
		break;

	case dump_type_UInteger32:
		printf("%li\n", wrpc_get_l32(p));
		break;

	case dump_type_UInteger8:
	case dump_type_Integer8:
	case dump_type_Enumeration8:
	case dump_type_UInteger4:
		printf("%i\n", *(unsigned char *)p);
		break;

	case dump_type_UInteger16:
	case dump_type_Integer16:
		printf("%i\n", wrpc_get_16(p));
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
		localt.secs = wrpc_get_64(&t->secs);
		localt.scaled_nsecs = wrpc_get_64(&t->scaled_nsecs);

		printf("correct %i: %25s rawps: 0x%04x\n",
		       !is_incorrect(&localt),
		       timeToString(&localt,buf),
		       (int)(localt.scaled_nsecs & 0xffff)
		      );
		break;
	}

	case dump_type_ClockIdentity: /* Same as binary */
		for (i = 0; i < sizeof(ClockIdentity); i++)
			printf("%02x%c", ((unsigned char *)p)[i],
			       i == sizeof(ClockIdentity) - 1 ? '\n' : ':');
		break;

	case dump_type_PortIdentity: /* Same as above plus port */
		for (i = 0; i < sizeof(ClockIdentity); i++)
			printf("%02x%c", ((unsigned char *)p)[i],
			       i == sizeof(ClockIdentity) - 1 ? '.' : ':');
		printf("%04x (%i)\n", wrpc_get_16(&pi->portNumber),
				      wrpc_get_16(&pi->portNumber));
		break;

	case dump_type_ClockQuality:
		printf("class %i, accuracy %02x (%i), logvariance %i\n",
		       cq->clockClass, cq->clockAccuracy, cq->clockAccuracy,
		       wrpc_get_16(&cq->offsetScaledLogVariance));
		break;

	case dump_type_TimeInterval:
		printf("%15s, ", timeIntervalToString(wrpc_get_64(ti), buf));
		printf("raw:  %15lld\n", wrpc_get_64(p));
		break;

	case dump_type_RelativeDifference:
		printf("%15s, ", relativeDifferenceToString(wrpc_get_64(rd), buf));
		printf("raw:  %15lld\n", wrpc_get_64(p));
		break;

	case dump_type_FixedDelta:
		/* FixedDelta has defined order of msb and lsb,
		 * which is different than in 64bit type (e.g. uint64_t) on host */
		printf("%lld\n", ((unsigned long long)wrpc_get_l32(p)
				  |((unsigned long long)wrpc_get_l32(p+4))<<32
				 )>>16);
		break;

	case dump_type_delay_mechanism:
		i = wrpc_get_i32(p);
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
		i = wrpc_get_i32(p);
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

	case dump_type_wrpc_mode_cfg:
		i = wrpc_get_i32(p);
		switch(i) {
		ENUM_TO_P_IN_CASE(WRC_MODE_UNKNOWN, char_p);
		ENUM_TO_P_IN_CASE(WRC_MODE_GM, char_p);
		ENUM_TO_P_IN_CASE(WRC_MODE_MASTER, char_p);
		ENUM_TO_P_IN_CASE(WRC_MODE_SLAVE, char_p);
		ENUM_TO_P_IN_CASE(WRC_MODE_ABSCAL, char_p);
		default:
			char_p = "Unknown";
		}
		printf("%d", i);
		print_str(char_p);
		printf("\n");
		break;

	case dump_type_timing_mode:
		i = wrpc_get_i32(p);
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

#if CONFIG_HAS_EXT_WR
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
#endif

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

#if CONFIG_HAS_EXT_WR
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
#endif

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
