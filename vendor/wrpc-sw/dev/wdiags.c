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
#include "dev/syscon.h"
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
extern volatile uint32_t debug_precrt_persistent_spll_check_lock_stage;
extern volatile uint32_t debug_precrt_persistent_spll_check_lock_channel;
extern volatile uint32_t debug_precrt_persistent_spll_check_lock_state_value;
extern volatile uint32_t debug_precrt_persistent_spll_check_lock_boot_generation;
extern volatile uint32_t debug_precrt_persistent_command_stage;
extern volatile uint32_t debug_precrt_persistent_command_rx_byte_count;
extern volatile uint32_t debug_precrt_persistent_command_last_byte;
extern volatile uint32_t debug_precrt_persistent_command_length;
extern volatile uint32_t debug_precrt_persistent_command_hash;
extern volatile uint32_t debug_precrt_persistent_command_boot_generation;
extern volatile uint32_t debug_precrt_persistent_command_micro_stage;
extern volatile uint32_t debug_precrt_persistent_command_micro_boot_generation;
extern volatile uint32_t debug_precrt_persistent_command_micro_length;
extern volatile uint32_t debug_precrt_persistent_command_micro_pos;
extern volatile uint32_t debug_precrt_persistent_command_micro_line_ready;
extern volatile uint32_t debug_precrt_persistent_command_micro_shell_state;
extern volatile uint32_t debug_precrt_persistent_command_micro_buffer_capture_stage;
extern volatile uint32_t debug_precrt_persistent_command_micro_buffer_word[4];
extern volatile uint32_t debug_precrt_persistent_fault_magic;
extern volatile uint32_t debug_precrt_persistent_fault_count;
extern volatile uint32_t debug_precrt_persistent_fault_mcause;
extern volatile uint32_t debug_precrt_persistent_fault_mepc;
extern volatile uint32_t debug_precrt_persistent_fault_mtval;
extern volatile uint32_t debug_precrt_persistent_fault_ra;
extern volatile uint32_t debug_precrt_persistent_fault_sp;
extern volatile uint32_t debug_precrt_persistent_fault_boot_generation;
extern volatile uint32_t debug_precrt_persistent_fault_last_mode_master_stage;
extern volatile uint32_t debug_precrt_persistent_fault_last_spll_check_lock_stage;

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
static int wdiags_reinit_attribution_active;
static uint32_t wdiags_helper_pi_snapshot_ack_seq;
static uint32_t wdiags_helper_pi_snapshot_last_request_seq;
static uint32_t wdiags_helper_pi_snapshot_req_count;
static uint32_t wdiags_helper_pi_snapshot_ack_count;
static uint32_t wdiags_helper_pi_snapshot_bank_commit_count;
static uint32_t wdiags_helper_pi_snapshot_overwrite_count;
static uint32_t wdiags_main_frequency_trace_epoch;
/* Once a snapshot request is observed, the overlapping 0x158..0x1dc
 * private window belongs exclusively to the PI frozen bank.  Legacy
 * diagnostic state is still updated in host RAM, but must not be mirrored
 * into that window until the next firmware initialization. */
static int wdiags_helper_pi_snapshot_v2_active;

static int wdiag_write( uint32_t reg, uint32_t value );
static void wdiags_write_boot_startup(void);
static void wdiags_publish_persistent_record(void);

static inline void wdiag_publish_barrier(void)
{
	/* Keep the seqlock markers ordered with the MMIO payload writes on the
	 * RISC-V CPU.  Volatile accesses constrain the compiler, while this fence
	 * also prevents posted I/O writes from becoming visible out of order to a
	 * concurrent JTAG reader. */
	__asm__ __volatile__("fence iorw, iorw" ::: "memory");
}

static void wdiags_write_shell_microtrace_mirror(void)
{
	uint32_t meta0;

	/* During the Step5 causality audit this window is owned by the
	 * source-attribution overlay. The audit is read-only and must not inject
	 * shell commands, so keep the overlay stable. */
	if (wdiags_reinit_attribution_active)
		return;

	/* The private WDIAGS SDB window ends at 0x1ff.  While the shell-ready
	 * gate is idle, 0x1e0..0x1f8 hold the gate words.  Once the newline arms
	 * the trace, the gate is no longer used for stimulus decisions, so reuse
	 * those seven words for the buffer and metadata snapshot. */
	meta0 = (debug_precrt_persistent_command_micro_length & 0xffU) |
		((debug_precrt_persistent_command_micro_pos & 0xffU) << 8) |
		((debug_precrt_persistent_command_micro_line_ready & 0x1U) << 16) |
		((debug_precrt_persistent_command_micro_shell_state & 0x7fU) << 24);

	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_MICRO_BUFFER_WORD0,
			debug_precrt_persistent_command_micro_buffer_word[0]);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_MICRO_BUFFER_WORD1,
			debug_precrt_persistent_command_micro_buffer_word[1]);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_MICRO_BUFFER_WORD2,
			debug_precrt_persistent_command_micro_buffer_word[2]);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_MICRO_BUFFER_WORD3,
			debug_precrt_persistent_command_micro_buffer_word[3]);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_MICRO_META0, meta0);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_MICRO_META1,
			debug_precrt_persistent_command_micro_boot_generation);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_MICRO_META2,
			debug_precrt_persistent_command_micro_buffer_capture_stage);
	/* Publish the stage last so a reader can use it as the commit marker for
	 * the preceding buffer and metadata writes. */
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_MICRO_STAGE,
			debug_precrt_persistent_command_micro_stage);
}

static void wdiags_persistent_init_if_invalid(void)
{
	int i;

	if (debug_precrt_persistent_magic == WDIAGS_PERSISTENT_MAGIC)
		return;

	debug_precrt_persistent_magic = WDIAGS_PERSISTENT_MAGIC;
	debug_precrt_persistent_mode_master_stage = 0;
	debug_precrt_persistent_lock_wait_substage = 0;
	debug_precrt_persistent_boot_generation_at_stage = 0;
	debug_precrt_persistent_spll_check_lock_stage = 0;
	debug_precrt_persistent_spll_check_lock_channel = 0;
	debug_precrt_persistent_spll_check_lock_state_value = 0;
	debug_precrt_persistent_spll_check_lock_boot_generation = 0;
	debug_precrt_persistent_command_stage = 0;
	debug_precrt_persistent_command_rx_byte_count = 0;
	debug_precrt_persistent_command_last_byte = 0;
	debug_precrt_persistent_command_length = 0;
	debug_precrt_persistent_command_hash = 0;
	debug_precrt_persistent_command_boot_generation = 0;
	debug_precrt_persistent_command_micro_stage = 0;
	debug_precrt_persistent_command_micro_boot_generation = 0;
	debug_precrt_persistent_command_micro_length = 0;
	debug_precrt_persistent_command_micro_pos = 0;
	debug_precrt_persistent_command_micro_line_ready = 0;
	debug_precrt_persistent_command_micro_shell_state = 0;
	debug_precrt_persistent_command_micro_buffer_capture_stage = 0;
	for (i = 0; i < 4; i++)
		debug_precrt_persistent_command_micro_buffer_word[i] = 0;
	/* Preserve a valid fault record across CPU-only re-entry. */
	if (debug_precrt_persistent_fault_magic !=
		WDIAGS_PERSISTENT_FAULT_MAGIC) {
		debug_precrt_persistent_fault_count = 0;
		debug_precrt_persistent_fault_mcause = 0;
		debug_precrt_persistent_fault_mepc = 0;
		debug_precrt_persistent_fault_mtval = 0;
		debug_precrt_persistent_fault_ra = 0;
		debug_precrt_persistent_fault_sp = 0;
		debug_precrt_persistent_fault_boot_generation = 0;
		debug_precrt_persistent_fault_last_mode_master_stage = 0;
		debug_precrt_persistent_fault_last_spll_check_lock_stage = 0;
	}
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
	wdiags_publish_persistent_record();
}

static void wdiags_persistent_lock_wait_substage(uint32_t substage)
{
	if (substage == 0)
		return;

	wdiags_persistent_init_if_invalid();
	debug_precrt_persistent_lock_wait_substage = substage;
	wdiags_publish_persistent_record();
}

static int wdiags_persistent_spll_check_lock_active(uint32_t stage)
{
	/* The first call belongs to the mode-master lock-wait path when the
	 * caller has published its entry.  Do not use boot generation as a
	 * gate: the re-entry under investigation can happen between the mode
	 * marker and spll_check_lock(), and that transition must remain visible. */
	if (stage == WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_BEFORE_CALL)
		return debug_precrt_persistent_spll_check_lock_stage ==
			WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_NOT_ENTERED &&
			debug_precrt_persistent_mode_master_stage ==
			WRC_DIAGS_MODE_MASTER_STAGE_BEFORE_LOCK_WAIT &&
			debug_precrt_persistent_lock_wait_substage ==
			WRC_DIAGS_LOCK_WAIT_SUBSTAGE_ENTERED;

	return stage >= WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_ENTERED &&
		stage <= WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_RETURNED &&
		debug_precrt_persistent_spll_check_lock_stage == stage - 1;
}


static int wdiag_write( uint32_t reg, uint32_t value )
{
	if( !wdiags_base )
		return -1;
	// fixme: there's a max of 64 diag registers.
	
	writel( value, (void*) ( wdiags_base + reg ) );
	return 0;
}

static void wdiags_publish_persistent_record(void)
{
	/* The persistent/lock-wait mirror overlaps the PI frozen bank.  Keep the
	 * legacy state live in host RAM for post-run forensics, but never publish
	 * it after the first PI snapshot request has claimed the window. */
	if (wdiags_helper_pi_snapshot_v2_active)
		return;

	/* Dedicated read-only WDIAGS mirror so passive JTAG reads do not need
	 * CPU host-RAM access or CPU hold/release. */
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_MAGIC,
			debug_precrt_persistent_magic);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_MODE_MASTER_STAGE,
			debug_precrt_persistent_mode_master_stage);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_LOCK_WAIT_SUBSTAGE,
			debug_precrt_persistent_lock_wait_substage);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_BOOT_GENERATION,
			debug_precrt_persistent_boot_generation_at_stage);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_STAGE_HISTORY0,
			debug_precrt_persistent_stage_history[0]);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_STAGE_HISTORY1,
			debug_precrt_persistent_stage_history[1]);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_STAGE_HISTORY2,
			debug_precrt_persistent_stage_history[2]);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_STAGE_HISTORY3,
			debug_precrt_persistent_stage_history[3]);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_SPLL_CHECK_LOCK_STAGE,
			debug_precrt_persistent_spll_check_lock_stage);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_SPLL_CHECK_LOCK_CHANNEL,
			debug_precrt_persistent_spll_check_lock_channel);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_SPLL_CHECK_LOCK_STATE,
			debug_precrt_persistent_spll_check_lock_state_value);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_SPLL_CHECK_LOCK_BOOT_GENERATION,
			debug_precrt_persistent_spll_check_lock_boot_generation);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_STAGE,
			debug_precrt_persistent_command_stage);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_RX_BYTE_COUNT,
			debug_precrt_persistent_command_rx_byte_count);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_LAST_BYTE,
			debug_precrt_persistent_command_last_byte);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_LENGTH,
			debug_precrt_persistent_command_length);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_HASH,
			debug_precrt_persistent_command_hash);
	wdiag_write(WRC_DIAGS_WDIAG_PERSISTENT_CMD_BOOT_GENERATION,
			debug_precrt_persistent_command_boot_generation);
	if (debug_precrt_persistent_command_micro_stage != 0)
		wdiags_write_shell_microtrace_mirror();
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

int wdiags_helper_pi_snapshot_request_pending(uint32_t *request_seq)
{
	uint32_t request = 0;

	/* The request lives in the one-word SYSCON User-Diag R/W bank.  It is
	 * intentionally separate from WDIAGS CTRL because the external/JTAG
	 * WDIAGS port is read-only except for its legacy control word. */
	if (diag_read_word(0, DIAG_RW_BANK, &request) != 0)
		return 0;
	if (request_seq)
		*request_seq = request;

	if (request == 0 || request == wdiags_helper_pi_snapshot_ack_seq)
		return 0;

	/* Count each newly observed request once, even if the 100 ms diagnostics
	 * task sees it more than once before the payload is published.  If the
	 * requester advances the sequence before the previous one was ACKed, the
	 * previous frozen-bank transaction was overwritten; retain that fact
	 * explicitly instead of silently treating the latest request as a clean
	 * one-to-one transaction. */
	if (request != wdiags_helper_pi_snapshot_last_request_seq) {
		if (wdiags_helper_pi_snapshot_last_request_seq != 0 &&
		    wdiags_helper_pi_snapshot_ack_seq !=
		    wdiags_helper_pi_snapshot_last_request_seq)
			wdiags_helper_pi_snapshot_overwrite_count++;
		wdiags_helper_pi_snapshot_last_request_seq = request;
		wdiags_helper_pi_snapshot_v2_active = 1;
		wdiags_helper_pi_snapshot_req_count++;
		wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_REQ_COUNT,
				wdiags_helper_pi_snapshot_req_count);
		wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_LAST_REQ_SEQ,
				request);
		wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_OVERWRITE_COUNT,
				wdiags_helper_pi_snapshot_overwrite_count);
	}
	return 1;
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
	/* This word is also PI_TRACE_EPOCH once the snapshot audit is active. */
	if (!wdiags_helper_pi_snapshot_v2_active)
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
	/* The direct words overlap PI_TRACE_EPOCH through PI_LD_ERROR after the
	 * snapshot request claims the bank.  Preserve the RAM-side state below,
	 * but do not tear the PI payload with a legacy mirror write. */
	if (!wdiags_helper_pi_snapshot_v2_active) {
		wdiag_write(WRC_DIAGS_WDIAG_LOCK_WAIT_SUBSTAGE, substage);
		wdiag_write(WRC_DIAGS_WDIAG_LOCK_WAIT_ITERATION, iteration_count);
		wdiag_write(WRC_DIAGS_WDIAG_LOCK_WAIT_START_TICS, start_tics);
		wdiag_write(WRC_DIAGS_WDIAG_LOCK_WAIT_CURRENT_TICS, current_tics);
		wdiag_write(WRC_DIAGS_WDIAG_LOCK_WAIT_LAST_LOCK_RESULT,
				(uint32_t)last_lock_result);
	}
	wdiags_persistent_lock_wait_substage(substage);
}

void wdiags_write_spll_check_lock_debug(uint32_t stage,
						uint32_t channel,
						uint32_t state_value)
{
	/* Only the first mode-master lock-wait invocation may claim this sticky
	 * record.  Subsequent stages must advance monotonically, so a later
	 * background spll_check_lock() call cannot overwrite the evidence. */
	if (channel != 0 || !wdiags_persistent_spll_check_lock_active(stage))
		return;

	debug_precrt_persistent_spll_check_lock_stage = stage;
	debug_precrt_persistent_spll_check_lock_channel = channel;
	if (stage != WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_RETURNED)
		debug_precrt_persistent_spll_check_lock_state_value = state_value;
	debug_precrt_persistent_spll_check_lock_boot_generation =
		debug_precrt_boot_generation;
	wdiags_publish_persistent_record();
}

void wdiags_write_shell_command_rx_byte(uint32_t byte_value)
{
	uint32_t count;
	uint32_t hash;
	uint32_t next_stage;

	wdiags_persistent_init_if_invalid();
	count = debug_precrt_persistent_command_rx_byte_count;
	if (count != 0xffffffffU)
		++count;

	/* FNV-1a gives a compact breadcrumb without retaining the command text. */
	hash = debug_precrt_persistent_command_hash;
	if (!hash)
		hash = 2166136261U;
	hash ^= byte_value & 0xffU;
	hash *= 16777619U;

	debug_precrt_persistent_command_rx_byte_count = count;
	debug_precrt_persistent_command_last_byte = byte_value & 0xffU;
	debug_precrt_persistent_command_length = count;
	debug_precrt_persistent_command_hash = hash;

	next_stage = debug_precrt_persistent_command_stage;
	if (next_stage < WRC_DIAGS_PERSISTENT_CMD_RX_FIRST_BYTE)
		next_stage = WRC_DIAGS_PERSISTENT_CMD_RX_FIRST_BYTE;
	if (count >= 12 && next_stage < WRC_DIAGS_PERSISTENT_CMD_RX_ALL_BYTES)
		next_stage = WRC_DIAGS_PERSISTENT_CMD_RX_ALL_BYTES;
	if ((byte_value & 0xffU) == '\n' &&
		next_stage < WRC_DIAGS_PERSISTENT_CMD_RX_NEWLINE)
		next_stage = WRC_DIAGS_PERSISTENT_CMD_RX_NEWLINE;
	if (next_stage != debug_precrt_persistent_command_stage) {
		debug_precrt_persistent_command_stage = next_stage;
		debug_precrt_persistent_command_boot_generation =
			debug_precrt_boot_generation;
	}
	wdiags_publish_persistent_record();
}

void wdiags_write_shell_command_stage(uint32_t stage)
{
	uint32_t current;

	if (stage < WRC_DIAGS_PERSISTENT_CMD_SHELL_LINE_READY || stage >
		WRC_DIAGS_PERSISTENT_CMD_SET_MODE_ENTERED)
		return;

	wdiags_persistent_init_if_invalid();
	current = debug_precrt_persistent_command_stage;
	if (current != stage - 1)
		return;

	debug_precrt_persistent_command_stage = stage;
	debug_precrt_persistent_command_boot_generation =
		debug_precrt_boot_generation;
	wdiags_publish_persistent_record();
}

void wdiags_write_shell_command_micro_stage(uint32_t stage,
										uint32_t command_length,
										uint32_t command_pos,
										uint32_t line_ready,
										uint32_t shell_state,
										const char *command_buffer)
{
	uint32_t current;
	int i;

	if (stage < WRC_DIAGS_PERSISTENT_CMD_MICRO_NEWLINE_DETECTED ||
		stage > WRC_DIAGS_PERSISTENT_CMD_MICRO_MASTER_ARGUMENT_MATCHED)
		return;

	wdiags_persistent_init_if_invalid();
	current = debug_precrt_persistent_command_micro_stage;
	if (stage <= current || (current != 0 && stage != current + 1))
		return;

	debug_precrt_persistent_command_micro_stage = stage;
	debug_precrt_persistent_command_micro_boot_generation =
		debug_precrt_boot_generation;
	debug_precrt_persistent_command_micro_length = command_length;
	debug_precrt_persistent_command_micro_pos = command_pos;
	debug_precrt_persistent_command_micro_line_ready = line_ready;
	debug_precrt_persistent_command_micro_shell_state = shell_state;

	/* Capture the pre-tokenization line.  _shell_exec() replaces spaces with
	 * NUL bytes, so later stages intentionally retain the stage-4 snapshot. */
	if (stage <= WRC_DIAGS_PERSISTENT_CMD_MICRO_BUFFER_TERMINATED &&
		command_buffer != NULL) {
		for (i = 0; i < 4; i++)
			debug_precrt_persistent_command_micro_buffer_word[i] = 0;
		for (i = 0; i < 16; i++)
			debug_precrt_persistent_command_micro_buffer_word[i / 4] |=
				((uint32_t)(unsigned char)command_buffer[i]) <<
				((i % 4) * 8);
		debug_precrt_persistent_command_micro_buffer_capture_stage = stage;
	}

	wdiags_publish_persistent_record();
}

void wdiags_write_firmware_shell_ready_debug(uint32_t main_loop_reached,
							 uint32_t shell_poll_reached,
							 uint32_t boot_init_done,
							 uint32_t main_loop_generation,
							 uint32_t shell_poll_generation,
							 uint32_t boot_init_generation,
							 uint32_t current_generation)
{
	uint32_t ready = main_loop_reached && shell_poll_reached &&
		boot_init_done && main_loop_generation == current_generation &&
		shell_poll_generation == current_generation &&
		boot_init_generation == current_generation;

	/* The shell microtrace reuses these seven private words after the
	 * newline arms the trace.  Do not let a later shell-ready refresh
	 * overwrite the committed microtrace snapshot. */
	if (debug_precrt_persistent_command_micro_stage != 0 ||
	    wdiags_reinit_attribution_active)
		return;

	/* Dedicated read-only WDIAGS words. They are snapshots of firmware
	 * breadcrumbs and never participate in WR/CPU control decisions. */
	wdiag_write(WRC_DIAGS_WDIAG_FIRMWARE_MAIN_LOOP_REACHED,
			main_loop_reached);
	wdiag_write(WRC_DIAGS_WDIAG_SHELL_POLL_LOOP_REACHED,
			shell_poll_reached);
	wdiag_write(WRC_DIAGS_WDIAG_BOOT_INIT_SEQUENCE_DONE,
			boot_init_done);
	wdiag_write(WRC_DIAGS_WDIAG_FIRMWARE_SHELL_READY, ready);
	wdiag_write(WRC_DIAGS_WDIAG_FIRMWARE_MAIN_LOOP_GENERATION,
			main_loop_generation);
	wdiag_write(WRC_DIAGS_WDIAG_SHELL_POLL_GENERATION,
			shell_poll_generation);
	wdiag_write(WRC_DIAGS_WDIAG_BOOT_INIT_GENERATION,
			boot_init_generation);
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
	/* The former correlation slots 0x100..0x128 are reserved exclusively for
	 * the coherent Helper PI snapshot.  Keeping this legacy entry point as a
	 * no-op prevents an older shadow writer from tearing that snapshot between
	 * the epoch marker and its payload.  The PI publisher preserves the
	 * source-backed update counter at 0x118. */
	(void)last_tag;
	(void)expected_tag;
	(void)preclamp_error;
	(void)tag_delta;
	(void)tag_source;
	(void)expected_delta;
	(void)update_count;
	(void)p_adder;
	(void)tag_d0;
	(void)p_setpoint;
	(void)ref_src;
}

void wdiags_write_mapping_self_test(uint32_t counter)
{
	/* These values validate firmware write -> DPRAM -> JTAG read mapping.
	 * They never feed back into WR control or the SoftPLL. */
	/* 0x12c and 0x130 are part of the coherent Helper PI snapshot. */
	/* V2 owns the 0x134/0x138 overlay after the first request.  Keep the
	 * generation counters stable while the observer reads them. */
	if (wdiags_helper_pi_snapshot_v2_active)
		return;
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
	/* V2 owns 0x13c/0x140 as LAST_REQ_SEQ/BANK_SEQ.  The initialization and
	 * clear-DAC counters below remain available to the Step5 live guard. */
	if (!wdiags_helper_pi_snapshot_v2_active) {
		wdiag_write(0x13c, current_tics);
		wdiag_write(0x140, dac_timeout);
	}
	wdiag_write(0x144, init_count);
	wdiag_write(0x148, clear_dacs_count);
	wdiag_write(0x14c, last_init_tics);
	wdiag_write(0x150, last_clear_dacs_tics);
}

void wdiags_write_wr_spll_reinit_debug(uint32_t last_reason,
						uint32_t last_mode,
						uint32_t last_flags,
						uint32_t last_reason_tics,
						const uint32_t *reason_counts,
						uint32_t reason_count)
{
	uint32_t i;
	uint32_t j;
	uint32_t packed;

	/* Claim the 0x1e0..0x1fc overlay for this read-only audit. */
	wdiags_reinit_attribution_active = 1;

	/* These words are passive source-attribution shadows. */
	wdiag_write(WRC_DIAGS_WDIAG_SPLL_LAST_INIT_REASON, last_reason);
	wdiag_write(WRC_DIAGS_WDIAG_SPLL_LAST_INIT_MODE, last_mode);
	wdiag_write(WRC_DIAGS_WDIAG_SPLL_LAST_INIT_FLAGS, last_flags);
	wdiag_write(WRC_DIAGS_WDIAG_SPLL_LAST_INIT_REASON_TICS,
			last_reason_tics);
	if (reason_count > WRC_DIAGS_WDIAG_SPLL_INIT_REASON_COUNT)
		reason_count = WRC_DIAGS_WDIAG_SPLL_INIT_REASON_COUNT;
	for (i = 0; i < reason_count; i += 4) {
		packed = 0;
		for (j = 0; j < 4 && i + j < reason_count; j++)
			packed |= (reason_counts[i + j] > 0xff ? 0xff :
				   reason_counts[i + j]) << (j * 8);
		wdiag_write(WRC_DIAGS_WDIAG_SPLL_INIT_REASON_COUNTS + (i / 4) * 4,
				packed);
	}
}

void wdiags_write_wr_spll_helper_measurement_debug(uint32_t measurement_epoch,
                                                   int32_t tag_delta,
                                                   int32_t expected_delta,
                                                   int32_t freq_error,
                                                   int32_t preclamp_error,
                                                   int32_t helper_error,
                                                   uint32_t helper_update_count,
                                                   int32_t helper_output,
                                                   uint32_t dmtd_ref_accept_count,
                                                   uint32_t dmtd_fb_accept_count)
{
	/* Publish an odd epoch before changing any payload word.  A passive
	 * reader brackets its reads with this commit word and accepts the data
	 * only when the epoch is unchanged and even. */
	if (measurement_epoch == 0xffffffffu || (measurement_epoch & 1u)) {
		wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_EPOCH, 0xffffffffu);
		return;
	}
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_EPOCH,
			measurement_epoch | 1u);
	wdiag_publish_barrier();
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_TAG_DELTA,
			(uint32_t)tag_delta);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_EXPECTED_DELTA,
			(uint32_t)expected_delta);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_FREQ_ERROR,
			(uint32_t)freq_error);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_PRECLAMP_ERROR,
			(uint32_t)preclamp_error);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_HELPER_ERROR,
			(uint32_t)helper_error);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_UPDATE_COUNT,
			helper_update_count);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_HELPER_OUTPUT,
			(uint32_t)helper_output);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_DMTD_REF_ACCEPT_COUNT,
			dmtd_ref_accept_count);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_DMTD_FB_ACCEPT_COUNT,
			dmtd_fb_accept_count);
	wdiag_publish_barrier();
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_MEASUREMENT_EPOCH, measurement_epoch);
}

static void wdiags_write_i64_pair(uint32_t lo_reg, uint32_t hi_reg,
					 int64_t value)
{
	uint64_t bits = (uint64_t)value;

	wdiag_write(lo_reg, (uint32_t)bits);
	wdiag_write(hi_reg, (uint32_t)(bits >> 32));
}

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
																		uint32_t snapshot_generation)
{
	uint32_t publication_epoch = trace_epoch;

	/* The PI trace owns the 0x158..0x1dc private overlay for this audit.
	 * Keep the re-init attribution at 0x1e0..0x1fc independent. */
	if (trace_epoch == 0xffffffffu || (trace_epoch & 1u)) {
		wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_TRACE_EPOCH, 0xffffffffu);
		return;
	}
	/* V3 carries the request generation in the frozen PI bank itself.  The
	 * odd/even publication protocol remains the transport seqlock; the source
	 * measurement epoch is not used as the frame identity. */
	if (snapshot_generation != 0)
		publication_epoch = snapshot_generation << 1;
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_TRACE_EPOCH,
			publication_epoch | 1u);
	wdiag_publish_barrier();
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_TAG_RAW, (uint32_t)tag_raw);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_P_ADDER, (uint32_t)p_adder);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_P_SETPOINT, (uint32_t)p_setpoint);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_RAW_ERROR, (uint32_t)raw_error);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_LD_ERROR, (uint32_t)ld_error);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_LOCK_STATE, lock_state);
	wdiags_write_i64_pair(WRC_DIAGS_WDIAG_HELPER_PI_INTEGRATOR_BEFORE_LO,
					 WRC_DIAGS_WDIAG_HELPER_PI_INTEGRATOR_BEFORE_HI,
					 integrator_before);
	wdiags_write_i64_pair(WRC_DIAGS_WDIAG_HELPER_PI_I_NEW_LO,
					 WRC_DIAGS_WDIAG_HELPER_PI_I_NEW_HI, i_new);
	wdiags_write_i64_pair(WRC_DIAGS_WDIAG_HELPER_PI_INTEGRATOR_AFTER_LO,
					 WRC_DIAGS_WDIAG_HELPER_PI_INTEGRATOR_AFTER_HI,
					 integrator_after);
	wdiags_write_i64_pair(WRC_DIAGS_WDIAG_HELPER_PI_PROP_TERM_LO,
					 WRC_DIAGS_WDIAG_HELPER_PI_PROP_TERM_HI, prop_term);
	wdiags_write_i64_pair(WRC_DIAGS_WDIAG_HELPER_PI_Y_PREROUND_LO,
					 WRC_DIAGS_WDIAG_HELPER_PI_Y_PREROUND_HI, y_preround);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_UNCLAMPED_OUTPUT,
				(uint32_t)unclamped_output);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_Y_MIN, (uint32_t)y_min);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_Y_MAX, (uint32_t)y_max);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_CLAMP_SIDE, (uint32_t)clamp_side);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_FINAL_OUTPUT,
				(uint32_t)final_output);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_X, (uint32_t)x);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_KP, (uint32_t)kp);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_KI, (uint32_t)ki);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SHIFT, (uint32_t)shift);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_BIAS, (uint32_t)bias);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_ANTI_WINDUP,
				(uint32_t)anti_windup);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_UPDATE_COUNT, update_count);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_FREQ_ERROR,
				(uint32_t)freq_error);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_LOCK_THRESHOLD,
				(uint32_t)lock_threshold);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_LOCK_SAMPLES,
				(uint32_t)lock_samples);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_REF_SRC, (uint32_t)ref_src);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_TRACE_MAGIC,
				WRC_DIAGS_WDIAG_HELPER_PI_TRACE_VERSION);
	wdiag_publish_barrier();
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_TRACE_EPOCH, publication_epoch);
}

void wdiags_write_wr_spll_helper_pi_snapshot_ack(uint32_t request_seq)
{
	if (request_seq == 0 || request_seq == wdiags_helper_pi_snapshot_ack_seq ||
	    request_seq != wdiags_helper_pi_snapshot_last_request_seq)
		return;

	/* The PI payload is already complete and its even epoch has been
	 * published before the bank sequence is committed.  ACK_SEQ is written
	 * last, so the WB observer can prove that one request, one frozen bank,
	 * and one acknowledgement all carry the same generation. */
	wdiags_helper_pi_snapshot_bank_commit_count++;
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_BANK_COMMIT_COUNT,
			wdiags_helper_pi_snapshot_bank_commit_count);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_BANK_SEQ, request_seq);
	wdiag_publish_barrier();
	wdiags_helper_pi_snapshot_ack_count++;
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_ACK_COUNT,
			wdiags_helper_pi_snapshot_ack_count);
	wdiag_publish_barrier();
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_LAST_ACK_SEQ,
			request_seq);
	wdiags_helper_pi_snapshot_ack_seq = request_seq;
}

void wdiags_write_wr_spll_main_frequency_debug(int32_t dref_dt,
                                               int32_t dout_dt,
                                               int32_t freq_error,
                                               int32_t prelock_error,
                                               int32_t pi_unclamped,
                                               int32_t pi_output,
                                               int32_t clamp_side,
                                               uint32_t freq_lock_count,
                                               uint32_t freq_lock_count_max,
                                               int32_t pi_kp,
                                               int32_t pi_ki,
                                               int32_t pi_shift,
                                               int32_t pi_bias,
                                               uint32_t update_count,
                                               uint32_t freq_threshold,
                                               uint32_t freq_lock_samples,
                                               uint32_t state,
                                               int32_t pi_y_min,
                                               int32_t pi_y_max,
                                               int32_t pi_anti_windup,
                                               int32_t pi_x)
{
	uint32_t epoch;

	/* The Helper PI request claims the same private window.  Do not tear a
	 * frozen Helper frame if a different observer has armed that protocol. */
	if (wdiags_helper_pi_snapshot_v2_active)
		return;

	epoch = ++wdiags_main_frequency_trace_epoch;
	if (!(epoch & 1u))
		epoch = ++wdiags_main_frequency_trace_epoch;
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_EPOCH, epoch);
	wdiag_publish_barrier();
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_DREF_DT,
			(uint32_t)dref_dt);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_DOUT_DT,
			(uint32_t)dout_dt);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_ERROR,
			(uint32_t)freq_error);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_PRELOCK_ERROR,
			(uint32_t)prelock_error);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_PI_UNCLAMPED,
			(uint32_t)pi_unclamped);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_PI_OUTPUT,
			(uint32_t)pi_output);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_CLAMP_SIDE,
			(uint32_t)clamp_side);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_LOCK_COUNT,
			freq_lock_count);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_LOCK_COUNT_MAX,
			freq_lock_count_max);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_PI_KP, (uint32_t)pi_kp);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_PI_KI, (uint32_t)pi_ki);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_PI_SHIFT,
			(uint32_t)pi_shift);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_PI_BIAS,
			(uint32_t)pi_bias);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_UPDATE_COUNT,
			update_count);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_THRESHOLD,
			freq_threshold);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_LOCK_SAMPLES,
			freq_lock_samples);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_STATE, state);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_PI_Y_MIN,
			(uint32_t)pi_y_min);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_PI_Y_MAX,
			(uint32_t)pi_y_max);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_PI_ANTI_WINDUP,
			(uint32_t)pi_anti_windup);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_PI_X, (uint32_t)pi_x);
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_MAGIC,
			WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_VERSION);
	wdiag_publish_barrier();
	wdiag_write(WRC_DIAGS_WDIAG_MAIN_FREQ_TRACE_EPOCH,
			++wdiags_main_frequency_trace_epoch);
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

	wdiags_helper_pi_snapshot_ack_seq = 0;
	wdiags_helper_pi_snapshot_last_request_seq = 0;
	wdiags_helper_pi_snapshot_req_count = 0;
	wdiags_helper_pi_snapshot_ack_count = 0;
	wdiags_helper_pi_snapshot_bank_commit_count = 0;
	wdiags_helper_pi_snapshot_overwrite_count = 0;
	wdiags_main_frequency_trace_epoch = 0;
	wdiags_helper_pi_snapshot_v2_active = 0;
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_ACK_SEQ, 0);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_REQ_COUNT, 0);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_ACK_COUNT, 0);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_BANK_COMMIT_COUNT, 0);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_OVERWRITE_COUNT, 0);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_LAST_REQ_SEQ, 0);
	wdiag_write(WRC_DIAGS_WDIAG_HELPER_PI_SNAPSHOT_BANK_SEQ, 0);

	wdiag_write( WRC_DIAGS_VER, WDIAGS_VERSION );
	wdiags_write_mode_master_stage(
		WRC_DIAGS_MODE_MASTER_STAGE_NOT_ENTERED);
	wdiags_write_lock_wait_debug(
		WRC_DIAGS_LOCK_WAIT_SUBSTAGE_NOT_ENTERED, 0, 0, 0, 0);
	wdiags_publish_persistent_record();
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
