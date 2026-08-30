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

/* Keep the existing read-only WDIAGS shadow current at the cadence used by
 * the long-lock convergence observer. This changes observability only. */
#define WRC_DIAG_REFRESH_PERIOD (TICS_PER_SECOND / 10)

int wrc_wr_diags(void)
{
	static uint32_t last_update_tick;
	static uint32_t mapping_self_test_counter;
	struct wrc_netif_device *ndev = netif_get_device(0);
	int tx, rx, rx_err;
	uint64_t sec;
	uint32_t nsec;
	int n_out;
	uint32_t aux_stat = 0;
	int temp = 0, valid = 0, snapshot = 0, i;
	uint32_t measurement_epoch_before, measurement_epoch_after;
	uint32_t measurement_epoch = 0xffffffffu;
	uint32_t measurement_update_count = 0;
	uint32_t measurement_ref_accept_count = 0;
	uint32_t measurement_fb_accept_count = 0;
	int32_t measurement_tag_delta = 0;
	int32_t measurement_expected_delta = 0;
	int32_t measurement_freq_error = 0;
	int32_t measurement_preclamp_error = 0;
	int32_t measurement_helper_error = 0;
	int32_t measurement_output = 0;
	int measurement_snapshot_valid;
	uint32_t pi_trace_epoch = 0xffffffffu;
	uint32_t pi_trace_lock_state = 0;
	uint32_t pi_trace_update_count = 0;
	int32_t pi_trace_tag_raw = 0;
	int32_t pi_trace_p_adder = 0;
	int32_t pi_trace_p_setpoint = 0;
	int32_t pi_trace_raw_error = 0;
	int32_t pi_trace_ld_error = 0;
	int64_t pi_trace_integrator_before = 0;
	int64_t pi_trace_i_new = 0;
	int64_t pi_trace_integrator_after = 0;
	int64_t pi_trace_prop_term = 0;
	int64_t pi_trace_y_preround = 0;
	int32_t pi_trace_unclamped_output = 0;
	int32_t pi_trace_y_min = 0;
	int32_t pi_trace_y_max = 0;
	int32_t pi_trace_clamp_side = 0;
	int32_t pi_trace_final_output = 0;
	int32_t pi_trace_x = 0;
	int32_t pi_trace_kp = 0;
	int32_t pi_trace_ki = 0;
	int32_t pi_trace_shift = 0;
	int32_t pi_trace_bias = 0;
	int32_t pi_trace_anti_windup = 0;
	int32_t pi_trace_freq_error = 0;
	int32_t pi_trace_lock_threshold = 0;
	int32_t pi_trace_lock_samples = 0;
	int32_t pi_trace_ref_src = 0;
	int pi_trace_snapshot_valid;

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
			wdiags_write_wr_spll_trr_pop_count(
				wrpc_spll_trr_pop_count);
			wdiags_write_wr_spll_helper_correlation(
				wrpc_spll_helper_last_tag,
				wrpc_spll_helper_expected_tag,
				wrpc_spll_helper_preclamp_error,
				wrpc_spll_helper_tag_delta,
				wrpc_spll_helper_tag_source,
				wrpc_spll_helper_expected_delta,
				wrpc_spll_helper_update_count,
				wrpc_spll_helper_p_adder,
				wrpc_spll_helper_tag_d0,
					wrpc_spll_helper_p_setpoint,
					wrpc_spll_helper_ref_src);
			wdiags_write_mapping_self_test(++mapping_self_test_counter);
			wdiags_write_wr_spll_runtime_debug(
				wrpc_spll_init_count,
				wrpc_spll_clear_dacs_entry_count,
				timer_get_tics(),
				softpll.dac_timeout,
				wrpc_spll_last_init_tics,
				wrpc_spll_last_clear_dacs_tics);
			wdiags_write_wr_spll_reinit_debug(
				wrpc_spll_last_init_reason,
				wrpc_spll_last_init_reason_mode,
				wrpc_spll_last_init_reason_flags,
				wrpc_spll_last_init_reason_tics,
				(const uint32_t *)wrpc_spll_init_reason_counts,
				WRPC_SPLL_INIT_REASON_COUNT);

			/* Copy one complete Helper invocation from the RAM seqlock.  The
			 * source payload is captured in helper_update(); WDIAGS is only a
			 * slower transport window for the passive JTAG observer. */
			measurement_snapshot_valid = 0;
			pi_trace_snapshot_valid = 0;
			for (i = 0; i < 4 && !measurement_snapshot_valid; i++) {
				measurement_epoch_before =
					wrpc_spll_helper_measurement_epoch;
				if (measurement_epoch_before & 1u)
					continue;
				measurement_tag_delta =
					wrpc_spll_helper_measurement_tag_delta;
				measurement_expected_delta =
					wrpc_spll_helper_measurement_expected_delta;
				measurement_freq_error =
					wrpc_spll_helper_measurement_freq_error;
				measurement_preclamp_error =
					wrpc_spll_helper_measurement_preclamp_error;
				measurement_helper_error =
					wrpc_spll_helper_measurement_error;
				measurement_update_count =
					wrpc_spll_helper_measurement_update_count;
				measurement_output =
					wrpc_spll_helper_measurement_output;
				measurement_ref_accept_count =
					wrpc_spll_helper_measurement_dmtd_ref_accept_count;
				measurement_fb_accept_count =
					wrpc_spll_helper_measurement_dmtd_fb_accept_count;
				pi_trace_tag_raw = wrpc_spll_helper_last_tag;
				pi_trace_p_adder = wrpc_spll_helper_p_adder;
				/* The error is formed against expected_tag before the next
				 * setpoint is advanced by one HPLL period. */
				pi_trace_p_setpoint = wrpc_spll_helper_expected_tag;
				pi_trace_raw_error = measurement_preclamp_error;
				pi_trace_ld_error = measurement_helper_error;
				pi_trace_lock_state =
					((uint32_t)(softpll.helper.ld.locked ? 1u : 0u)) |
					(((uint32_t)softpll.helper.ld.lock_cnt & 0xffffu) << 16);
				pi_trace_integrator_before =
					softpll.helper.pi.trace_integrator_before;
				pi_trace_i_new = softpll.helper.pi.trace_i_new;
				pi_trace_integrator_after =
					softpll.helper.pi.trace_integrator_after;
				pi_trace_x = softpll.helper.pi.trace_x;
				pi_trace_kp = softpll.helper.pi.kp;
				pi_trace_ki = softpll.helper.pi.ki;
				pi_trace_shift = softpll.helper.pi.shift;
				pi_trace_bias = softpll.helper.pi.bias;
				pi_trace_anti_windup = softpll.helper.pi.anti_windup;
				pi_trace_prop_term =
					(int64_t)pi_trace_x * (int64_t)pi_trace_kp;
				pi_trace_y_preround = pi_trace_i_new + pi_trace_prop_term;
				if (pi_trace_shift > 0)
					pi_trace_y_preround +=
						((int64_t)1 << (pi_trace_shift - 1));
				pi_trace_unclamped_output =
					softpll.helper.pi.trace_y_unclamped;
				pi_trace_y_min = softpll.helper.pi.y_min;
				pi_trace_y_max = softpll.helper.pi.y_max;
				pi_trace_clamp_side = softpll.helper.pi.trace_clamp_side;
				pi_trace_final_output = softpll.helper.pi.trace_y_clamped;
				pi_trace_update_count = measurement_update_count;
				pi_trace_freq_error = measurement_freq_error;
				pi_trace_lock_threshold = softpll.helper.ld.threshold;
				pi_trace_lock_samples = softpll.helper.ld.lock_samples;
				pi_trace_ref_src = softpll.helper.ref_src;
				measurement_epoch_after =
					wrpc_spll_helper_measurement_epoch;
				if (measurement_epoch_before == measurement_epoch_after &&
				    !(measurement_epoch_after & 1u)) {
					measurement_epoch = measurement_epoch_after;
					measurement_snapshot_valid = 1;
					pi_trace_epoch = measurement_epoch_after;
					pi_trace_snapshot_valid = 1;
				}
			}
			wdiags_write_wr_spll_helper_measurement_debug(
				measurement_epoch,
				measurement_tag_delta,
				measurement_expected_delta,
				measurement_freq_error,
				measurement_preclamp_error,
				measurement_helper_error,
				measurement_update_count,
				measurement_output,
				measurement_ref_accept_count,
				measurement_fb_accept_count);
			wdiags_write_wr_spll_helper_pi_trace(
				pi_trace_snapshot_valid ? pi_trace_epoch : 0xffffffffu,
				pi_trace_tag_raw,
				pi_trace_p_adder,
				pi_trace_p_setpoint,
				pi_trace_raw_error,
				pi_trace_ld_error,
				pi_trace_lock_state,
				pi_trace_integrator_before,
				pi_trace_i_new,
				pi_trace_integrator_after,
				pi_trace_prop_term,
				pi_trace_y_preround,
				pi_trace_unclamped_output,
				pi_trace_y_min,
				pi_trace_y_max,
				pi_trace_clamp_side,
				pi_trace_final_output,
				pi_trace_x,
				pi_trace_kp,
				pi_trace_ki,
				pi_trace_shift,
				pi_trace_bias,
				pi_trace_anti_windup,
				pi_trace_update_count,
				pi_trace_freq_error,
				pi_trace_lock_threshold,
				pi_trace_lock_samples,
				pi_trace_ref_src);

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
