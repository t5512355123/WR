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
/* Phase branch PI controller */
	s->pi.y_min = (5 << BOARD_SPLL_DIV_BITS);
	s->pi.y_max = (1 << BOARD_SPLL_DAC_BITS) - (5 << BOARD_SPLL_DIV_BITS);
#if defined(CONFIG_WR_NODE)
	s->pi.kp = -225;
	s->pi.ki = -1;
#else
	s->pi.kp = 150;
	s->pi.ki = 2;
#endif
	s->pi.shift = PI_FRACBITS - BOARD_SPLL_DIV_BITS;
	s->pi.anti_windup = 1;

	/* Phase branch lock detection */
	s->ld.threshold = 200;
	s->ld.lock_samples = 10000;
	s->ld.delock_samples = 100;
}

void helper_init(struct spll_helper_state *s, int ref_channel)
{
	s->ref_src = ref_channel;
}

void helper_update(struct spll_helper_state *s, int tag,
			 int source)
{
	int err, y, tag_delta, raw_err;
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
	
	//spll_debug(SPLL_DBG_SRC_HELPER, SPLL_DBG_SIGNAL_TAG, tag, 0);
	//spll_debug(SPLL_DBG_SRC_HELPER, SPLL_DBG_SIGNAL_REF, s->p_setpoint, 0);

	if (s->tag_d0 < 0) {
		/* First tag. */
		s->p_setpoint = tag;
		s->tag_d0 = tag;
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
	if (s->tag_d0 > tag)
		s->p_adder += (1 << TAG_BITS);

	tag_delta = tag - s->tag_d0;
	if (tag_delta < 0)
		tag_delta += (1 << TAG_BITS);

	/* Compute the error */
	raw_err = (tag + s->p_adder) - s->p_setpoint;
	wrpc_spll_helper_expected_tag = s->p_setpoint;
	wrpc_spll_helper_preclamp_error = raw_err;
	wrpc_spll_helper_tag_delta = tag_delta;
	err = raw_err;

	/* And clamp */
	if (HELPER_ERROR_CLAMP) {
		if (err < -HELPER_ERROR_CLAMP)
			err = -HELPER_ERROR_CLAMP;
		if (err > HELPER_ERROR_CLAMP)
			err = HELPER_ERROR_CLAMP;
	}

	/* Handle wraparound */
	if ((tag + s->p_adder) > HELPER_TAG_WRAPAROUND
	    && s->p_setpoint > HELPER_TAG_WRAPAROUND) {
		s->p_adder -= HELPER_TAG_WRAPAROUND;
		s->p_setpoint -= HELPER_TAG_WRAPAROUND;
	}

	/* The next expected tag is the current plus one cycle */
	s->p_setpoint += (1 << HPLL_N);
	s->tag_d0 = tag;

	y = pi_update((spll_pi_t *)&s->pi, err);
	SPLL->DAC_HPLL = y;

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
		tag_delta - expected_delta, raw_err, err,
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
	s->last_lock_duration_ms = -1;

	pi_init((spll_pi_t *)&s->pi);
	ld_init((spll_lock_det_t *)&s->ld);

	s->lock_start_ms = timer_get_tics();

	spll_enable_tagger(s->ref_src, 1);
	//spll_debug(SPLL_DBG_SRC_HELPER, SPLL_DBG_SIGNAL_EVENT, SPLL_DBG_EVT_START, 1);
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
