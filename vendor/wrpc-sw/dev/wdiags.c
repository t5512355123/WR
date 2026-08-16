/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011-2021 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include <errno.h>
#include <string.h>

#include "board.h"
#include "dev/wdiags.h"
#include "wrc-debug.h"
#include "hw/rawmem.h"
#include "hw/wrc_diags_regs.h"

#define WDIAGS_VERSION 2

#if defined(BASE_WDIAGS_PRIV)
static void *wdiags_base = (void *)(BASE_WDIAGS_PRIV);
#else
static void *wdiags_base = NULL;
#endif


static int wdiag_write( uint32_t reg, uint32_t value )
{
	if( !wdiags_base )
		return -1;
	// fixme: there's a max of 64 diag registers.
	
	writel( value, (void*) ( wdiags_base + reg ) );
	return 0;
}

static uint32_t wdiag_read( uint32_t reg )
{
	if( !wdiags_base )
		return 0xdeadbeef;

	return readl( (void*) ( wdiags_base + reg )  );
}


int wdiag_set_valid(int enable)
{
	uint32_t ctl = wdiag_read( WRC_DIAGS_CTRL );
	if (enable)
	{
		wdiag_write( WRC_DIAGS_CTRL, ctl | WRC_DIAGS_CTRL_DATA_VALID );
	}
	else
	{
		wdiag_write( WRC_DIAGS_CTRL, ctl & ~WRC_DIAGS_CTRL_DATA_VALID );
	}

	return wdiag_read( WRC_DIAGS_CTRL );
}

int wdiag_get_valid(void)
{
	uint32_t ctl = wdiag_read( WRC_DIAGS_CTRL );

	return (ctl & WRC_DIAGS_CTRL_DATA_VALID ) ? 1 : 0;
}

int wdiag_get_snapshot(void)
{
	uint32_t ctl = wdiag_read( WRC_DIAGS_CTRL );

	return (ctl & WRC_DIAGS_CTRL_DATA_SNAPSHOT ) ? 1 : 0;
}

void wdiags_write_servo_state(int wr_mode, uint8_t servostate, uint64_t mu,
			      uint64_t dms, int32_t asym, int32_t cko,
			      int32_t setp, int32_t ucnt, uint32_t restart_cnt, uint64_t up_timestamp )
{
	uint32_t sstat   = wr_mode ? WRC_DIAGS_WDIAG_SSTAT_WR_MODE:0;
	sstat  |= servostate << WRC_DIAGS_WDIAG_SSTAT_SERVOSTATE_SHIFT;

	wdiag_write( WRC_DIAGS_WDIAG_SSTAT, sstat );
	wdiag_write( WRC_DIAGS_WDIAG_MU_MSB  , 0xFFFFFFFF & (mu>>32) );
	wdiag_write( WRC_DIAGS_WDIAG_MU_LSB  , 0xFFFFFFFF &  mu );
	wdiag_write( WRC_DIAGS_WDIAG_DMS_MSB , 0xFFFFFFFF & (dms>>32) );
	wdiag_write( WRC_DIAGS_WDIAG_DMS_LSB , 0xFFFFFFFF &  dms );
	wdiag_write( WRC_DIAGS_WDIAG_ASYM    , asym );
	wdiag_write( WRC_DIAGS_WDIAG_CKO     , cko );
	wdiag_write( WRC_DIAGS_WDIAG_SETP    , setp );
	wdiag_write( WRC_DIAGS_WDIAG_UCNT    , ucnt );
}

void wdiags_write_port_state(int link, int locked)
{
	uint32_t val = 0;

	val  = link   ? WRC_DIAGS_WDIAG_PSTAT_LINK   : 0;
	val |= locked ? WRC_DIAGS_WDIAG_PSTAT_LOCKED : 0;
	wdiag_write( WRC_DIAGS_WDIAG_PSTAT    , val );

	//pp_printf("wdiags_write_port_state: %x\n", val );
}

void wdiags_write_ptp_state(uint8_t ptpstate)
{
	wdiag_write( WRC_DIAGS_WDIAG_PTPSTAT, ptpstate << WRC_DIAGS_WDIAG_PTPSTAT_PTPSTATE_SHIFT );
}

void wdiags_write_aux_state(uint32_t aux_states)
{
	wdiag_write( WRC_DIAGS_WDIAG_ASTAT, aux_states << WRC_DIAGS_WDIAG_ASTAT_AUX_SHIFT );
}

void wdiags_write_cnts(uint32_t tx, uint32_t rx, uint32_t rx_errors)
{
	wdiag_write( WRC_DIAGS_WDIAG_TXFCNT, tx);
	wdiag_write( WRC_DIAGS_WDIAG_RXFCNT, rx);
	wdiag_write( WRC_DIAGS_WDIAG_RX_ERR_CNT, rx_errors);
}

void wdiags_write_ptp_debug(uint32_t rx_count, uint32_t tx_count,
			    uint8_t ptp_state, uint8_t pd_state,
			    uint8_t ext_state, uint8_t protocol_extension)
{
	/* AUX1/AUX2/AUX3 are not used by this one-output DE5a design's
	 * periodic auxiliary-clock loop. Reuse them only as read-only
	 * bring-up evidence for the PPSI receive path. */
	wdiag_write(WRC_DIAGS_WDIAG_AUX1_DETAIL_STAT, rx_count);
	wdiag_write(WRC_DIAGS_WDIAG_AUX2_DETAIL_STAT, tx_count);
	wdiag_write(WRC_DIAGS_WDIAG_AUX3_DETAIL_STAT,
		    ((uint32_t)protocol_extension << 24) |
		    ((uint32_t)ext_state << 16) |
		    ((uint32_t)pd_state << 8) |
		    (uint32_t)ptp_state);
}

void wdiags_write_ptp_debug_detail(uint32_t rx_type_counts,
				   uint32_t foreign_master_meta,
				   uint32_t filter_meta,
				   uint32_t parse_meta)
{
	/* 0x74..0x80 are unused by this build's regular diagnostic refresh. */
	wdiag_write(WRC_DIAGS_WDIAG_DELTA_RX_M, rx_type_counts);
	wdiag_write(WRC_DIAGS_WDIAG_DELTA_RX_S, foreign_master_meta);
	wdiag_write(WRC_DIAGS_WDIAG_DELTA_TX_M, filter_meta);
	wdiag_write(WRC_DIAGS_WDIAG_DELTA_TX_S, parse_meta);
}

void wdiags_write_time(uint64_t sec, uint32_t nsec)
{
	wdiag_write( WRC_DIAGS_WDIAG_SEC_MSB, 0xFFFFFFFF & (sec>>32) );
	wdiag_write( WRC_DIAGS_WDIAG_SEC_LSB, 0xFFFFFFFF &  sec );
	wdiag_write( WRC_DIAGS_WDIAG_NS,       nsec );
}

void wdiags_write_temp(uint32_t temp)
{
	wdiag_write( WRC_DIAGS_WDIAG_TEMP, temp );
}

void wdiags_write_wr_state_debug(uint32_t state)
{
	/* WDIAG_TEMP is unused on the DE5a builds without temperature sensors.
	 * The 0xA tag makes stale or unsupported values immediately visible. */
	wdiag_write( WRC_DIAGS_WDIAG_TEMP, state );
}

void wdiags_write_wr_signaling_debug(uint32_t rx, uint32_t tx, uint32_t failure)
{
	/* These registers are not written by the DE5a diagnostic task's
	 * normal servo path. Keep the raw message IDs and low counter words. */
	wdiag_write(WRC_DIAGS_WDIAG_SERVO_UPTIME_MSB, rx);
	wdiag_write(WRC_DIAGS_WDIAG_SERVO_UPTIME_LSB, tx);
	wdiag_write(WRC_DIAGS_WDIAG_SERVO_RESTART_COUNT, failure);
}

void wdiags_write_wr_lock_debug(uint32_t result, uint32_t polls,
					uint32_t unlocked, uint32_t calibration_fail,
					uint32_t enable_count, uint32_t spll_state)
{
	/* The DE5a diagnostic DPRAM has unused words after the standard map.
	 * Keep this shadow read-only: it never feeds back into WR control. */
	wdiag_write(0x8c, result);
	wdiag_write(0x90, polls);
	wdiag_write(0x94, unlocked);
	wdiag_write(0x98, calibration_fail);
	wdiag_write(0x9c, enable_count);
	wdiag_write(0xa0, spll_state);
}

void wdiags_set_base_address( void *base )
{
	wdiags_base = base;
}

int wdiags_init(void)
{
	int i;

	if( wdiags_base == NULL )
	{
		dev_dbg("wdiags: no base address specified.\n");
		return -1;
	}
	else
	{
		dev_dbg("wdiags: base addr = 0x%x.\n", wdiags_base );
	}

	for( i = 0; i < WRC_DIAGS_SIZE / 4; i++ )
		wdiag_write( i * 4, 0 );

	wdiag_write( WRC_DIAGS_VER, WDIAGS_VERSION );

	return 0;
}

void wdiags_write_aux_clock_details( int clk_id, uint32_t mode, uint32_t phase, int enabled, int ready )
{
	uint32_t reg;
	switch(clk_id)
	{
		case 0: reg = WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT; break;
		case 1: reg = WRC_DIAGS_WDIAG_AUX1_DETAIL_STAT; break;
		case 2: reg = WRC_DIAGS_WDIAG_AUX2_DETAIL_STAT; break;
		case 3: reg = WRC_DIAGS_WDIAG_AUX3_DETAIL_STAT; break;
		default: return;
	}

	uint32_t v = 0;

	v |= mode << WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_MODE_SHIFT;
	v |= (enabled ? WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_ENABLED : 0);
	v |= (ready ? WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_LOCKED : 0);
	v |= (phase << WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_PHASE_SHIFT) & WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_PHASE_MASK;

	wdiag_write( reg, v );
}

void wdiags_write_bitslide(int bitslide)
{
	wdiag_write( WRC_DIAGS_WDIAG_BITSLIDE, bitslide );
}

void wdiags_write_ptp_deltas( int dtxm, int drxm, int dtxs, int drxs )
{
	wdiag_write( WRC_DIAGS_WDIAG_DELTA_RX_M, drxm );
	wdiag_write( WRC_DIAGS_WDIAG_DELTA_RX_S, drxs );
	wdiag_write( WRC_DIAGS_WDIAG_DELTA_TX_M, dtxm );
	wdiag_write( WRC_DIAGS_WDIAG_DELTA_TX_S, dtxs );
}

void wdiags_write_pll_diags( int hy, int my )
{
	wdiag_write( WRC_DIAGS_WDIAG_SPLL_HY, hy );
	wdiag_write( WRC_DIAGS_WDIAG_SPLL_MY, my );
}
