/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2010 - 2013 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

/* softpll_ng.h: public SoftPLL API header */

#ifndef __SOFTPLL_NG_H
#define __SOFTPLL_NG_H

#include <stdint.h>
#include "util.h"
#include "softpll_export.h"
#include "spll_defs.h"
#include "spll_common.h"
#include "spll_debug.h"
#include "spll_helper.h"
#include "spll_main.h"
#include "spll_ptracker.h"
#include "spll_external.h"

/* Shortcut for 'channels' parameter in various API functions to perform operation on all channels */
#define SPLL_ALL_CHANNELS 0xffffffff

#define SPLL_AUX_MODE_SLAVE 0 /* Aux clock is disciplined from the local WR time base */
#define SPLL_AUX_MODE_PHASE_MONITOR 1 /* Aux clock phase is monitored by this softPLL using another reference clock */

/* Aux clock flags */
#define SPLL_AUX_SLAVE_ENABLED (1<<0) /* Locking the particular aux channel to the WR reference is enabled */
#define SPLL_AUX_SLAVE_LOCKED (1<<1)  /* The particular aux clock is already locked to WR reference */
#define SPLL_AUX_MONITOR_ENABLED (1<<2) /* The particilar aux clock phase is monitored against the local WR reference */
#define SPLL_AUX_MONITOR_READY (1<<3)


/* Channels for spll_measure_frequency() */
#define SPLL_OSC_REF 0
#define SPLL_OSC_DMTD 1
#define SPLL_OSC_EXT 2

/* flags passed to spll_init() */
#define SPLL_FLAG_ALIGN_PPS (1<<0) /* enables rephasing of the local oscillator to the external PPS signal */
#define SPLL_FLAG_USE_LJD (1<<1)   /* enables the Low Jitter Daughterboard mezzanine (WRS V3 - specific) */

/* Read-only attribution for every source call site that can invoke
 * spll_init(). These counters are never consulted by the SoftPLL. */
enum wrpc_spll_init_reason {
	WRPC_SPLL_INIT_REASON_UNKNOWN = 0,
	WRPC_SPLL_INIT_REASON_WRPC_LOCKING_ENABLE,
	WRPC_SPLL_INIT_REASON_WRPC_LOCKING_RESET,
	WRPC_SPLL_INIT_REASON_PTP_SET_MODE_GM,
	WRPC_SPLL_INIT_REASON_PTP_SET_MODE_MASTER,
	WRPC_SPLL_INIT_REASON_PTP_LINK_DOWN,
	WRPC_SPLL_INIT_REASON_SHELL_CMD_PLL,
	WRPC_SPLL_INIT_REASON_FREQMON,
	WRPC_SPLL_INIT_REASON_RTS_SET_MODE,
	WRPC_SPLL_INIT_REASON_RTS_LOCK_CHANNEL,
	WRPC_SPLL_INIT_REASON_RXTS_CALIBRATION,
	WRPC_SPLL_INIT_REASON_ERTM14_PHY_CALIBRATION,
	WRPC_SPLL_INIT_REASON_ERTM14_BOARD_INIT,
	WRPC_SPLL_INIT_REASON_RT_IPC_MODE,
	WRPC_SPLL_INIT_REASON_RT_IPC_DISABLE,
	WRPC_SPLL_INIT_REASON_RT_IPC_SLAVE,
	WRPC_SPLL_INIT_REASON_COUNT
};


/* Note on channel naming:
 - ref_channel means a PHY recovered clock input. There can be one (as in
   WR core) or more (WR switch).
 - out_channel means an output channel, which represents PLL feedback signal
   from a local, tunable oscillator. Every SPLL implementation has at least
   one output channel, connected to the 125 / 62.5 MHz transceiver (WR)
   reference. This channel has always index 0 and is compared against all
   reference channels by the phase tracking mechanism.
*/

struct spll_aux_clock_status
{
	uint32_t flags;
	int mode;
	int phase;
};

/* PUBLIC API */

/* 
Initializes the SoftPLL to work in mode (mode). Extra parameters depend on choice of the mode:
- for SPLL_MODE_GRAND_MASTER: flags == SPLL_FLAG_ALIGN_PPS value enables realignment of the WR reference rising edge to the 
  rising edge of 10 MHz external clock that comes immediately after a PPS pulse
- for SPLL_MODE_SLAVE: (ref_channel) indicates the reference channel to which we are locking our PLL. 
*/
void spll_init(int mode, int ref_channel, int flags);
void spll_very_init(void);
void wrpc_spll_note_init_reason(uint32_t reason, uint32_t mode,
				uint32_t flags);

/* Disables the SoftPLL and cleans up stuff */
void spll_shutdown(void);

/* Returns number of reference and output channels implemented in HW. */
void spll_get_num_channels(int *n_ref, int *n_out);

/* Starts locking output channel (out_channel) */
int spll_start_channel(int out_channel);

/* Stops locking output channel (out_channel) */
void spll_stop_channel(int out_channel);

/* Returns non-zero if output channel (out_channel) is locked to a WR reference */
int spll_check_lock(int out_channel);

/* Sets phase setpoint for given output channel. */
void spll_set_phase_shift(int out_channel, int32_t value_picoseconds);

/* Retreives the current phase shift and desired setpoint for given output channel */
void spll_get_phase_shift(int out_channel, int32_t *current, int32_t *target);

/* Returns non-zero if the given output channel is busy phase shifting to a new preset */
int spll_shifter_busy(int out_channel);

/* Enables/disables phase tracking on channel (ref_channel). Phase is always measured between
   the WR local reference (out_channel 0) and ref_channel */
void spll_enable_ptracker(int ref_channel, int enable);

/* Reads tracked phase shift value for given reference channel */
int spll_read_ptracker(int ref_channel, int32_t *phase_ps, int *enabled);

/* Calls non-realtime update state machine. Must be called regularly (although
 * it is not time-critical) in the main loop of the program if aux clocks or
 * external reference are used in the design. */
int spll_update(void);

/* Returns the status of given aux clock output (SPLL_AUX_) */
struct spll_aux_clock_status spll_get_aux_status(int channel );

/* Debug/testing functions */

/* Returns how many time the PLL has de-locked since last call of spll_init() */
int spll_get_delock_count(void);

void spll_show_stats(void);
void ptracker_show_stats(void);

/* Sets VCXO tuning DAC corresponding to output (out_channel) to a given value */
void spll_set_dac(int out_channel, int value);

/* Returns current DAC sample value for output (out_channel) */
int spll_get_dac(int out_channel);

void spll_set_gain_schedule( spll_gain_schedule_t* sch );
void spll_set_pi_gain( int loop, int sched_stage, int kp, int ki, int shift );

void spll_set_ptracker_average_samples(int channel, int nsamples);

int spll_get_debug_queue_samples( uint32_t *buf, int *count );
void spll_debug_queue_configure( int undersample, int coalsesce_threshold );

void spll_set_aux_mode( int channel, int mode );
void spll_set_aux_frequency_ratio( int channel, int div_ref, int div_fb );

int spll_is_ext_supported(void);

/*
 * Aux and main state:
 * used to be in .c file, but we need it here for memory dumping
 */

/* NOTE: Please increment WRPC_SHMEM_VERSION if you change this structure */
struct spll_aux_state {
	int mode; /* SPLL_AUX_MODE* */
	int seq_state;
#ifdef CONFIG_FRAC_SPLL
	/* Fractional pll ratio (0 if 1:1).  */
	int div_ref;
	int div_fb;
#endif
	int32_t phase_value;
	union {
		struct spll_main_state dmtd;
		struct spll_ptracker_state tracker;
		/* spll_external_state ch_bb */
	} pll;
};

/* NOTE: Please increment WRPC_SHMEM_VERSION if you change this structure */
struct softpll_state {
	int mode;
	int seq_state;
	uint32_t dac_timeout;
	int delock_count;
	unsigned irq_count;
	unsigned ref_count, tag_count;
	int32_t mpll_shift_ps;

	struct spll_helper_state helper;
	struct spll_external_state ext;
	struct spll_main_state mpll;
	struct spll_aux_state aux[MAX_CHAN_AUX];
	struct spll_ptracker_state ptrackers[MAX_PTRACKERS];
};

/* NOTE: Please increment WRPC_SHMEM_VERSION if you change this structure */
struct spll_fifo_log {
	uint32_t trr;
	uint32_t tstamp;
	uint32_t duration;
	uint16_t irq_count;
	uint16_t tag_count;
};
#define FIFO_LOG_LEN 16

extern unsigned char spll_ljd_present;

extern volatile struct softpll_state softpll;

/* Read-only bring-up counters; they do not affect SoftPLL control. */
extern volatile uint32_t wrpc_spll_state_visit_mask;
extern volatile uint32_t wrpc_spll_state_transition_count;
extern volatile uint8_t wrpc_spll_last_state;

/* Read-only helper correlation shadow. These values are sampled by the
 * periodic diagnostics task and do not participate in the control loop. */
extern volatile int32_t wrpc_spll_helper_last_tag;
extern volatile int32_t wrpc_spll_helper_expected_tag;
extern volatile int32_t wrpc_spll_helper_preclamp_error;
extern volatile int32_t wrpc_spll_helper_tag_delta;
extern volatile int32_t wrpc_spll_helper_tag_source;
extern volatile int32_t wrpc_spll_helper_expected_delta;
extern volatile uint32_t wrpc_spll_helper_update_count;
/* Read-only count of tags removed from the TRR FIFO. */
extern volatile uint32_t wrpc_spll_trr_pop_count;
extern volatile int32_t wrpc_spll_helper_p_adder;
extern volatile int32_t wrpc_spll_helper_tag_d0;
extern volatile int32_t wrpc_spll_helper_p_setpoint;
extern volatile int32_t wrpc_spll_helper_ref_src;
/* Monotonic even sequence for the coherent Helper-update measurement
 * snapshot captured in helper_update() and mirrored by task-diags. */
extern volatile uint32_t wrpc_spll_helper_measurement_epoch;
extern volatile int32_t wrpc_spll_helper_measurement_tag_delta;
extern volatile int32_t wrpc_spll_helper_measurement_expected_delta;
extern volatile int32_t wrpc_spll_helper_measurement_freq_error;
extern volatile int32_t wrpc_spll_helper_measurement_preclamp_error;
extern volatile int32_t wrpc_spll_helper_measurement_error;
extern volatile uint32_t wrpc_spll_helper_measurement_update_count;
extern volatile int32_t wrpc_spll_helper_measurement_output;
extern volatile uint32_t wrpc_spll_helper_measurement_dmtd_ref_accept_count;
extern volatile uint32_t wrpc_spll_helper_measurement_dmtd_fb_accept_count;

/* Read-only runtime context counters; these never alter SoftPLL control. */
extern volatile uint32_t wrpc_spll_init_count;
extern volatile uint32_t wrpc_spll_clear_dacs_entry_count;
extern volatile uint32_t wrpc_spll_last_init_tics;
extern volatile uint32_t wrpc_spll_last_clear_dacs_tics;
extern volatile uint32_t wrpc_spll_init_reason_counts[
		WRPC_SPLL_INIT_REASON_COUNT];
extern volatile uint32_t wrpc_spll_last_init_reason;
extern volatile uint32_t wrpc_spll_last_init_reason_mode;
extern volatile uint32_t wrpc_spll_last_init_reason_flags;
extern volatile uint32_t wrpc_spll_last_init_reason_tics;

#endif // __SOFTPLL_NG_H
