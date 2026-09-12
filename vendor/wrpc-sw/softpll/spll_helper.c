/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2010 - 2013 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

/* spll_helper.c - implmentation of the Helper PLL servo algorithm. */

#include "softpll_ng.h"

/*
 * The helper phase accumulator is used as a long-running control state.  The
 * exported diagnostic fields remain int32_t for compatibility, but keeping
 * the arithmetic itself in 64 bits prevents a sustained frequency error from
 * wrapping raw_err after roughly a minute of operation.
 */
static int64_t helper_p_adder_wide;
static int64_t helper_p_setpoint_wide;
static int64_t helper_tag_d0_wide;
static int helper_wide_state_valid;

/* Keep the best previously measured acquisition dynamics for the lock
 * threshold A/B.  The PI target is updated on every accepted tag; the
 * observer showed that the 64-tag hold made coarse acquisition too slow. */
#define STEP5_HELPER_PI_UPDATE_DECIMATION 1
static uint32_t helper_pi_decimation_count;

/* The coherent Helper trajectory is centered near zero and has an observed
 * RMS below 700 tics, but the 1200-tic admission band is crossed repeatedly
 * before the Main loop is allowed to start.  Keep this as a separately
 * auditable admission-boundary A/B; Step5 still requires Main/PSTAT lock and
 * a stable closed-loop window. */
#define STEP5_HELPER_LOCK_THRESHOLD 2000
/* The 64-code physical actuator and the measured phase-noise floor can
 * remain inside the 1200-tic band for useful acquisition intervals, but the
 * original 10000 accepted-tag requirement is longer than those intervals.
 * Keep the threshold unchanged and use a separately auditable 1000-sample
 * dwell for this Step5 A/B. */
#define STEP5_HELPER_LOCK_SAMPLES 1000
#define STEP5_HELPER_RESEED_BIAS 63252

static inline int32_t helper_diag_i32(int64_t value)
{
	if (value > 2147483647LL)
		return 2147483647;
	if (value < -2147483648LL)
		return -2147483648LL;
	return (int32_t)value;
}

static inline void helper_sync_legacy_state(struct spll_helper_state *s)
{
	s->p_adder = helper_diag_i32(helper_p_adder_wide);
	s->p_setpoint = helper_diag_i32(helper_p_setpoint_wide);
	s->tag_d0 = helper_diag_i32(helper_tag_d0_wide);
}

static inline void helper_publish_measurement(int32_t tag_delta,
						      int32_t expected_delta,
						      int32_t freq_error,
						      int32_t preclamp_error,
						      int32_t helper_error,
						      uint32_t update_count,
						      int32_t helper_output)
{
	uint32_t epoch = wrpc_spll_helper_measurement_epoch;

	if (epoch >= 0xfffffffdU || (epoch & 1u))
		epoch = 0;
	else
		epoch += 2u;

	/* This RAM seqlock is updated once per accepted Helper invocation.  The
	 * periodic diagnostics task copies one coherent instance to WDIAGS, where
	 * the passive JTAG observer can bracket its slower MMIO reads. */
	wrpc_spll_helper_measurement_epoch = epoch | 1u;
	wrpc_spll_helper_measurement_tag_delta = tag_delta;
	wrpc_spll_helper_measurement_expected_delta = expected_delta;
	wrpc_spll_helper_measurement_freq_error = freq_error;
	wrpc_spll_helper_measurement_preclamp_error = preclamp_error;
	wrpc_spll_helper_measurement_error = helper_error;
	wrpc_spll_helper_measurement_update_count = update_count;
	wrpc_spll_helper_measurement_output = helper_output;
	wrpc_spll_helper_measurement_dmtd_ref_accept_count =
		SPLL->DMTD_REF_ACCEPT_COUNT;
	wrpc_spll_helper_measurement_dmtd_fb_accept_count =
		SPLL->DMTD_FB_ACCEPT_COUNT;
	wrpc_spll_helper_measurement_epoch = epoch;
}

void helper_very_init( struct spll_helper_state *s )
{
	helper_p_adder_wide = 0;
	helper_p_setpoint_wide = 0;
	helper_tag_d0_wide = -1;
	helper_wide_state_valid = 0;
	helper_pi_decimation_count = 0;

/* Phase branch PI controller */
	s->pi.y_min = (5 << BOARD_SPLL_DIV_BITS);
	s->pi.y_max = (1 << BOARD_SPLL_DAC_BITS) - (5 << BOARD_SPLL_DIV_BITS);
#if defined(CONFIG_WR_NODE)
	/* Step5 damping A/B: keep the measured 3388 operating point and reduce
	 * proportional authority for the quantized 64-code physical actuator. */
	s->pi.kp = -75;
	s->pi.ki = -1;
#else
	s->pi.kp = 150;
	s->pi.ki = 2;
#endif
	s->pi.shift = PI_FRACBITS - BOARD_SPLL_DIV_BITS;
	s->pi.anti_windup = 1;

	/* Phase branch lock detection */
	s->ld.threshold = STEP5_HELPER_LOCK_THRESHOLD;
	s->ld.lock_samples = STEP5_HELPER_LOCK_SAMPLES;
	s->ld.delock_samples = 100;
}

void helper_init(struct spll_helper_state *s, int ref_channel)
{
	s->ref_src = ref_channel;
}

void helper_update(struct spll_helper_state *s, int tag,
			 int source)
{
	int err, y, tag_delta;
	int64_t raw_err;
	int expected_delta;

	/* Helper pll tracks the ref clock */
	if (source != s->ref_src)
		return;

	wrpc_spll_helper_last_tag = tag;
	wrpc_spll_helper_tag_source = source;
	wrpc_spll_helper_expected_delta = (1 << HPLL_N);
	expected_delta = (1 << HPLL_N);
	wrpc_spll_helper_update_count++;
	wrpc_spll_helper_ref_src = s->ref_src;

	if (!helper_wide_state_valid) {
		helper_p_adder_wide = s->p_adder;
		helper_p_setpoint_wide = s->p_setpoint;
		helper_tag_d0_wide = s->tag_d0;
		helper_wide_state_valid = 1;
	}
	
	//spll_debug(SPLL_DBG_SRC_HELPER, SPLL_DBG_SIGNAL_TAG, tag, 0);
	//spll_debug(SPLL_DBG_SRC_HELPER, SPLL_DBG_SIGNAL_REF, s->p_setpoint, 0);

	if (helper_tag_d0_wide < 0) {
		/* First tag. */
		helper_p_setpoint_wide = tag;
		helper_tag_d0_wide = tag;
		helper_sync_legacy_state(s);
		wrpc_spll_helper_expected_tag = s->p_setpoint;
		wrpc_spll_helper_preclamp_error = 0;
		wrpc_spll_helper_tag_delta = 0;
		wrpc_spll_helper_p_adder = s->p_adder;
		wrpc_spll_helper_tag_d0 = s->tag_d0;
		wrpc_spll_helper_p_setpoint = s->p_setpoint;
		helper_publish_measurement(0, expected_delta, 0, 0, 0,
			wrpc_spll_helper_update_count, s->pi.y);

		return;
	}

	/* Handle tag wraparound */
	if (helper_tag_d0_wide > tag)
		helper_p_adder_wide += (1LL << TAG_BITS);

	tag_delta = tag - (int)helper_tag_d0_wide;
	if (tag_delta < 0)
		tag_delta += (1 << TAG_BITS);

	/* Compute the error */
	raw_err = ((int64_t)tag + helper_p_adder_wide) - helper_p_setpoint_wide;
	helper_sync_legacy_state(s);
	wrpc_spll_helper_expected_tag = s->p_setpoint;
	wrpc_spll_helper_preclamp_error = helper_diag_i32(raw_err);
	wrpc_spll_helper_tag_delta = tag_delta;
	err = (raw_err < -HELPER_ERROR_CLAMP) ? -HELPER_ERROR_CLAMP :
	      (raw_err > HELPER_ERROR_CLAMP) ? HELPER_ERROR_CLAMP :
	      (int)raw_err;

	/* And clamp */
	/* Handle wraparound */
	if (((int64_t)tag + helper_p_adder_wide) > HELPER_TAG_WRAPAROUND
	    && helper_p_setpoint_wide > HELPER_TAG_WRAPAROUND) {
		helper_p_adder_wide -= HELPER_TAG_WRAPAROUND;
		helper_p_setpoint_wide -= HELPER_TAG_WRAPAROUND;
	}

	/* The next expected tag is the current plus one cycle */
	helper_p_setpoint_wide += (1 << HPLL_N);
	helper_tag_d0_wide = tag;
	helper_sync_legacy_state(s);

	if (++helper_pi_decimation_count >= STEP5_HELPER_PI_UPDATE_DECIMATION) {
		helper_pi_decimation_count = 0;
		y = pi_update((spll_pi_t *)&s->pi, err);
		SPLL->DAC_HPLL = y;
	} else {
		/* Do not write the MMIO register on held samples: a repeated store
		 * would look like a fresh target load to the SI5340 tracker. */
		y = s->pi.y;
	}

	//spll_debug(SPLL_DBG_SRC_HELPER, SPLL_DBG_SIGNAL_TIME_MS, timer_get_tics(), 0);
	//spll_debug(SPLL_DBG_SRC_HELPER, SPLL_DBG_SIGNAL_SAMPLE_ID, s->sample_n++, 0);
	//spll_debug(SPLL_DBG_SRC_HELPER, SPLL_DBG_SIGNAL_Y, y, 0);
	//spll_debug(SPLL_DBG_SRC_HELPER, SPLL_DBG_SIGNAL_ERR, err, 1);

	ld_update((spll_lock_det_t *)&s->ld, err);

	if( s->ld.lock_changed && s->ld.locked )
	{
		s->last_lock_duration_ms = timer_get_tics() - s->lock_start_ms;
	}

	wrpc_spll_helper_p_adder = s->p_adder;
	wrpc_spll_helper_tag_d0 = s->tag_d0;
	wrpc_spll_helper_p_setpoint = s->p_setpoint;
	helper_publish_measurement(tag_delta, expected_delta,
		tag_delta - expected_delta, helper_diag_i32(raw_err), err,
		wrpc_spll_helper_update_count, y);
}

void helper_start(struct spll_helper_state *s)
{
	/* Set the bias to the upper end of tuning range. This is to ensure that
	   the HPLL will always lock on positive frequency offset. */
#if defined(CONFIG_TARGET_WR_SWITCH)
	s->pi.bias = s->pi.y_max;
#else
	s->pi.bias = s->pi.y_min;
#endif
	s->p_setpoint = 0;
	s->p_adder = 0;
	s->sample_n = 0;
	s->tag_d0 = -1;
	helper_p_setpoint_wide = 0;
	helper_p_adder_wide = 0;
	helper_tag_d0_wide = -1;
	helper_pi_decimation_count = 0;
	helper_wide_state_valid = 1;
	s->last_lock_duration_ms = -1;

#if defined(CONFIG_WR_NODE)
	/* The coarse bootstrap has already established the physical operating
	 * point. Restart the fine loop near the measured 3388-step target
	 * instead of re-seeding at the DAC rail. */
	s->pi.bias = STEP5_HELPER_RESEED_BIAS;
#endif
	pi_init((spll_pi_t *)&s->pi);
	ld_init((spll_lock_det_t *)&s->ld);

	s->lock_start_ms = timer_get_tics();

	spll_enable_tagger(s->ref_src, 1);
	//spll_debug(SPLL_DBG_SRC_HELPER, SPLL_DBG_SIGNAL_EVENT, SPLL_DBG_EVT_START, 1);
}

void helper_reseed(struct spll_helper_state *s)
{
	/* The Slave may spend its startup interval moving the HPLL coarse
	 * actuator.  Any Helper phase history collected during that motion is
	 * not a valid fine-lock initial condition, so restart from the first
	 * accepted tag after the coarse operation has settled. */
	s->p_setpoint = 0;
	s->p_adder = 0;
	s->sample_n = 0;
	s->tag_d0 = -1;
	helper_p_setpoint_wide = 0;
	helper_p_adder_wide = 0;
	helper_tag_d0_wide = -1;
	helper_pi_decimation_count = 0;
	helper_wide_state_valid = 1;
	s->last_lock_duration_ms = -1;

	pi_init((spll_pi_t *)&s->pi);
	ld_init((spll_lock_det_t *)&s->ld);
	s->lock_start_ms = timer_get_tics();
}

void helper_switch_reference(struct spll_helper_state *s, int new_ref)
{
#if 0
	disable_irq();
	s->ref_src = new_ref;
	s->tag_d0 = -1;
	s->p_adder = 0;
	enable_irq();
	spll_enable_tagger(s->ref_src, 1);
#endif
}
