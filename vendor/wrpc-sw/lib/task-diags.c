/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2021 CERN
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

/* This periodic task is responsible of updating diagnostics
   data (in wdiags) */

#include <inttypes.h>
#include "wrc-task.h"
#include "ppsi/ppsi.h"
#include "wrpc.h"
#include "dev/wdiags.h"
#include "dev/temperature.h"
#include "softpll/softpll_ng.h"
#include "dev/netif.h"
#include "dev/pps_gen.h"
#include "wrc_global.h"

#define WRC_DIAG_REFRESH_PERIOD (1 * TICS_PER_SECOND)

int wrc_wr_diags(void)
{
	static uint32_t last_update_tick;
	struct wrc_netif_device *ndev = netif_get_device(0);
	int tx, rx, rx_err;
	uint64_t sec;
	uint32_t nsec;
	int n_out;
	uint32_t aux_stat = 0;
	int temp = 0, valid = 0, snapshot = 0, i;

	struct pp_instance *ppi = ppg->pp_instances;
	valid    = wdiag_get_valid();
	snapshot = wdiag_get_snapshot();

	/* if the data is snapshot and there is already valid data, do not
	 * refresh */
	if (valid & snapshot)
	      return 0;

	/* ***************** lock data from reading by user **************** */
	/* stats update condition */
	if (wrc_task_not_yet(&last_update_tick, WRC_DIAG_REFRESH_PERIOD))
		return 0;

	/* ***************** lock data from reading by user **************** */
	wdiag_set_valid(0);
	
	/* frame statistics */
	minic_get_stats(ndev->nic, &tx, &rx, &rx_err);
	wdiags_write_cnts(tx, rx, rx_err);

	/* local time */
	shw_pps_gen_get_time(&sec, &nsec);
	wdiags_write_time(sec, nsec);

	/* port state */
	wdiags_write_port_state
	  ((wrc_global_link.link_up == NETIF_LINK_UP), spll_check_lock(0));

	/* port PTP State (from ppsi)
	* see: ppsi/include/ppsi/ieee1588_types.h
	0  : none
	1  : PPS_INITIALIZING
	2  : PPS_FAULTY
	3  : PPS_DISABLED
	4  : PPS_LISTENING
	5  : PPS_PRE_MASTER
	6  : PPS_MASTER
	7  : PPS_PASSIVE
	8  : PPS_UNCALIBRATED
	9  : PPS_SLAVE
	*/
	wdiags_write_ptp_state((uint8_t)ppi->state);
	/* Preserve PPSI-side counters separately from the Mini-NIC counters.
	 * The metadata high byte carries the configured WRC mode during bring-up
	 * so Master/Slave role selection is directly visible over JTAG. */
	wdiags_write_ptp_debug((uint32_t)ppi->ptp_rx_count,
			       (uint32_t)ppi->ptp_tx_count,
			       (uint8_t)ppi->state,
			       (uint8_t)ppi->pdstate,
			       (uint8_t)ppi->extState,
			       (uint8_t)wrc_ptp_get_mode());
	/* 診斷版：拆出訊息類型與 foreign-master/WR-parent 判斷。 */
	{
		uint32_t rx_type_counts =
			((uint32_t)wrpc_ptp_rx_sync_count & 0xff) |
			(((uint32_t)wrpc_ptp_rx_announce_count & 0xff) << 8) |
			(((uint32_t)wrpc_ptp_rx_followup_count & 0xff) << 16) |
			(((uint32_t)wrpc_ptp_rx_signaling_count & 0xff) << 24);
		uint32_t foreign_master_meta =
			((uint32_t)ppi->frgn_rec_num & 0xff) |
			(((uint32_t)(ppi->frgn_rec_best < 0 ? 0xff : ppi->frgn_rec_best) & 0xff) << 8);
		uint32_t filter_meta =
			((uint32_t)wrpc_ptp_prefilter_wrong_domain_count & 0xff) |
			(((uint32_t)wrpc_ptp_prefilter_alternate_master_count & 0xff) << 8) |
			(((uint32_t)wrpc_ptp_prefilter_same_port_count & 0xff) << 16) |
			(((uint32_t)wrpc_ptp_prefilter_same_clock_count & 0xff) << 24);
		uint32_t parse_meta =
			((uint32_t)wrpc_ptp_frame_parse_error_count & 0xff) |
			(((uint32_t)wrpc_ptp_rx_announce_processed_count & 0xff) << 8) |
			(((uint32_t)wrpc_ptp_rx_announce_added_count & 0xff) << 16);
#if CONFIG_HAS_EXT_WR
		struct wr_dsport *wrp = WR_DSPOR(ppi);
		uint32_t parent_flags =
			(wrp->parentIsWRnode ? 1 : 0) |
			((wrp->parentWrModeOn ? 1 : 0) << 1) |
			((wrp->parentCalibrated ? 1 : 0) << 2);
		foreign_master_meta |= ((uint32_t)wrp->parentDetection & 0xff) << 16;
		foreign_master_meta |= ((uint32_t)wrp->parentWrConfig & 0xff) << 24;
		parse_meta |= (parent_flags & 0x7) << 24;
#endif
		wdiags_write_ptp_debug_detail(rx_type_counts,
					      foreign_master_meta,
					      filter_meta,
					      parse_meta);

		/* DE5a has no temperature sensor. Reuse the otherwise idle register
		 * as a read-only shadow of the WR extension state. This does not feed
		 * back into PPSI, the servo, or the clock actuator. */
		if (!HAS_TEMP_SENSORS) {
			uint32_t wr_state_debug = 0xA0000000u |
				((uint32_t)(wrp->wrModeOn ? 1 : 0) << 0) |
				((uint32_t)(wrp->parentWrModeOn ? 1 : 0) << 1) |
				((uint32_t)(wrp->calibrated ? 1 : 0) << 2) |
				((uint32_t)(wrp->parentIsWRnode ? 1 : 0) << 3) |
				((uint32_t)(wrp->parentCalibrated ? 1 : 0) << 4) |
				(((uint32_t)wrp->wrConfig & 0x7u) << 5) |
				(((uint32_t)wrp->parentWrConfig & 0x7u) << 8) |
				(((uint32_t)wrp->state & 0xfu) << 11) |
				(((uint32_t)wrp->next_state & 0xfu) << 15) |
				(((uint32_t)wrp->parentDetection & 0x3u) << 19) |
				(((uint32_t)wrp->wrMode & 0x7u) << 21);
			wdiags_write_wr_state_debug(wr_state_debug);
			wdiags_write_wr_signaling_debug(
				(((uint32_t)wrpc_wr_last_rx_msg_id & 0xffffu) << 16) |
				 (wrpc_wr_rx_signaling_count & 0xffffu),
				(((uint32_t)wrpc_wr_last_tx_msg_id & 0xffffu) << 16) |
				 (wrpc_wr_tx_signaling_count & 0xffffu),
				(((uint32_t)wrpc_wr_last_fail_role & 0xffu) << 24) |
				(((uint32_t)wrpc_wr_last_fail_state & 0xffu) << 16) |
				 (wrpc_wr_handshake_fail_count & 0xffffu));
			wdiags_write_wr_signaling_reject_debug(
				wrpc_wr_rx_signal_reject_count,
				wrpc_wr_last_rx_signal_reject_reason);
			wdiags_write_wr_lock_debug(
				(uint32_t)wrpc_wr_lock_last_result |
					((uint32_t)(spll_check_lock(0) ? 1u : 0u) << 8),
				wrpc_wr_lock_poll_count,
				wrpc_wr_lock_unlocked_count,
				wrpc_wr_lock_calibration_fail_count,
				wrpc_wr_lock_enable_count,
				((uint32_t)softpll.seq_state & 0xffu) |
					(((uint32_t)softpll.ext.align_state & 0xffu) << 8) |
				(((uint32_t)softpll.mode & 0xffu) << 16) |
				(((uint32_t)softpll.delock_count & 0xffu) << 24));
			wdiags_write_wr_spll_hw_debug(
				SPLL->OCER,
				SPLL->RCER,
				SPLL->OCCR,
				SPLL->TRR_CSR,
				SPLL->DAC_HPLL,
				SPLL->DAC_MAIN,
				((uint32_t)(softpll.helper.ld.locked ? 1u : 0u)) |
					((uint32_t)(softpll.helper.ld.lock_changed ? 1u : 0u) << 1) |
					(((uint32_t)softpll.helper.ref_src & 0xffu) << 8) |
					(((uint32_t)softpll.helper.ld.lock_cnt & 0xffffu) << 16),
				((uint32_t)softpll.helper.ld.threshold & 0xffffu) |
					(((uint32_t)softpll.helper.ld.lock_samples & 0xffffu) << 16),
				((uint32_t)(softpll.mpll.enabled ? 1u : 0u)) |
					((uint32_t)(softpll.mpll.locked ? 1u : 0u) << 1) |
					((uint32_t)(softpll.mpll.freq_ld.locked ? 1u : 0u) << 2) |
					((uint32_t)(softpll.mpll.phase_ld.locked ? 1u : 0u) << 3) |
					(((uint32_t)softpll.mpll.freq_ld.lock_cnt & 0xfffu) << 8) |
					(((uint32_t)softpll.mpll.phase_ld.lock_cnt & 0xfffu) << 20),
				((uint32_t)softpll.mpll.freq_ld.threshold & 0xffffu) |
					(((uint32_t)softpll.mpll.freq_ld.lock_samples & 0xffffu) << 16),
				((uint32_t)softpll.mpll.phase_ld.threshold & 0xffffu) |
					(((uint32_t)softpll.mpll.phase_ld.lock_samples & 0xffffu) << 16));
			wdiags_write_wr_spll_activity_debug(
				softpll.ref_count,
				softpll.tag_count,
				softpll.helper.pi.x,
				softpll.helper.pi.y,
				wrpc_spll_state_visit_mask,
				wrpc_spll_state_transition_count,
				wrpc_spll_last_state,
				softpll.irq_count,
				SPLL->EIC_IMR,
				SPLL->EIC_ISR);
			wdiags_write_wr_spll_event_debug(
				SPLL->TAG_VALID_COUNT,
				SPLL->TRR_WRITE_COUNT);
		}
	}

	
	/* servo state (if slave)s */
	if (wrc_ptp_get_mode() == WRC_MODE_SLAVE) {
		struct pp_servo *s = SRV(ppg->pp_instances);
		
		struct wrh_servo_t *wrh_servo = NULL;
		int32_t asym;
		int wr_mode;
		int32_t cur_setpoint_ps = 0;
		uint64_t mu = 0;

		asym = interval_to_picos(ppi_static.portDS->delayAsymmetry);
		wr_mode = (s->flags & PP_SERVO_FLAG_VALID) ? 1 : 0;

		wrh_servo = (ppi_static.protocol_extension == PPSI_EXT_WR && ppi_static.extState == PP_EXSTATE_ACTIVE) ?
			    (wrh_servo_t*) ppi_static.ext_data : NULL;

		if (wrh_servo) {
#if CONFIG_HAS_EXT_WR
			struct wr_servo_ext *wr_servo_ext =
				&((struct wr_data *)wrh_servo)->servo_ext;
			mu = pp_time_to_picos(&wr_servo_ext->rawDelayMM),
#endif
			cur_setpoint_ps = wrh_servo->cur_setpoint_ps;
		}

		/* see ppsi/include/hw-specific/wrh.h:
		0: WRH_UNINITIALIZED = 0,
		1: WRH_SYNC_TAI,
		2: WRH_SYNC_NSEC,
		3: WRH_SYNC_PHASE,
		4: WRH_TRACK_PHASE,
		5: WRH_WAIT_OFFSET_STABLE */
		wdiags_write_servo_state(wr_mode,
					 s->state,
					 mu,
					 pp_time_to_picos(&s->delayMS),
					 asym,
					 (int32_t) pp_time_to_picos(&s->offsetFromMaster),
					 cur_setpoint_ps,
					 ppi_static.servo->update_count, 0, 0);
	}

	/* Auxiliar channels (if any) */
	spll_get_num_channels(NULL, &n_out);
	if (n_out > 8) n_out = 8; /* hardware limit. */
	for (i = 0; i < n_out - 1; i++) {
		struct spll_aux_clock_status status = spll_get_aux_status( i );
		aux_stat |= ((SPLL_AUX_SLAVE_LOCKED | SPLL_AUX_MONITOR_READY) & status.flags) << i;

		wdiags_write_aux_clock_details( i, status.mode, status.phase, status.flags & SPLL_AUX_MONITOR_ENABLED, status.flags & SPLL_AUX_MONITOR_READY );

	}
	wdiags_write_aux_state(aux_stat);

	/* temperature */
	if (HAS_TEMP_SENSORS) {
		temp = wrc_temp_get("pcb");
		wdiags_write_temp(temp);
	}

	/* **************** unlock data from reading by user  ************** */
	wdiag_set_valid(1);
	return 1;
}
