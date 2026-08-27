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
#define WDIAGS_PERSISTENT_MAGIC 0x504D5354U /* "PMST" */

extern volatile uint32_t debug_precrt_boot_generation;
extern volatile uint32_t debug_precrt_persistent_magic;
extern volatile uint32_t debug_precrt_persistent_mode_master_stage;
extern volatile uint32_t debug_precrt_persistent_lock_wait_substage;
extern volatile uint32_t debug_precrt_persistent_boot_generation_at_stage;
extern volatile uint32_t debug_precrt_persistent_stage_history[4];

#if defined(BASE_WDIAGS_PRIV)
static void *wdiags_base = (void *)(BASE_WDIAGS_PRIV);
#else
static void *wdiags_base = NULL;
#endif

static uint32_t wdiags_ptp_state_shadow;
static uint32_t wdiags_boot_init_debug_shadow;
static uint16_t wdiags_vlan_pfilter_progress_shadow;
static uint32_t wdiags_mapping_counter_shadow;
static uint32_t wdiags_port_state_shadow;
static uint32_t wdiags_aux_state_shadow;
static uint32_t wdiags_boot_startup_p_offset_shadow[WRC_DIAGS_BOOT_STARTUP_STAGE_COUNT];
static uint32_t wdiags_boot_startup_valid_shadow;
static int wdiags_boot_startup_active;

static void wdiags_write_boot_startup(void);

static void wdiags_persistent_init_if_invalid(void)
{
	int i;

	if (debug_precrt_persistent_magic == WDIAGS_PERSISTENT_MAGIC)
		return;

	debug_precrt_persistent_magic = WDIAGS_PERSISTENT_MAGIC;
	debug_precrt_persistent_mode_master_stage = 0;
	debug_precrt_persistent_lock_wait_substage = 0;
	debug_precrt_persistent_boot_generation_at_stage = 0;
	for (i = 0; i < 4; i++)
		debug_precrt_persistent_stage_history[i] = 0;
}

static void wdiags_persistent_mode_master_stage(uint32_t stage)
{
	int i;

	if (stage == 0)
		return;

	wdiags_persistent_init_if_invalid();
	for (i = 0; i < 3; i++)
		debug_precrt_persistent_stage_history[i] =
			debug_precrt_persistent_stage_history[i + 1];
	debug_precrt_persistent_stage_history[3] = stage;
	debug_precrt_persistent_mode_master_stage = stage;
	debug_precrt_persistent_boot_generation_at_stage =
		debug_precrt_boot_generation;
}

static void wdiags_persistent_lock_wait_substage(uint32_t substage)
{
	if (substage == 0)
		return;

	wdiags_persistent_init_if_invalid();
	debug_precrt_persistent_lock_wait_substage = substage;
}


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
	wdiags_port_state_shadow = val;
	wdiags_write_boot_startup();

	//pp_printf("wdiags_write_port_state: %x\n", val );
}

void wdiags_write_ptp_state(uint8_t ptpstate)
{
	wdiags_ptp_state_shadow =
		((uint32_t)ptpstate << WRC_DIAGS_WDIAG_PTPSTAT_PTPSTATE_SHIFT) &
		WRC_DIAGS_WDIAG_PTPSTAT_PTPSTATE_MASK;
	wdiag_write(WRC_DIAGS_WDIAG_PTPSTAT,
			wdiags_ptp_state_shadow | wdiags_boot_init_debug_shadow);
}

void wdiags_write_boot_init_debug(uint32_t script_enter_count,
					  uint32_t command_index,
					  uint32_t mode_master_call_count,
					  uint32_t mode_master_return_count)
{
	/* Keep the existing PTP state in bits 0..7. The boot script has four
	 * commands, so 4 bits are sufficient for its index and entry count; the
	 * two mode-master counters retain 8 bits each. */
	wdiags_boot_init_debug_shadow =
		((script_enter_count << WRC_DIAGS_WDIAG_PTPSTAT_BOOT_INIT_ENTER_SHIFT) &
		 WRC_DIAGS_WDIAG_PTPSTAT_BOOT_INIT_ENTER_MASK) |
		((command_index << WRC_DIAGS_WDIAG_PTPSTAT_BOOT_INIT_INDEX_SHIFT) &
		 WRC_DIAGS_WDIAG_PTPSTAT_BOOT_INIT_INDEX_MASK) |
		((mode_master_call_count << WRC_DIAGS_WDIAG_PTPSTAT_MODE_MASTER_CALL_SHIFT) &
		 WRC_DIAGS_WDIAG_PTPSTAT_MODE_MASTER_CALL_MASK) |
		((mode_master_return_count << WRC_DIAGS_WDIAG_PTPSTAT_MODE_MASTER_RETURN_SHIFT) &
		 WRC_DIAGS_WDIAG_PTPSTAT_MODE_MASTER_RETURN_MASK);
	wdiag_write(WRC_DIAGS_WDIAG_PTPSTAT,
			wdiags_ptp_state_shadow | wdiags_boot_init_debug_shadow);
}

void wdiags_write_mode_master_stage(uint32_t stage)
{
	/* Direct sticky write: it must remain visible if the CPU wedges before
	 * the periodic diagnostics task can publish another shadow. */
	wdiag_write(WRC_DIAGS_WDIAG_MODE_MASTER_STAGE, stage);
	wdiags_persistent_mode_master_stage(stage);
}

void wdiags_write_lock_wait_debug(uint32_t substage,
					  uint32_t iteration_count,
					  uint32_t start_tics,
					  uint32_t current_tics,
					  int32_t last_lock_result)
{
	/* These words are direct read-only shadows. They are written at each
	 * boundary so a CPU wedge leaves the last completed boundary visible. */
	wdiag_write(WRC_DIAGS_WDIAG_LOCK_WAIT_SUBSTAGE, substage);
	wdiag_write(WRC_DIAGS_WDIAG_LOCK_WAIT_ITERATION, iteration_count);
	wdiag_write(WRC_DIAGS_WDIAG_LOCK_WAIT_START_TICS, start_tics);
	wdiag_write(WRC_DIAGS_WDIAG_LOCK_WAIT_CURRENT_TICS, current_tics);
	wdiag_write(WRC_DIAGS_WDIAG_LOCK_WAIT_LAST_LOCK_RESULT,
			(uint32_t)last_lock_result);
	wdiags_persistent_lock_wait_substage(substage);
}

static void wdiags_write_boot_startup(void)
{
	uint32_t value = wdiags_port_state_shadow;

	if (wdiags_boot_startup_active) {
		value |= (wdiags_boot_startup_p_offset_shadow[
			WRC_DIAGS_BOOT_STARTUP_STAGE_P_AT_RESET_EARLY] &
			WRC_DIAGS_BOOT_STARTUP_P_OFFSET_MASK) <<
			WRC_DIAGS_BOOT_STARTUP_P_AT_RESET_EARLY_SHIFT;
		value |= (wdiags_boot_startup_p_offset_shadow[
			WRC_DIAGS_BOOT_STARTUP_STAGE_P_AFTER_BSS_DATA_INIT] &
			WRC_DIAGS_BOOT_STARTUP_P_OFFSET_MASK) <<
			WRC_DIAGS_BOOT_STARTUP_P_AFTER_BSS_DATA_INIT_SHIFT;
		value |= (wdiags_boot_startup_p_offset_shadow[
			WRC_DIAGS_BOOT_STARTUP_STAGE_P_AFTER_BOARD_INIT] &
			WRC_DIAGS_BOOT_STARTUP_P_OFFSET_MASK) <<
			WRC_DIAGS_BOOT_STARTUP_P_AFTER_BOARD_INIT_SHIFT;
		value |= (wdiags_boot_startup_p_offset_shadow[
			WRC_DIAGS_BOOT_STARTUP_STAGE_P_AFTER_SHELL_INIT] &
			WRC_DIAGS_BOOT_STARTUP_P_OFFSET_MASK) <<
			WRC_DIAGS_BOOT_STARTUP_P_AFTER_SHELL_INIT_SHIFT;
		value |= (wdiags_boot_startup_p_offset_shadow[
			WRC_DIAGS_BOOT_STARTUP_STAGE_P_BEFORE_SHELL_BOOT_SCRIPT] &
			WRC_DIAGS_BOOT_STARTUP_P_OFFSET_MASK) <<
			WRC_DIAGS_BOOT_STARTUP_P_BEFORE_SHELL_BOOT_SCRIPT_SHIFT;
	}

	wdiag_write(WRC_DIAGS_WDIAG_PSTAT, value);

	value = wdiags_aux_state_shadow;
	if (wdiags_boot_startup_active) {
		value |= (wdiags_boot_startup_p_offset_shadow[
			WRC_DIAGS_BOOT_STARTUP_STAGE_P_AT_BOOT_SCRIPT_ENTRY] &
			WRC_DIAGS_BOOT_STARTUP_P_OFFSET_MASK) <<
			WRC_DIAGS_BOOT_STARTUP_P_AT_BOOT_SCRIPT_ENTRY_SHIFT;
		value |= (wdiags_boot_startup_valid_shadow &
			WRC_DIAGS_BOOT_STARTUP_VALID_MASK_MASK) <<
			WRC_DIAGS_BOOT_STARTUP_VALID_MASK_SHIFT;
		value |= WRC_DIAGS_BOOT_STARTUP_TRACE_VALID;
	}

	wdiag_write(WRC_DIAGS_WDIAG_ASTAT, value);
}

void wdiags_boot_startup_reset(void)
{
	uint32_t i;

	for (i = 0; i < WRC_DIAGS_BOOT_STARTUP_STAGE_COUNT; i++)
		wdiags_boot_startup_p_offset_shadow[i] =
			WRC_DIAGS_BOOT_STARTUP_P_OFFSET_INVALID;
	wdiags_boot_startup_valid_shadow = 0;
	wdiags_boot_startup_active = 1;
	wdiags_write_boot_startup();
}

void wdiags_boot_startup_checkpoint(uint32_t stage, uint32_t p_offset)
{
	if (stage >= WRC_DIAGS_BOOT_STARTUP_STAGE_COUNT)
		return;

	wdiags_boot_startup_p_offset_shadow[stage] = p_offset;
	wdiags_boot_startup_valid_shadow |= 1UL << stage;
	wdiags_write_boot_startup();
}

static void wdiags_write_vlan_pfilter_progress(void)
{
	uint32_t counter = wdiags_mapping_counter_shadow & 0xffffu;
	uint32_t progress = wdiags_vlan_pfilter_progress_shadow;

	/* Keep the existing mapping counter/inverse in the low half-words and
	 * expose the checkpoint bitmap/index in the high half-words. */
	wdiag_write(WRC_DIAGS_WDIAG_MAPPING_COUNTER,
			counter | (progress << WRC_DIAGS_WDIAG_MAPPING_PROGRESS_SHIFT));
	wdiag_write(WRC_DIAGS_WDIAG_MAPPING_INVERSE,
			((~counter) & 0xffffu) |
			(((~progress) & 0xffffu) << WRC_DIAGS_WDIAG_MAPPING_PROGRESS_SHIFT));
}

void wdiags_vlan_cmd_enter(void)
{
	wdiags_vlan_pfilter_progress_shadow = WRC_DIAGS_VLAN_CMD_ENTER;
	wdiags_write_vlan_pfilter_progress();
}

void wdiags_pfilter_enter(void)
{
	wdiags_vlan_pfilter_progress_shadow |= WRC_DIAGS_PFILTER_ENTER;
	wdiags_write_vlan_pfilter_progress();
}

void wdiags_pfilter_before_disable(void)
{
	wdiags_vlan_pfilter_progress_shadow |= WRC_DIAGS_PFILTER_BEFORE_DISABLE;
	wdiags_write_vlan_pfilter_progress();
}

void wdiags_pfilter_rule_index(uint32_t index)
{
	wdiags_vlan_pfilter_progress_shadow &=
		~WRC_DIAGS_PFILTER_RULE_INDEX_MASK;
	wdiags_vlan_pfilter_progress_shadow |=
		(index << WRC_DIAGS_PFILTER_RULE_INDEX_SHIFT) &
		WRC_DIAGS_PFILTER_RULE_INDEX_MASK;
	wdiags_write_vlan_pfilter_progress();
}

void wdiags_pfilter_after_rule_write(void)
{
	wdiags_vlan_pfilter_progress_shadow |= WRC_DIAGS_PFILTER_AFTER_RULE_WRITE;
	wdiags_write_vlan_pfilter_progress();
}

void wdiags_pfilter_before_enable(void)
{
	wdiags_vlan_pfilter_progress_shadow |= WRC_DIAGS_PFILTER_BEFORE_ENABLE;
	wdiags_write_vlan_pfilter_progress();
}

void wdiags_pfilter_return(void)
{
	wdiags_vlan_pfilter_progress_shadow |= WRC_DIAGS_PFILTER_RETURN;
	wdiags_write_vlan_pfilter_progress();
}

void wdiags_vlan_cmd_return(void)
{
	wdiags_vlan_pfilter_progress_shadow |= WRC_DIAGS_VLAN_CMD_RETURN;
	wdiags_write_vlan_pfilter_progress();
}

void wdiags_write_aux_state(uint32_t aux_states)
{
	wdiags_aux_state_shadow =
		(aux_states << WRC_DIAGS_WDIAG_ASTAT_AUX_SHIFT) &
		WRC_DIAGS_WDIAG_ASTAT_AUX_MASK;
	wdiags_write_boot_startup();
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

void wdiags_write_wr_signaling_reject_debug(uint32_t reject_count,
                                            uint8_t reject_reason)
{
	/* DE5a has one WR output, so AUX0 detail (0x50) is unused here. */
	wdiag_write(WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT,
			((reject_count & 0x00ffffffu) << 8) |
			((uint32_t)reject_reason & 0xffu));
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

void wdiags_write_wr_spll_hw_debug(uint32_t ocer, uint32_t rcer,
                                   uint32_t occr, uint32_t trr_csr,
                                   uint32_t dac_hpll, uint32_t dac_main,
                                   uint32_t helper_state, uint32_t helper_limits,
                                   uint32_t main_state, uint32_t main_limits,
                                   uint32_t main_phase_limits)
{
	/* These words are read-only shadows. They never feed back into SoftPLL. */
	wdiag_write(0xa4, ocer);
	wdiag_write(0xa8, rcer);
	wdiag_write(0xac, occr);
	wdiag_write(0xb0, trr_csr);
	wdiag_write(0xb4, dac_hpll);
	wdiag_write(0xb8, dac_main);
	wdiag_write(0xbc, helper_state);
	wdiag_write(0xc0, helper_limits);
	wdiag_write(0xc4, main_state);
	wdiag_write(0xc8, main_limits);
	wdiag_write(0xcc, main_phase_limits);
}

void wdiags_write_wr_spll_activity_debug(uint32_t ref_count, uint32_t tag_count,
                                         int32_t helper_error, int32_t helper_output,
                                         uint32_t state_visit_mask,
                                         uint32_t state_transition_count,
                                         uint32_t last_state,
                                         uint32_t irq_count,
                                         uint32_t irq_mask,
                                         uint32_t irq_status)
{
	wdiag_write(0xd0, ref_count);
	wdiag_write(0xd4, tag_count);
	wdiag_write(0xd8, (uint32_t)helper_error);
	wdiag_write(0xdc, (uint32_t)helper_output);
	wdiag_write(0xe0, state_visit_mask);
	wdiag_write(0xe4, state_transition_count);
	wdiag_write(0xe8, last_state);
	wdiag_write(0xec, irq_count);
	wdiag_write(0xf0, irq_mask);
	wdiag_write(0xf4, irq_status);
}

void wdiags_write_wr_spll_event_debug(uint32_t tag_valid_count,
                                      uint32_t trr_write_count)
{
	/* These are read-only hardware counters exposed by SoftPLL-ng. */
	wdiag_write(0xf8, tag_valid_count);
	wdiag_write(0xfc, trr_write_count);
}

void wdiags_write_wr_spll_trr_pop_count(uint32_t trr_pop_count)
{
	/* Read-only firmware shadow; it does not change TRR or SoftPLL flow. */
	wdiag_write(0x154, trr_pop_count);
}

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
                                             int32_t ref_src)
{
	/* These registers are sampled shadows only. The periodic diagnostics task
	 * writes them outside the interrupt-driven SoftPLL loop. */
	wdiag_write(0x100, (uint32_t)last_tag);
	wdiag_write(0x104, (uint32_t)expected_tag);
	wdiag_write(0x108, (uint32_t)preclamp_error);
	wdiag_write(0x10c, (uint32_t)tag_delta);
	wdiag_write(0x110, (uint32_t)tag_source);
	wdiag_write(0x114, (uint32_t)expected_delta);
	wdiag_write(0x118, update_count);
	wdiag_write(0x11c, (uint32_t)p_adder);
	wdiag_write(0x120, (uint32_t)tag_d0);
	wdiag_write(0x124, (uint32_t)p_setpoint);
	wdiag_write(0x128, (uint32_t)ref_src);
}

void wdiags_write_mapping_self_test(uint32_t counter)
{
	/* These values validate firmware write -> DPRAM -> JTAG read mapping.
	 * They never feed back into WR control or the SoftPLL. */
	wdiag_write(0x12c, 0xA5A5122Cu);
	wdiag_write(0x130, 0xA5A51330u);
	wdiags_mapping_counter_shadow = counter;
	wdiag_write(WRC_DIAGS_WDIAG_MAPPING_COUNTER,
			(counter & 0xffffu) |
			((uint32_t)wdiags_vlan_pfilter_progress_shadow <<
			 WRC_DIAGS_WDIAG_MAPPING_PROGRESS_SHIFT));
	wdiag_write(WRC_DIAGS_WDIAG_MAPPING_INVERSE,
			((~counter) & 0xffffu) |
			(((uint32_t)(~wdiags_vlan_pfilter_progress_shadow) & 0xffffu) <<
			 WRC_DIAGS_WDIAG_MAPPING_PROGRESS_SHIFT));
}

void wdiags_write_wr_spll_runtime_debug(uint32_t init_count,
						uint32_t clear_dacs_count,
						uint32_t current_tics,
						uint32_t dac_timeout,
						uint32_t last_init_tics,
						uint32_t last_clear_dacs_tics)
{
	/* Read-only runtime context shadows. They never feed back into SoftPLL. */
	wdiag_write(0x13c, current_tics);
	wdiag_write(0x140, dac_timeout);
	wdiag_write(0x144, init_count);
	wdiag_write(0x148, clear_dacs_count);
	wdiag_write(0x14c, last_init_tics);
	wdiag_write(0x150, last_clear_dacs_tics);
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

	/* Preserve a valid record across CPU-only re-entry; initialize only a
	 * record from an older image or an uninitialized NOLOAD region. */
	wdiags_persistent_init_if_invalid();

	for( i = 0; i < WRC_DIAGS_SIZE / 4; i++ )
		wdiag_write( i * 4, 0 );

	wdiag_write( WRC_DIAGS_VER, WDIAGS_VERSION );
	wdiags_write_mode_master_stage(
		WRC_DIAGS_MODE_MASTER_STAGE_NOT_ENTERED);
	wdiags_write_lock_wait_debug(
		WRC_DIAGS_LOCK_WAIT_SUBSTAGE_NOT_ENTERED, 0, 0, 0, 0);
	wdiags_write_boot_startup();

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
