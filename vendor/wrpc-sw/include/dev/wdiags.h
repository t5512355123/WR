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
void wdiags_write_time(uint64_t sec, uint32_t nsec);
void wdiags_write_temp(uint32_t temp);
void wdiags_write_aux_clock_details( int clk_id, uint32_t mode, uint32_t phase, int enabled, int ready );
int wdiags_init(void);
void wdiags_write_bitslide(int bitslide);
void wdiags_write_ptp_deltas( int dtxm, int drxm, int dtxs, int drxs );
void wdiags_set_base_address( void *base );
void wdiags_write_bitslide(int bitslide);
void wdiags_write_ptp_deltas( int dtxm, int drxm, int dtxs, int drxs );
void wdiags_write_pll_diags( int hy, int my );

#endif
