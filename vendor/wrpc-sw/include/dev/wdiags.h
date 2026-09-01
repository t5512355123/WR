/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011-2021 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __WDIAGS_H
#define __WDIAGS_H

#include <stdint.h>

/* "FAUL" marks a complete persistent trap/fault record. */
#define WDIAGS_PERSISTENT_FAULT_MAGIC 0x4641554cU

int wdiag_set_valid(int enable);
int wdiag_get_valid(void);
int wdiag_get_snapshot(void);
/* Diagnostic-only atomic Helper PI snapshot transport. */
int wdiags_helper_pi_snapshot_request_pending(uint32_t *request_seq);
void wdiags_write_wr_spll_helper_pi_snapshot_ack(uint32_t request_seq);
void wdiags_write_servo_state(int wr_mode, uint8_t servostate, uint64_t mu,
			      uint64_t dms, int32_t asym, int32_t cko,
			      int32_t setp, int32_t ucnt, uint32_t restart_cnt, uint64_t up_timestamp );
void wdiags_write_port_state(int link, int locked);
void wdiags_write_ptp_state(uint8_t ptpstate);
/* Read-only boot-init execution evidence carried in PTPSTAT bits 8..31. */
void wdiags_write_boot_init_debug(uint32_t script_enter_count,
                                  uint32_t command_index,
                                  uint32_t mode_master_call_count,
                                  uint32_t mode_master_return_count);
/* Read-only sticky stage of the manual mode-master transition. */
#define WRC_DIAGS_MODE_MASTER_STAGE_NOT_ENTERED 0
#define WRC_DIAGS_MODE_MASTER_STAGE_ENTERED 1
#define WRC_DIAGS_MODE_MASTER_STAGE_BEFORE_SPLL_INIT 2
#define WRC_DIAGS_MODE_MASTER_STAGE_AFTER_SPLL_INIT 3
#define WRC_DIAGS_MODE_MASTER_STAGE_BEFORE_LOCK_WAIT 4
#define WRC_DIAGS_MODE_MASTER_STAGE_AFTER_LOCK_WAIT 5
void wdiags_write_mode_master_stage(uint32_t stage);
/* Read-only sticky sub-stage and timing shadow for lock-wait forensics. */
#define WRC_DIAGS_LOCK_WAIT_SUBSTAGE_NOT_ENTERED 0
#define WRC_DIAGS_LOCK_WAIT_SUBSTAGE_ENTERED 1
#define WRC_DIAGS_LOCK_WAIT_SUBSTAGE_AFTER_LOCK_CHECK 2
#define WRC_DIAGS_LOCK_WAIT_SUBSTAGE_BEFORE_SPLL_UPDATE 3
#define WRC_DIAGS_LOCK_WAIT_SUBSTAGE_AFTER_SPLL_UPDATE 4
#define WRC_DIAGS_LOCK_WAIT_SUBSTAGE_BEFORE_TIMER_DELAY 5
#define WRC_DIAGS_LOCK_WAIT_SUBSTAGE_AFTER_TIMER_DELAY 6
#define WRC_DIAGS_LOCK_WAIT_SUBSTAGE_AFTER_TIMEOUT_CHECK 7
#define WRC_DIAGS_LOCK_WAIT_SUBSTAGE_RETURN 8
void wdiags_write_lock_wait_debug(uint32_t substage,
                                   uint32_t iteration_count,
                                   uint32_t start_tics,
                                   uint32_t current_tics,
                                   int32_t last_lock_result);
/* Persistent read-only markers around spll_check_lock(0). */
#define WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_NOT_ENTERED 0
#define WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_BEFORE_CALL 1
#define WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_ENTERED 2
#define WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_AFTER_STATE_READ 3
#define WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_BEFORE_RETURN 4
#define WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_RETURNED 5
void wdiags_write_spll_check_lock_debug(uint32_t stage,
                                        uint32_t channel,
                                        uint32_t state_value);
/* Persistent read-only VUART-to-shell dispatch breadcrumbs. */
#define WRC_DIAGS_PERSISTENT_CMD_NO_EVIDENCE 0
#define WRC_DIAGS_PERSISTENT_CMD_RX_FIRST_BYTE 1
#define WRC_DIAGS_PERSISTENT_CMD_RX_ALL_BYTES 2
#define WRC_DIAGS_PERSISTENT_CMD_RX_NEWLINE 3
#define WRC_DIAGS_PERSISTENT_CMD_SHELL_LINE_READY 4
#define WRC_DIAGS_PERSISTENT_CMD_LOOKUP_MODE 5
#define WRC_DIAGS_PERSISTENT_CMD_MODE_HANDLER_ENTERED 6
#define WRC_DIAGS_PERSISTENT_CMD_MASTER_ARGUMENT 7
#define WRC_DIAGS_PERSISTENT_CMD_BEFORE_SET_MODE 8
#define WRC_DIAGS_PERSISTENT_CMD_SET_MODE_ENTERED 9
void wdiags_write_shell_command_rx_byte(uint32_t byte_value);
void wdiags_write_shell_command_stage(uint32_t stage);
/* Persistent interactive VUART newline-to-dispatch microtrace. */
#define WRC_DIAGS_PERSISTENT_CMD_MICRO_IDLE 0
#define WRC_DIAGS_PERSISTENT_CMD_MICRO_NEWLINE_DETECTED 1
#define WRC_DIAGS_PERSISTENT_CMD_MICRO_LINE_READY_SCHEDULED 2
#define WRC_DIAGS_PERSISTENT_CMD_MICRO_SHELL_POLL_LINE_READY 3
#define WRC_DIAGS_PERSISTENT_CMD_MICRO_BUFFER_TERMINATED 4
#define WRC_DIAGS_PERSISTENT_CMD_MICRO_SHELL_EXEC_ENTERED 5
#define WRC_DIAGS_PERSISTENT_CMD_MICRO_TOKEN_PARSED 6
#define WRC_DIAGS_PERSISTENT_CMD_MICRO_MODE_LOOKUP_MATCHED 7
#define WRC_DIAGS_PERSISTENT_CMD_MICRO_MODE_HANDLER_ENTERED 8
#define WRC_DIAGS_PERSISTENT_CMD_MICRO_MASTER_ARGUMENT_MATCHED 9
void wdiags_write_shell_command_micro_stage(uint32_t stage,
                                            uint32_t command_length,
                                            uint32_t command_pos,
                                            uint32_t line_ready,
                                            uint32_t shell_state,
                                            const char *command_buffer);
/* Read-only per-boot shell-ready gate. The markers are intentionally
 * generation-tagged so a stale pre-reentry value cannot arm a stimulus. */
void wdiags_write_firmware_shell_ready_debug(uint32_t main_loop_reached,
                                             uint32_t shell_poll_reached,
                                             uint32_t boot_init_done,
                                             uint32_t main_loop_generation,
                                             uint32_t shell_poll_generation,
                                             uint32_t boot_init_generation,
                                             uint32_t current_generation);
/* Read-only static-p startup-lifetime checkpoints. */
#define WRC_DIAGS_BOOT_STARTUP_STAGE_P_AT_RESET_EARLY 0
#define WRC_DIAGS_BOOT_STARTUP_STAGE_P_AFTER_BSS_DATA_INIT 1
#define WRC_DIAGS_BOOT_STARTUP_STAGE_P_AFTER_BOARD_INIT 2
#define WRC_DIAGS_BOOT_STARTUP_STAGE_P_AFTER_SHELL_INIT 3
#define WRC_DIAGS_BOOT_STARTUP_STAGE_P_BEFORE_SHELL_BOOT_SCRIPT 4
#define WRC_DIAGS_BOOT_STARTUP_STAGE_P_AT_BOOT_SCRIPT_ENTRY 5
#define WRC_DIAGS_BOOT_STARTUP_STAGE_COUNT 6
void wdiags_boot_startup_reset(void);
void wdiags_boot_startup_checkpoint(uint32_t stage, uint32_t p_offset);
/* Read-only VLAN/pfilter boot-progress checkpoints in the mapping words. */
void wdiags_vlan_cmd_enter(void);
void wdiags_pfilter_enter(void);
void wdiags_pfilter_before_disable(void);
void wdiags_pfilter_rule_index(uint32_t index);
void wdiags_pfilter_after_rule_write(void);
void wdiags_pfilter_before_enable(void);
void wdiags_pfilter_return(void);
void wdiags_vlan_cmd_return(void);
void wdiags_write_aux_state(uint32_t aux_states);
void wdiags_write_cnts(uint32_t tx, uint32_t rx, uint32_t rx_errors);
/* 診斷版：保存 PPSI 收發計數與協定狀態，不改變 WR 控制流程。 */
void wdiags_write_ptp_debug(uint32_t rx_count, uint32_t tx_count,
                            uint8_t ptp_state, uint8_t pd_state,
                            uint8_t ext_state, uint8_t protocol_extension);
void wdiags_write_ptp_debug_detail(uint32_t rx_type_counts,
                                   uint32_t foreign_master_meta,
                                   uint32_t filter_meta,
                                   uint32_t parse_meta);
void wdiags_write_time(uint64_t sec, uint32_t nsec);
void wdiags_write_temp(uint32_t temp);
/* Read-only WR extension state shadow for DE5a bring-up diagnostics. */
void wdiags_write_wr_state_debug(uint32_t state);
void wdiags_write_wr_signaling_debug(uint32_t rx, uint32_t tx, uint32_t failure);
void wdiags_write_wr_signaling_reject_debug(uint32_t reject_count,
                                            uint8_t reject_reason);
void wdiags_write_wr_lock_debug(uint32_t result, uint32_t polls,
					uint32_t unlocked, uint32_t calibration_fail,
					uint32_t enable_count, uint32_t spll_state);
/* Read-only SoftPLL hardware and lock-detector shadow for WR bring-up. */
void wdiags_write_wr_spll_hw_debug(uint32_t ocer, uint32_t rcer,
                                   uint32_t occr, uint32_t trr_csr,
                                   uint32_t dac_hpll, uint32_t dac_main,
                                   uint32_t helper_state, uint32_t helper_limits,
                                   uint32_t main_state, uint32_t main_limits,
                                   uint32_t main_phase_limits);
void wdiags_write_wr_spll_activity_debug(uint32_t ref_count, uint32_t tag_count,
                                         int32_t helper_error, int32_t helper_output,
                                         uint32_t state_visit_mask,
                                         uint32_t state_transition_count,
                                         uint32_t last_state,
                                         uint32_t irq_count,
                                         uint32_t irq_mask,
                                         uint32_t irq_status);
/* Read-only hardware event counters: tag arbitration and FIFO writes. */
void wdiags_write_wr_spll_event_debug(uint32_t tag_valid_count,
                                      uint32_t trr_write_count);
/* Read-only firmware-side count of successful TRR FIFO pops. */
void wdiags_write_wr_spll_trr_pop_count(uint32_t trr_pop_count);
/* Read-only helper tag/error correlation shadow. */
void wdiags_write_wr_spll_helper_correlation(int32_t last_tag,
                                             int32_t expected_tag,
                                             int32_t preclamp_error,
                                             int32_t tag_delta,
                                             int32_t tag_source,
                                             int32_t expected_delta,
                                             uint32_t update_count,
                                             int32_t p_adder,
                                             int32_t tag_d0,
                                             int32_t p_setpoint,
                                             int32_t ref_src);
/* Read-only register-map self-test for DE5a JTAG observability. */
void wdiags_write_mapping_self_test(uint32_t counter);
void wdiags_write_wr_spll_runtime_debug(uint32_t init_count,
						 uint32_t clear_dacs_count,
						 uint32_t current_tics,
						 uint32_t dac_timeout,
						 uint32_t last_init_tics,
						 uint32_t last_clear_dacs_tics);
/* Read-only attribution of spll_init() call sites. */
void wdiags_write_wr_spll_reinit_debug(uint32_t last_reason,
						uint32_t last_mode,
						uint32_t last_flags,
						uint32_t last_reason_tics,
						const uint32_t *reason_counts,
						uint32_t reason_count);
/* Read-only coherent Helper-update measurement snapshot. The caller must
 * provide values captured from one accepted helper_update() invocation. */
void wdiags_write_wr_spll_helper_measurement_debug(uint32_t measurement_epoch,
                                                   int32_t tag_delta,
                                                   int32_t expected_delta,
                                                   int32_t freq_error,
                                                   int32_t preclamp_error,
                                                   int32_t helper_error,
                                                   uint32_t helper_update_count,
                                                   int32_t helper_output,
                                                   uint32_t dmtd_ref_accept_count,
                                                   uint32_t dmtd_fb_accept_count);
/* Read-only Helper PI/rail causality snapshot.  This is a diagnostic overlay
 * only; signed 64-bit values are transported as native int64_t values and
 * published with an epoch seqlock in the implementation. */
void wdiags_write_wr_spll_helper_pi_trace(
                                                   uint32_t trace_epoch,
                                                   int32_t tag_raw,
                                                   int32_t p_adder,
                                                   int32_t p_setpoint,
                                                   int32_t raw_error,
                                                   int32_t ld_error,
                                                   uint32_t lock_state,
                                                   int64_t integrator_before,
                                                   int64_t i_new,
                                                   int64_t integrator_after,
                                                   int64_t prop_term,
                                                   int64_t y_preround,
                                                   int32_t unclamped_output,
                                                   int32_t y_min,
                                                   int32_t y_max,
                                                   int32_t clamp_side,
                                                   int32_t final_output,
                                                   int32_t x,
                                                   int32_t kp,
                                                   int32_t ki,
                                                   int32_t shift,
                                                   int32_t bias,
                                                   int32_t anti_windup,
                                                   uint32_t update_count,
                                                   int32_t freq_error,
                                                   int32_t lock_threshold,
                                                   int32_t lock_samples,
                                                   int32_t ref_src,
                                                   uint32_t snapshot_generation);
void wdiags_write_aux_clock_details( int clk_id, uint32_t mode, uint32_t phase, int enabled, int ready );
int wdiags_init(void);
void wdiags_write_bitslide(int bitslide);
void wdiags_write_ptp_deltas( int dtxm, int drxm, int dtxs, int drxs );
void wdiags_set_base_address( void *base );
void wdiags_write_bitslide(int bitslide);
void wdiags_write_ptp_deltas( int dtxm, int drxm, int dtxs, int drxs );
void wdiags_write_pll_diags( int hy, int my );

#endif
