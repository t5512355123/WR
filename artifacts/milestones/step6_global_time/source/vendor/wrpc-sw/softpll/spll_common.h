/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2010 - 2013 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

/* spll_common.h - common data structures and functions used by the SoftPLL */

#ifndef __SPLL_COMMON_H
#define __SPLL_COMMON_H

#include <dev/syscon.h>

#include <hw/softpll_regs.h>
#include <hw/pps_gen_regs.h>

#define SPLL_LOCKED 	1
#define SPLL_LOCKING 	0

/* Number of reference/output channels. We don't plan to have more than one
   SoftPLL instantiation per project, so these can remain global. */
extern unsigned char spll_n_chan_ref, spll_n_chan_out;

/* Channels id:
   -1                                    : helper clock (for dmtd)
   0 - (n_chan_ref-1)                    : reference clocks (from RX)
   n_chan_ref .. n_chan_ref+n_chan_out-1 : main clock + auxilliary clocks
*/
/* So the main clock id is spll_n_chan_ref. */
#define MAIN_CHANNEL (spll_n_chan_ref)

#define SPLL ((volatile struct SPLL_WB*) (BASE_SOFTPLL))
#define PPSG ((volatile struct PPSG_WB*) (BASE_PPS_GEN))

/* PI regulator state */
typedef struct {
	int ki, kp;		/* integral and proportional gains (1<<PI_FRACBITS == 1.0f) */
	int shift;		/* fractional bits shift factor (defaults to PI_FRACBITS) */
	int64_t integrator;		/* current integrator value */
	int bias;		/* DC offset always added to the output */
	int anti_windup;	/* when non-zero, anti-windup is enabled */
	int y_min;		/* min/max output range, used by clapming and antiwindup algorithms */
	int y_max;
	int x, y;		/* Current input (x) and output value (y) */
	int dithered;		/* Enable dithering of DAC output */

	/* Read-only PI trace.  These fields are updated around pi_update() and
	 * are mirrored by the diagnostics task; they never participate in the
	 * controller calculation.  trace_epoch is odd while the trace is being
	 * published and even when the snapshot is coherent. */
	volatile uint32_t trace_epoch;
	volatile int64_t trace_integrator_before;
	volatile int64_t trace_i_new;
	volatile int64_t trace_integrator_after;
	volatile int trace_x;
	volatile int trace_y_unclamped;
	volatile int trace_y_clamped;
	volatile int trace_clamp_side;
} spll_pi_t;

/* lock detector state */
typedef struct {
	int lock_cnt;		/* Lock sample counter */
	int lock_samples;	/* Number of samples below the (threshold) to assume that we are locked */
	int delock_samples;	/* Accumulated number of samples that causes the PLL go get out of lock.
				   delock_samples < lock_samples.  */
	int threshold;		/* Error threshold */
	int locked;		/* Non-zero: we are locked */
	int lock_changed;
} spll_lock_det_t;

typedef struct {
	int kp, ki, shift, lock_samples;
} spll_gain_schedule_item_t;

typedef struct {
	int n_stages;
	int current_stage;
	spll_gain_schedule_item_t stages[SPLL_GAIN_SCHED_MAX];
	int locked_d;
} spll_gain_schedule_t;

/* initializes the PI controller state. Currently almost a stub. */
void pi_init(spll_pi_t *pi);

/* Processes a single sample (x) with PI control algorithm
 (pi). Returns the value (y) to drive the actuator. */
int pi_update(spll_pi_t *pi, int x);

void ld_init(spll_lock_det_t *ld);
int ld_update(spll_lock_det_t *ld, int y);

void spll_enable_tagger(int channel, int enable);

#endif // __SPLL_COMMON_H
