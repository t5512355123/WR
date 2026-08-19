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

int wdiag_set_valid(int enable);
int wdiag_get_valid(void);
int wdiag_get_snapshot(void);
void wdiags_write_servo_state(int wr_mode, uint8_t servostate, uint64_t mu,
			      uint64_t dms, int32_t asym, int32_t cko,
			      int32_t setp, int32_t ucnt, uint32_t restart_cnt, uint64_t up_timestamp );
void wdiags_write_port_state(int link, int locked);
void wdiags_write_ptp_state(uint8_t ptpstate);
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
void wdiags_write_aux_clock_details( int clk_id, uint32_t mode, uint32_t phase, int enabled, int ready );
int wdiags_init(void);
void wdiags_write_bitslide(int bitslide);
void wdiags_write_ptp_deltas( int dtxm, int drxm, int dtxs, int drxs );
void wdiags_set_base_address( void *base );
void wdiags_write_bitslide(int bitslide);
void wdiags_write_ptp_deltas( int dtxm, int drxm, int dtxs, int drxs );
void wdiags_write_pll_diags( int hy, int my );

#endif
