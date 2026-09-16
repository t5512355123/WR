/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2010 - 2013 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

/* spll_main.c - Implementation of the main DDMTD PLL. */

#include <wrc.h>
#include "softpll_ng.h"
#include "spll_main_diag.h"
#include "spll_main_f4l_diag.h"

#if defined(CONFIG_TARGET_GENERIC_PHY_8BIT) || defined(CONFIG_TARGET_GENERIC_PHY_16BIT)
#include "boards/generic/de5a-identity.h"
#endif

#define MPLL_DISCARD_EARLY_TAGS 10
#define MPLL_TAG_WRAPAROUND 100000000
#if defined(DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE) && DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE
#define MPLL_FREQ_PRELOCK_GAIN_BOOST 4
#else
#define MPLL_FREQ_PRELOCK_GAIN_BOOST 20
#endif
/* ld_update() uses this as the lock-counter floor at which a persistent
 * out-of-band error releases the frequency lock.  It must be below
 * lock_samples; a value above it makes a claimed frequency lock sticky. */
#define MPLL_FREQ_DELOCK_FLOOR 10

#undef WITH_SEQUENCING

static volatile uint32_t spll_main_diag_epoch;
static volatile struct spll_main_diag_frame spll_main_diag_published;
static uint32_t spll_main_diag_update_id;
static uint32_t spll_main_diag_total_updates;
static uint32_t spll_main_diag_frequency_branch_updates;
static uint32_t spll_main_diag_phase_branch_updates;
static uint32_t spll_main_diag_frequency_to_phase_transitions;
static uint32_t spll_main_diag_phase_to_frequency_transitions;
static uint32_t spll_main_diag_phase_detector_updates;
static uint32_t spll_main_diag_phase_in_band_updates;
static uint32_t spll_main_diag_phase_out_of_band_updates;
static uint32_t spll_main_diag_latest_transition_update_id;
static uint32_t spll_main_diag_latest_transition;
static uint32_t spll_main_diag_last_frequency_branch_update_id;
static uint32_t spll_main_diag_last_phase_branch_update_id;
static uint32_t spll_main_diag_last_branch;

/* F4L is a read-only source-side diagnostic.  Keep all of its state outside
 * spll_main_state so the WRPC shared-memory ABI and the controller layout are
 * unchanged.  The 64-bit accumulators are intentionally retained in RAM and
 * split only when a page is copied to WDIAGS. */
static volatile uint32_t spll_main_f4l_diag_epoch;
static uint32_t spll_main_f4l_update_id;
static uint32_t spll_main_f4l_init_generation;
static uint32_t spll_main_f4l_producer_identity;
static uint32_t spll_main_f4l_source_ids;
static uint32_t spll_main_f4l_branch_id;
static uint32_t spll_main_f4l_flags;
static int32_t spll_main_f4l_branch_error;
static int32_t spll_main_f4l_freq_error;
static int32_t spll_main_f4l_pi_x;
static int32_t spll_main_f4l_pi_output;
static int32_t spll_main_f4l_pi_clamp_side;
static int32_t spll_main_f4l_phase_shift_current;

static uint32_t spll_main_f4l_total_updates;
static uint32_t spll_main_f4l_frequency_updates;
static uint32_t spll_main_f4l_phase_updates;
static uint32_t spll_main_f4l_phase_detector_updates;
static uint32_t spll_main_f4l_phase_in_band_updates;
static uint32_t spll_main_f4l_phase_out_of_band_updates;

static uint32_t spll_main_f4l_phase_pair_eligible;
static uint32_t spll_main_f4l_phase_pair_breaks;
static uint32_t spll_main_f4l_phase_pair_ambiguous;
static uint32_t spll_main_f4l_phase_positive_boundary;
static uint32_t spll_main_f4l_phase_negative_boundary;
static int64_t spll_main_f4l_phase_delta_sum;
static uint32_t spll_main_f4l_phase_shift_breaks;

static uint32_t spll_main_f4l_phase_freq_error_count;
static int64_t spll_main_f4l_phase_freq_error_sum;
static int32_t spll_main_f4l_phase_freq_error_min;
static int32_t spll_main_f4l_phase_freq_error_max;

static int64_t spll_main_f4l_frequency_actual_i_sum;
static int64_t spll_main_f4l_phase_actual_i_sum;
static int64_t spll_main_f4l_frequency_ki_x_sum;
static int64_t spll_main_f4l_phase_ki_x_sum;
static uint32_t spll_main_f4l_frequency_i_count;
static uint32_t spll_main_f4l_phase_i_count;
static uint32_t spll_main_f4l_clamp_event_count;
static uint32_t spll_main_f4l_anti_windup_event_count;
static uint32_t spll_main_f4l_actual_delta_mismatch_count;
static int64_t spll_main_f4l_last_i_before;
static int64_t spll_main_f4l_last_i_after;

static uint32_t spll_main_f4l_phase_histogram[16];
static uint32_t spll_main_f4l_phase_hist_out_of_range;

static int spll_main_f4l_have_last_phase;
static uint32_t spll_main_f4l_last_phase_update_id;
static uint32_t spll_main_f4l_last_phase_generation;
static uint32_t spll_main_f4l_last_phase_identity;
static uint32_t spll_main_f4l_last_phase_source_ids;
static int32_t spll_main_f4l_last_phase_shift;
static int32_t spll_main_f4l_last_phase_error;

static inline void spll_main_f4l_diag_barrier(void)
{
	__asm__ __volatile__("fence iorw, iorw" ::: "memory");
}

static void spll_main_f4l_diag_zero_state(void)
{
	int i;

	spll_main_f4l_update_id = 0;
	spll_main_f4l_init_generation = 0;
	spll_main_f4l_producer_identity = 0;
	spll_main_f4l_source_ids = 0;
	spll_main_f4l_branch_id = SPLL_MAIN_DIAG_BRANCH_NONE;
	spll_main_f4l_flags = 0;
	spll_main_f4l_branch_error = 0;
	spll_main_f4l_freq_error = 0;
	spll_main_f4l_pi_x = 0;
	spll_main_f4l_pi_output = 0;
	spll_main_f4l_pi_clamp_side = 0;
	spll_main_f4l_phase_shift_current = 0;
	spll_main_f4l_total_updates = 0;
	spll_main_f4l_frequency_updates = 0;
	spll_main_f4l_phase_updates = 0;
	spll_main_f4l_phase_detector_updates = 0;
	spll_main_f4l_phase_in_band_updates = 0;
	spll_main_f4l_phase_out_of_band_updates = 0;
	spll_main_f4l_phase_pair_eligible = 0;
	spll_main_f4l_phase_pair_breaks = 0;
	spll_main_f4l_phase_pair_ambiguous = 0;
	spll_main_f4l_phase_positive_boundary = 0;
	spll_main_f4l_phase_negative_boundary = 0;
	spll_main_f4l_phase_delta_sum = 0;
	spll_main_f4l_phase_shift_breaks = 0;
	spll_main_f4l_phase_freq_error_count = 0;
	spll_main_f4l_phase_freq_error_sum = 0;
	spll_main_f4l_phase_freq_error_min = 0;
	spll_main_f4l_phase_freq_error_max = 0;
	spll_main_f4l_frequency_actual_i_sum = 0;
	spll_main_f4l_phase_actual_i_sum = 0;
	spll_main_f4l_frequency_ki_x_sum = 0;
	spll_main_f4l_phase_ki_x_sum = 0;
	spll_main_f4l_frequency_i_count = 0;
	spll_main_f4l_phase_i_count = 0;
	spll_main_f4l_clamp_event_count = 0;
	spll_main_f4l_anti_windup_event_count = 0;
	spll_main_f4l_actual_delta_mismatch_count = 0;
	spll_main_f4l_last_i_before = 0;
	spll_main_f4l_last_i_after = 0;
	spll_main_f4l_phase_hist_out_of_range = 0;
	spll_main_f4l_have_last_phase = 0;
	spll_main_f4l_last_phase_update_id = 0;
	spll_main_f4l_last_phase_generation = 0;
	spll_main_f4l_last_phase_identity = 0;
	spll_main_f4l_last_phase_source_ids = 0;
	spll_main_f4l_last_phase_shift = 0;
	spll_main_f4l_last_phase_error = 0;
	for (i = 0; i < 16; i++)
		spll_main_f4l_phase_histogram[i] = 0;
}

void spll_main_f4l_diag_reset(void)
{
	/* Reset is called at the same Main init/start boundaries as the existing
	 * F4J producer diagnostic.  Publish an even, empty epoch. */
	spll_main_f4l_diag_epoch++;
	if (!(spll_main_f4l_diag_epoch & 1U))
		spll_main_f4l_diag_epoch++;
	spll_main_f4l_diag_barrier();
	spll_main_f4l_diag_zero_state();
	spll_main_f4l_diag_barrier();
	spll_main_f4l_diag_epoch++;
}

static uint32_t spll_main_f4l_clamp_code(int32_t clamp_side)
{
	if (clamp_side > 0)
		return SPLL_MAIN_F4L_CLAMP_POSITIVE;
	if (clamp_side < 0)
		return SPLL_MAIN_F4L_CLAMP_NEGATIVE;
	return SPLL_MAIN_F4L_CLAMP_NONE;
}

static void spll_main_f4l_diag_record_pair(uint32_t update_id,
					   uint32_t init_generation,
					   uint32_t producer_identity,
					   uint32_t source_ids,
					   int32_t phase_shift_current,
					   int32_t phase_error)
{
	int64_t raw_delta;
	int64_t delta;
	int continuity_ok;

	if (spll_main_f4l_have_last_phase) {
		continuity_ok = init_generation == spll_main_f4l_last_phase_generation &&
			producer_identity == spll_main_f4l_last_phase_identity &&
			source_ids == spll_main_f4l_last_phase_source_ids &&
			update_id == spll_main_f4l_last_phase_update_id + 1U &&
			phase_shift_current == spll_main_f4l_last_phase_shift;
		if (phase_shift_current != spll_main_f4l_last_phase_shift)
			spll_main_f4l_phase_shift_breaks++;
		if (continuity_ok) {
			raw_delta = (int64_t)phase_error -
				(int64_t)spll_main_f4l_last_phase_error;
			if (raw_delta == 8192 || raw_delta == -8192) {
				spll_main_f4l_phase_pair_ambiguous++;
			} else {
				delta = raw_delta;
				if (delta > 8192) {
					delta -= 16384;
					spll_main_f4l_phase_positive_boundary++;
				} else if (delta < -8192) {
					delta += 16384;
					spll_main_f4l_phase_negative_boundary++;
				}
				spll_main_f4l_phase_pair_eligible++;
				spll_main_f4l_phase_delta_sum += delta;
			}
		} else {
			spll_main_f4l_phase_pair_breaks++;
		}
	}

	spll_main_f4l_have_last_phase = 1;
	spll_main_f4l_last_phase_update_id = update_id;
	spll_main_f4l_last_phase_generation = init_generation;
	spll_main_f4l_last_phase_identity = producer_identity;
	spll_main_f4l_last_phase_source_ids = source_ids;
	spll_main_f4l_last_phase_shift = phase_shift_current;
	spll_main_f4l_last_phase_error = phase_error;
}

void spll_main_f4l_diag_record(uint32_t update_id,
				       uint32_t init_generation,
				       uint32_t producer_identity,
				       uint32_t source_ids,
				       uint32_t branch_id,
				       uint32_t flags,
				       int32_t branch_error,
				       int32_t freq_error,
				       int32_t pi_x,
				       int32_t pi_output,
				       int32_t pi_clamp_side,
				       int32_t phase_shift_current,
				       int64_t integrator_before,
				       int64_t i_new,
				       int64_t integrator_after,
				       int32_t pi_ki)
{
	uint32_t odd_epoch;
	int64_t actual_delta = integrator_after - integrator_before;
	int64_t proposal = (int64_t)pi_ki * (int64_t)pi_x;
	int phase_error;
	int histogram_bin;

	/* i_new is retained in the call contract for offline integrity checks;
	 * the live proposal is recomputed from the recorded Ki and x. */
	(void)i_new;

	odd_epoch = spll_main_f4l_diag_epoch + 1U;
	if (!(odd_epoch & 1U))
		odd_epoch++;
	spll_main_f4l_diag_epoch = odd_epoch;
	spll_main_f4l_diag_barrier();

	spll_main_f4l_update_id = update_id;
	spll_main_f4l_init_generation = init_generation;
	spll_main_f4l_producer_identity = producer_identity;
	spll_main_f4l_source_ids = source_ids;
	spll_main_f4l_branch_id = branch_id;
	spll_main_f4l_flags = flags;
	spll_main_f4l_branch_error = branch_error;
	spll_main_f4l_freq_error = freq_error;
	spll_main_f4l_pi_x = pi_x;
	spll_main_f4l_pi_output = pi_output;
	spll_main_f4l_pi_clamp_side = pi_clamp_side;
	spll_main_f4l_phase_shift_current = phase_shift_current;
	spll_main_f4l_total_updates++;
	if (branch_id == SPLL_MAIN_DIAG_BRANCH_FREQUENCY) {
		spll_main_f4l_frequency_updates++;
		spll_main_f4l_frequency_actual_i_sum += actual_delta;
		spll_main_f4l_frequency_ki_x_sum += proposal;
		spll_main_f4l_frequency_i_count++;
	} else if (branch_id == SPLL_MAIN_DIAG_BRANCH_PHASE) {
		spll_main_f4l_phase_updates++;
		spll_main_f4l_phase_actual_i_sum += actual_delta;
		spll_main_f4l_phase_ki_x_sum += proposal;
		spll_main_f4l_phase_i_count++;
		spll_main_f4l_phase_detector_updates++;
		if (flags & SPLL_MAIN_DIAG_FLAG_PHASE_IN_BAND)
			spll_main_f4l_phase_in_band_updates++;
		if (flags & SPLL_MAIN_DIAG_FLAG_PHASE_OUT_OF_BAND)
			spll_main_f4l_phase_out_of_band_updates++;

		phase_error = branch_error;
		if (phase_error < -8192 || phase_error > 8191) {
			spll_main_f4l_phase_hist_out_of_range++;
			histogram_bin = phase_error < -8192 ? 0 : 15;
		} else {
			histogram_bin = (phase_error + 8192) >> 10;
		}
		spll_main_f4l_phase_histogram[histogram_bin]++;
		spll_main_f4l_phase_freq_error_count++;
		spll_main_f4l_phase_freq_error_sum += (int64_t)freq_error;
		if (spll_main_f4l_phase_freq_error_count == 1) {
			spll_main_f4l_phase_freq_error_min = freq_error;
			spll_main_f4l_phase_freq_error_max = freq_error;
		} else {
			if (freq_error < spll_main_f4l_phase_freq_error_min)
				spll_main_f4l_phase_freq_error_min = freq_error;
			if (freq_error > spll_main_f4l_phase_freq_error_max)
				spll_main_f4l_phase_freq_error_max = freq_error;
		}
		spll_main_f4l_diag_record_pair(update_id, init_generation,
			producer_identity, source_ids, phase_shift_current, phase_error);
	} else {
		/* A non-phase sample intentionally breaks phase-pair continuity. */
		if (spll_main_f4l_have_last_phase)
			spll_main_f4l_phase_pair_breaks++;
		spll_main_f4l_have_last_phase = 0;
	}
	if (pi_clamp_side != 0)
		spll_main_f4l_clamp_event_count++;
	if (actual_delta != proposal) {
		spll_main_f4l_actual_delta_mismatch_count++;
		if (pi_clamp_side != 0)
			spll_main_f4l_anti_windup_event_count++;
	}
	spll_main_f4l_last_i_before = integrator_before;
	spll_main_f4l_last_i_after = integrator_after;

	spll_main_f4l_diag_barrier();
	spll_main_f4l_diag_epoch = odd_epoch + 1U;
}

static void spll_main_f4l_put_i64(uint32_t *words, uint32_t low_index,
					  int64_t value)
{
	uint64_t bits = (uint64_t)value;

	words[low_index] = (uint32_t)bits;
	words[low_index + 1U] = (uint32_t)(bits >> 32);
}

static void spll_main_f4l_diag_fill(uint32_t page,
				    uint32_t source_epoch,
				    struct spll_main_f4l_diag_frame *out)
{
	uint32_t i;
	uint32_t clamp_code = spll_main_f4l_clamp_code(
		spll_main_f4l_pi_clamp_side);

	for (i = 0; i < SPLL_MAIN_F4L_DIAG_FRAME_WORDS; i++)
		out->words[i] = 0;
	out->words[1] = SPLL_MAIN_F4L_DIAG_MAGIC;
	out->words[2] = SPLL_MAIN_F4L_DIAG_SCHEMA_VERSION |
		(page << 8);
	out->words[3] = source_epoch;
	out->words[4] = spll_main_f4l_update_id;
	out->words[5] = spll_main_f4l_init_generation;
	out->words[6] = spll_main_f4l_producer_identity;
	out->words[7] = (spll_main_f4l_branch_id & 0xffU) |
		((spll_main_f4l_flags & 0xffffU) << 8) |
		((clamp_code & 0x3U) << 24);
	out->words[8] = (uint32_t)spll_main_f4l_branch_error;
	out->words[9] = (uint32_t)spll_main_f4l_freq_error;
	out->words[10] = (uint32_t)spll_main_f4l_pi_x;
	out->words[11] = (uint32_t)spll_main_f4l_pi_output;
	out->words[12] = (uint32_t)spll_main_f4l_phase_shift_current;
	out->words[13] = spll_main_f4l_total_updates;
	out->words[14] = spll_main_f4l_frequency_updates;
	out->words[15] = spll_main_f4l_phase_updates;
	out->words[16] = spll_main_f4l_source_ids;

	if (page == SPLL_MAIN_F4L_PAGE_SUMMARY) {
		out->words[17] = spll_main_f4l_phase_detector_updates;
		out->words[18] = spll_main_f4l_phase_in_band_updates;
		out->words[19] = spll_main_f4l_phase_out_of_band_updates;
		out->words[20] = spll_main_f4l_phase_pair_eligible;
		out->words[21] = spll_main_f4l_phase_pair_breaks;
		out->words[22] = spll_main_f4l_phase_pair_ambiguous;
		out->words[23] = spll_main_f4l_phase_positive_boundary;
		out->words[24] = spll_main_f4l_phase_negative_boundary;
		spll_main_f4l_put_i64(out->words, 25,
			spll_main_f4l_phase_delta_sum);
		out->words[27] = spll_main_f4l_phase_freq_error_count;
		spll_main_f4l_put_i64(out->words, 28,
			spll_main_f4l_phase_freq_error_sum);
		out->words[30] = (uint32_t)spll_main_f4l_phase_freq_error_min;
		out->words[31] = (uint32_t)spll_main_f4l_phase_freq_error_max;
		out->words[32] = spll_main_f4l_phase_shift_breaks;
		out->words[33] = spll_main_f4l_phase_hist_out_of_range;
	} else if (page == SPLL_MAIN_F4L_PAGE_INTEGRATOR) {
		spll_main_f4l_put_i64(out->words, 17,
			spll_main_f4l_frequency_actual_i_sum);
		spll_main_f4l_put_i64(out->words, 19,
			spll_main_f4l_phase_actual_i_sum);
		spll_main_f4l_put_i64(out->words, 21,
			spll_main_f4l_frequency_ki_x_sum);
		spll_main_f4l_put_i64(out->words, 23,
			spll_main_f4l_phase_ki_x_sum);
		out->words[25] = spll_main_f4l_frequency_i_count;
		out->words[26] = spll_main_f4l_phase_i_count;
		out->words[27] = spll_main_f4l_clamp_event_count;
		out->words[28] = spll_main_f4l_anti_windup_event_count;
		out->words[29] = spll_main_f4l_actual_delta_mismatch_count;
		spll_main_f4l_put_i64(out->words, 30,
			spll_main_f4l_last_i_before);
		spll_main_f4l_put_i64(out->words, 32,
			spll_main_f4l_last_i_after);
	} else {
		for (i = 0; i < 16; i++)
			out->words[17U + i] = spll_main_f4l_phase_histogram[i];
		out->words[33] = spll_main_f4l_phase_hist_out_of_range;
	}
}

int spll_main_f4l_diag_copy(uint32_t page,
				    struct spll_main_f4l_diag_frame *out)
{
	uint32_t before, after;
	int attempt;

	if (!out || page >= SPLL_MAIN_F4L_DIAG_PAGE_COUNT)
		return 0;
	for (attempt = 0; attempt < 4; attempt++) {
		before = spll_main_f4l_diag_epoch;
		if (before & 1U)
			continue;
		spll_main_f4l_diag_fill(page, before, out);
		after = spll_main_f4l_diag_epoch;
		if (before == after && !(after & 1U) &&
			out->words[3] == after && spll_main_f4l_total_updates != 0)
			return 1;
	}
	out->words[0] = 0xffffffffU;
	out->words[1] = 0;
	out->words[2] = 0;
	out->words[3] = 0xffffffffU;
	return 0;
}

static inline void spll_main_diag_barrier(void)
{
	__asm__ __volatile__("fence iorw, iorw" ::: "memory");
}

static void spll_main_diag_reset(void)
{
	spll_main_diag_epoch = 0;
	spll_main_diag_update_id = 0;
	spll_main_diag_total_updates = 0;
	spll_main_diag_frequency_branch_updates = 0;
	spll_main_diag_phase_branch_updates = 0;
	spll_main_diag_frequency_to_phase_transitions = 0;
	spll_main_diag_phase_to_frequency_transitions = 0;
	spll_main_diag_phase_detector_updates = 0;
	spll_main_diag_phase_in_band_updates = 0;
	spll_main_diag_phase_out_of_band_updates = 0;
	spll_main_diag_latest_transition_update_id = 0;
	spll_main_diag_latest_transition = 0;
	spll_main_diag_last_frequency_branch_update_id = 0;
	spll_main_diag_last_phase_branch_update_id = 0;
	spll_main_diag_last_branch = SPLL_MAIN_DIAG_BRANCH_NONE;
	spll_main_diag_published.producer_epoch = 0;
	spll_main_diag_published.update_id = 0;
	spll_main_diag_published.init_generation = 0;
	spll_main_diag_published.producer_identity = 0;
	spll_main_diag_published.freq_error = 0;
	spll_main_diag_published.branch_id = SPLL_MAIN_DIAG_BRANCH_NONE;
	spll_main_diag_published.branch_error = 0;
	spll_main_diag_published.pi_x = 0;
	spll_main_diag_published.pi_output = 0;
	spll_main_diag_published.pi_clamp_side = 0;
	spll_main_diag_published.flags = 0;
	spll_main_diag_published.freq_lock_count_before = 0;
	spll_main_diag_published.freq_lock_count_after = 0;
	spll_main_diag_published.phase_lock_count_before = 0;
	spll_main_diag_published.phase_lock_count_after = 0;
	spll_main_diag_published.sample_n = 0;
	spll_main_diag_published.source_ids = 0;
	spll_main_diag_published.total_updates = 0;
	spll_main_diag_published.frequency_branch_updates = 0;
	spll_main_diag_published.phase_branch_updates = 0;
	spll_main_diag_published.frequency_to_phase_transitions = 0;
	spll_main_diag_published.phase_to_frequency_transitions = 0;
	spll_main_diag_published.phase_detector_updates = 0;
	spll_main_diag_published.phase_in_band_updates = 0;
	spll_main_diag_published.phase_out_of_band_updates = 0;
	spll_main_diag_published.latest_transition_update_id = 0;
	spll_main_diag_published.latest_transition = 0;
	spll_main_diag_published.status = SPLL_MAIN_DIAG_STATUS_INVALID;
	spll_main_diag_published.last_frequency_branch_update_id = 0;
	spll_main_diag_published.last_phase_branch_update_id = 0;
}

static void spll_main_diag_publish(struct spll_main_diag_frame *frame)
{
	uint32_t odd_epoch = spll_main_diag_epoch + 1U;
	uint32_t even_epoch;

	if (!(odd_epoch & 1U))
		odd_epoch++;
	even_epoch = odd_epoch + 1U;
	spll_main_diag_epoch = odd_epoch;
	spll_main_diag_barrier();
	frame->producer_epoch = even_epoch;
	spll_main_diag_published.producer_epoch = frame->producer_epoch;
	spll_main_diag_published.update_id = frame->update_id;
	spll_main_diag_published.init_generation = frame->init_generation;
	spll_main_diag_published.producer_identity = frame->producer_identity;
	spll_main_diag_published.freq_error = frame->freq_error;
	spll_main_diag_published.branch_id = frame->branch_id;
	spll_main_diag_published.branch_error = frame->branch_error;
	spll_main_diag_published.pi_x = frame->pi_x;
	spll_main_diag_published.pi_output = frame->pi_output;
	spll_main_diag_published.pi_clamp_side = frame->pi_clamp_side;
	spll_main_diag_published.flags = frame->flags;
	spll_main_diag_published.freq_lock_count_before = frame->freq_lock_count_before;
	spll_main_diag_published.freq_lock_count_after = frame->freq_lock_count_after;
	spll_main_diag_published.phase_lock_count_before = frame->phase_lock_count_before;
	spll_main_diag_published.phase_lock_count_after = frame->phase_lock_count_after;
	spll_main_diag_published.sample_n = frame->sample_n;
	spll_main_diag_published.source_ids = frame->source_ids;
	spll_main_diag_published.total_updates = frame->total_updates;
	spll_main_diag_published.frequency_branch_updates = frame->frequency_branch_updates;
	spll_main_diag_published.phase_branch_updates = frame->phase_branch_updates;
	spll_main_diag_published.frequency_to_phase_transitions = frame->frequency_to_phase_transitions;
	spll_main_diag_published.phase_to_frequency_transitions = frame->phase_to_frequency_transitions;
	spll_main_diag_published.phase_detector_updates = frame->phase_detector_updates;
	spll_main_diag_published.phase_in_band_updates = frame->phase_in_band_updates;
	spll_main_diag_published.phase_out_of_band_updates = frame->phase_out_of_band_updates;
	spll_main_diag_published.latest_transition_update_id = frame->latest_transition_update_id;
	spll_main_diag_published.latest_transition = frame->latest_transition;
	spll_main_diag_published.status = frame->status;
	spll_main_diag_published.last_frequency_branch_update_id = frame->last_frequency_branch_update_id;
	spll_main_diag_published.last_phase_branch_update_id = frame->last_phase_branch_update_id;
	spll_main_diag_barrier();
	spll_main_diag_epoch = even_epoch;
}

int spll_main_diag_copy(struct spll_main_diag_frame *out)
{
	uint32_t before, after;
	int attempt;

	if (!out)
		return 0;
	for (attempt = 0; attempt < 4; attempt++) {
		before = spll_main_diag_epoch;
		if (before & 1U)
			continue;
		out->producer_epoch = spll_main_diag_published.producer_epoch;
		out->update_id = spll_main_diag_published.update_id;
		out->init_generation = spll_main_diag_published.init_generation;
		out->producer_identity = spll_main_diag_published.producer_identity;
		out->freq_error = spll_main_diag_published.freq_error;
		out->branch_id = spll_main_diag_published.branch_id;
		out->branch_error = spll_main_diag_published.branch_error;
		out->pi_x = spll_main_diag_published.pi_x;
		out->pi_output = spll_main_diag_published.pi_output;
		out->pi_clamp_side = spll_main_diag_published.pi_clamp_side;
		out->flags = spll_main_diag_published.flags;
		out->freq_lock_count_before = spll_main_diag_published.freq_lock_count_before;
		out->freq_lock_count_after = spll_main_diag_published.freq_lock_count_after;
		out->phase_lock_count_before = spll_main_diag_published.phase_lock_count_before;
		out->phase_lock_count_after = spll_main_diag_published.phase_lock_count_after;
		out->sample_n = spll_main_diag_published.sample_n;
		out->source_ids = spll_main_diag_published.source_ids;
		out->total_updates = spll_main_diag_published.total_updates;
		out->frequency_branch_updates = spll_main_diag_published.frequency_branch_updates;
		out->phase_branch_updates = spll_main_diag_published.phase_branch_updates;
		out->frequency_to_phase_transitions = spll_main_diag_published.frequency_to_phase_transitions;
		out->phase_to_frequency_transitions = spll_main_diag_published.phase_to_frequency_transitions;
		out->phase_detector_updates = spll_main_diag_published.phase_detector_updates;
		out->phase_in_band_updates = spll_main_diag_published.phase_in_band_updates;
		out->phase_out_of_band_updates = spll_main_diag_published.phase_out_of_band_updates;
		out->latest_transition_update_id = spll_main_diag_published.latest_transition_update_id;
		out->latest_transition = spll_main_diag_published.latest_transition;
		out->status = spll_main_diag_published.status;
		out->last_frequency_branch_update_id = spll_main_diag_published.last_frequency_branch_update_id;
		out->last_phase_branch_update_id = spll_main_diag_published.last_phase_branch_update_id;
		after = spll_main_diag_epoch;
		if (before == after && !(after & 1U) &&
		    out->producer_epoch == after)
			return out->status == SPLL_MAIN_DIAG_STATUS_VALID;
	}
	out->producer_epoch = 0xffffffffU;
	out->status = SPLL_MAIN_DIAG_STATUS_INVALID;
	return 0;
}

#ifdef CONFIG_DAC_LOG
extern void spll_log_dac(int y);
#else
static inline void spll_log_dac(int y) {}
#endif

void mpll_init(struct spll_main_state *s, int id_ref, int id_out)
{
	/* Frequency branch PI controller */

	s->ps_freeze = 0;
	s->vco_freeze = 0;
	s->pi.y_min = (5 << BOARD_SPLL_DIV_BITS);
	s->pi.y_max = (1 << BOARD_SPLL_DAC_BITS) - (5 << BOARD_SPLL_DIV_BITS);
	s->pi.anti_windup = 1;
	s->pi.bias = (1 << (BOARD_SPLL_DAC_BITS - 1)); // midscale
	s->pi.shift = PI_FRACBITS - BOARD_SPLL_DIV_BITS;
#if defined(CONFIG_TARGET_WR_SWITCH)
	if (spll_ljd_present) {
		s->pi.kp = 2000;
		s->pi.ki = 15;
	} else {
		s->pi.kp = 1100;		// / 2;
		s->pi.ki = 30;			// / 2;
	}
#elif defined(CONFIG_WR_NODE)
	/* Main-frequency polarity is established as positive by the A/B run.
	 * F4b isolates the candidate gains to the Slave image; the Master keeps
	 * the known-good control operating point. */
#ifndef DE5A_MAIN_PI_KP_OVERRIDE
#define DE5A_MAIN_PI_KP_OVERRIDE 300
#endif
#if defined(DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE) && \
	DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE && \
	defined(DE5A_MAIN_PI_KP_OVERRIDE)
#error "F4K Main Kp override cannot be combined with the legacy PI candidate"
#endif
#if (DE5A_MAIN_PI_KP_OVERRIDE != 300) && \
	(DE5A_MAIN_PI_KP_OVERRIDE != 600)
#error "F4K Main Kp override must be exactly 300 or 600"
#endif
#if defined(DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE) && DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE
	s->pi.kp = 1300;
	s->pi.ki = 3;
#else
	s->pi.kp = DE5A_MAIN_PI_KP_OVERRIDE;
	s->pi.ki = 1;
#endif
#else
#error "Please set CONFIG for wr switch or wr node"
#endif
	s->enabled = 0;

	/* Freqency branch lock detection */
	s->freq_ld.threshold = 50;
	s->freq_ld.lock_samples = 50;
	s->freq_ld.delock_samples = MPLL_FREQ_DELOCK_FLOOR;

	s->freq_prelock_gain_boost = MPLL_FREQ_PRELOCK_GAIN_BOOST;

	s->phase_ld.threshold = 1200;
	s->phase_ld.lock_samples = 1000;
	s->phase_ld.delock_samples = 100;

	s->id_ref = id_ref;
	s->id_out = id_out;
	s->dac_index = id_out - spll_n_chan_ref;
	s->dbg_src_id = (s->dac_index == 0) ? SPLL_DBG_SRC_MAIN : SPLL_DBG_SRC_AUX( s->dac_index - 1 );
	if (s->dac_index == 0) {
		spll_main_diag_reset();
		spll_main_f4l_diag_reset();
	}
#ifdef CONFIG_FRAC_SPLL
	s->div_ref = s->div_fb = 0;
#endif

	if( s->gain_sched )
	{
		s->gain_sched->current_stage = 0;
		s->gain_sched->locked_d = 0;
	}

	pi_init((spll_pi_t *)&s->pi);
	s->pi.dithered = 0;
	ld_init((spll_lock_det_t *)&s->freq_ld);
	ld_init((spll_lock_det_t *)&s->phase_ld);
}

static inline void mpll_handle_gain_schedule( struct spll_main_state *s )
{
	int do_update = 0;

	if (!s->gain_sched)
	{
		s->locked = s->phase_ld.locked;
		return;
	}

	if( s->gain_sched->locked_d && !s->phase_ld.locked ) // Pll out-of-lock? restart
	{
		s->gain_sched->current_stage = 0;
		s->locked = 0;
		do_update = 1;
	}
	else if ( !s->gain_sched->locked_d && s->phase_ld.locked ) // PLL lock acquired? advance stage
	{
		spll_debug(s->dbg_src_id, SPLL_DBG_SIGNAL_EVENT, SPLL_DBG_EVT_GAIN_SWITCH, 0);
		if ( s->gain_sched->current_stage == s->gain_sched->n_stages - 1 )
		{
			s->locked = 1;
			s->gain_sched->locked_d = 1;
			return;
		}
		else
		{
			s->gain_sched->current_stage++;
		}

		do_update = 1;
	}

	if( do_update )
	{
		spll_gain_schedule_item_t* stage = &s->gain_sched->stages[ s->gain_sched->current_stage ];
		s->pi.kp = stage->kp;
		s->pi.ki = stage->ki;
		s->pi.shift = stage->shift;
		s->phase_ld.lock_samples = stage->lock_samples;
		s->phase_ld.lock_cnt = 0;
		s->phase_ld.lock_changed = 0;
		s->phase_ld.locked = 0;
		s->gain_sched->locked_d = 0;
	}

	s->gain_sched->locked_d = s->phase_ld.locked;
}

void mpll_start(struct spll_main_state *s)
{
	pll_verbose("MPLL_Start [dac %d]\n", s->dac_index);

	s->discard_early_cnt = MPLL_DISCARD_EARLY_TAGS;
	s->ps_freeze = 0;
	s->vco_freeze = 0;

	s->adder_ref = s->adder_out = 0;
	s->tag_ref = -1;
	s->tag_out = -1;
	s->tag_ref_d = -1;
	s->tag_out_d = -1;
	s->tag_ref_raw_d = -1;
	s->tag_out_raw_d2 = -1;

	s->phase_shift_target = 0;
	s->phase_shift_current = 0;
	s->sample_n = 0;
	s->enabled = 1;
	s->locked = 0;
#ifdef CONFIG_FRAC_SPLL
	s->tag_out_raw_d = -1;
	s->tag_out_interp = -1;
	s->tag_out_raw = -1;
	s->n_ref = s->n_out = 0;
	s->div_cnt = 0;
#endif

	s->last_freq_lock_duration_ms = -1;
	s->last_phase_lock_duration_ms = -1;
	if (s->dac_index == 0) {
		spll_main_diag_reset();
		spll_main_f4l_diag_reset();
	}

	if( s->gain_sched )
	{
		s->gain_sched->current_stage = 0;
		s->gain_sched->locked_d = 0;
		s->pi.kp = s->gain_sched->stages[0].kp;
		s->pi.ki = s->gain_sched->stages[0].ki;
		s->pi.shift = s->gain_sched->stages[0].shift;
		s->phase_ld.lock_samples = s->gain_sched->stages[0].lock_samples;
		s->phase_ld.lock_cnt = 0;
	}

	pi_init((spll_pi_t *)&s->pi);
	s->pi.dithered = 0;
	ld_init((spll_lock_det_t *)&s->phase_ld);
	ld_init((spll_lock_det_t *)&s->freq_ld);

	s->lock_start_ms = timer_get_tics();

	spll_enable_tagger(s->id_ref, 1);
	spll_enable_tagger(s->id_out, 1);
	spll_debug(s->dbg_src_id, SPLL_DBG_SIGNAL_EVENT, SPLL_DBG_EVT_START, 1);
}

void mpll_stop(struct spll_main_state *s)
{
	spll_enable_tagger(s->id_out, 0);
	s->enabled = 0;
}

//#ifdef CONFIG_FRAC_SPLL
static inline void update_dtag_dt( int *dtag_dt, int tag, int *tag_d )
{
	if( tag == *tag_d )
		return;

	*dtag_dt = (tag - *tag_d);
	if( *dtag_dt < 0 )
			*dtag_dt += (1<<TAG_BITS);
	*tag_d = tag;
}
//#endif

int mpll_update(struct spll_main_state *s, int tag, int source)
{
	if(!s->enabled)
	    return SPLL_LOCKED;

	int err, y;

	if (source == s->id_ref)
	{
		s->tag_ref = tag;

#ifdef CONFIG_FRAC_SPLL
		s->n_ref++;

		if(s->tag_out_interp >= 0)
		{
			s->tag_out = s->tag_out_interp;
			s->n_out++;
			s->tag_out_interp = -1;
		}
#endif
	}

	if (source == s->id_out)
	{
#ifdef CONFIG_FRAC_SPLL
		s->tag_out_raw_d = s->tag_out_raw;
		s->tag_out_raw = tag;
		if (s->div_ref == 0)
		{
		s->tag_out = tag;
			s->n_out++;
		}
		else
		{
			int t_raw = s->tag_out_raw;
			if (t_raw < s->tag_out_raw_d)
				t_raw += (1 << TAG_BITS);

			int w0 = s->div_cnt * s->div_fb;
			int w1 = (s->div_cnt + 1) * s->div_fb;

			//printf("w0 %d/%d w1 %d/%d\n", w0, div_ref, w1, div_ref );

			int f0 = w0 % s->div_ref;
			int f1 = w1 % s->div_ref;

			int c0 = w0 / s->div_ref;
			int c1 = w1 / s->div_ref;

			int tr = ((s->div_ref - f0) * s->tag_out_raw_d + f0 * t_raw) / s->div_ref;

			//printf("Interp[NORM]: %d tprev %d tcur %d c0 %d c1 %d f0 %d f1 %d\n", tr, tag_si_prev, tag_si, c0, c1, f0, f1 );
			//spll_debug(mtag | DBG_TAG, tr, 1);

			s->tag_out = tr;
			s->n_out++;

			if (c0 == c1)
			{
				s->div_cnt++;

				int tr2 = ((s->div_ref - f1) * s->tag_out_raw_d + f1 * t_raw) / s->div_ref;

				s->tag_out_interp = tr2;
				//printf("Interp[SLIP]: %d tprev %d tcur %d c0 %d c1 %d f0 %d f1 %d\n", tr, tag_si_prev, tag_si, c0, c1, f0, f1 );
			}
			else
			{
				s->tag_out_interp = -1;
			}

			s->div_cnt++;

			if (s->div_cnt == s->div_ref)
				s->div_cnt = 0;
		}
#else
		s->tag_out = tag;
#endif
	}

	if (s->tag_ref >= 0) {
		update_dtag_dt( &s->dref_dt, s->tag_ref, &s->tag_ref_raw_d );

		if(s->tag_ref_d >= 0 && s->tag_ref_d > s->tag_ref)
			s->adder_ref += (1 << TAG_BITS);

		s->tag_ref_d = s->tag_ref;
	}


	if (s->tag_out >= 0) {
		update_dtag_dt( &s->dout_dt, s->tag_out, &s->tag_out_raw_d2 );

		if(s->tag_out_d >= 0 && s->tag_out_d > s->tag_out)
			s->adder_out += (1 << TAG_BITS);

		s->tag_out_d = s->tag_out;
	}

	if (s->tag_ref >= 0 && s->tag_out >= 0) {

#ifndef CONFIG_FRAC_SPLL
           if(s->discard_early_cnt == 1)
        {
            int adj_ref = s->tag_ref + s->adder_ref;
            int adj_out = s->tag_out + s->adder_out;
            if( adj_ref > adj_out )
            {
                int delta = adj_ref - adj_out;
                s->adder_ref -= (delta >> HPLL_N) << HPLL_N;
            }
            else
            {
                int delta = adj_out - adj_ref;
                s->adder_out -= (delta >> HPLL_N) << HPLL_N;
            }
            if (s->adder_ref < 0 || s->adder_out < 0)
            {
                s->adder_ref += MPLL_TAG_WRAPAROUND;
                s->adder_out += MPLL_TAG_WRAPAROUND;
            }
        }

        if( s->discard_early_cnt > 0 )
            s->discard_early_cnt--;

#endif

		int freq_error = s->dout_dt - s->dref_dt;
		uint32_t diag_flags = 0;
		uint32_t diag_branch = SPLL_MAIN_DIAG_BRANCH_NONE;
		uint32_t diag_freq_lock_count_before = 0;
		uint32_t diag_freq_lock_count_after = 0;
	uint32_t diag_phase_lock_count_before = 0;
	uint32_t diag_phase_lock_count_after = 0;
	uint32_t diag_update_id = 0;
	struct spll_main_diag_frame diag_frame;
#if defined(DE5A_F4L_MAIN_PHASE_DIAG) && DE5A_F4L_MAIN_PHASE_DIAG
	int32_t diag_f4l_pi_x = 0;
	int32_t diag_f4l_pi_output = 0;
	int32_t diag_f4l_pi_clamp_side = 0;
	int32_t diag_f4l_phase_shift_current = 0;
	int32_t diag_f4l_pi_ki = 0;
	int64_t diag_f4l_integrator_before = 0;
	int64_t diag_f4l_i_new = 0;
	int64_t diag_f4l_integrator_after = 0;
#endif

		if (s->dac_index == 0) {
			diag_freq_lock_count_before = (uint32_t)s->freq_ld.lock_cnt;
			if (s->freq_ld.locked)
				diag_flags |= SPLL_MAIN_DIAG_FLAG_FREQ_LOCK_BEFORE;
		}

		ld_update((spll_lock_det_t *)&s->freq_ld, freq_error);

		if ( s->freq_ld.lock_changed && s->freq_ld.locked )
		{
			s->last_freq_lock_duration_ms = timer_get_tics() - s->lock_start_ms;
		}

		if( !s->freq_ld.locked )
		{
			diag_branch = SPLL_MAIN_DIAG_BRANCH_FREQUENCY;
			err = -s->freq_prelock_gain_boost * freq_error;
		}
		else
		{
			diag_branch = SPLL_MAIN_DIAG_BRANCH_PHASE;
			err = s->adder_ref + s->tag_ref - s->adder_out - s->tag_out;
		}

#ifndef WITH_SEQUENCING

		/* Hack: the PLL is locked, so the tags are close to
		   each other. But when we start phase shifting, after
		   reaching full clock period, one of the reference
		   tags will flip before the other, causing a suddent
		   2**HPLL_N jump in the error.  So, once the PLL is
		   locked, we just mask out everything above
		   2**HPLL_N.

		   Proper solution: tag sequence numbers */
		if (s->freq_ld.locked)
		{
			err &= (1 << HPLL_N) - 1;
			if (err & (1 << (HPLL_N - 1)))
				err |= ~((1 << HPLL_N) - 1);
		}

#endif

		y = pi_update((spll_pi_t *)&s->pi, err);
#if defined(DE5A_F4L_MAIN_PHASE_DIAG) && DE5A_F4L_MAIN_PHASE_DIAG
		if (s->dac_index == 0) {
			/* Capture the completed PI trace before the optional gain schedule
			 * changes kp/ki for the next iteration. */
			diag_f4l_pi_x = (int32_t)s->pi.trace_x;
			diag_f4l_pi_output = (int32_t)y;
			diag_f4l_pi_clamp_side = (int32_t)s->pi.trace_clamp_side;
			diag_f4l_phase_shift_current =
				(int32_t)s->phase_shift_current;
			diag_f4l_pi_ki = (int32_t)s->pi.ki;
			diag_f4l_integrator_before = s->pi.trace_integrator_before;
			diag_f4l_i_new = s->pi.trace_i_new;
			diag_f4l_integrator_after = s->pi.trace_integrator_after;
		}
#endif
		if(!s->vco_freeze)
		{
			SPLL->DAC_MAIN = SPLL_DAC_MAIN_VALUE_W(y)
				| SPLL_DAC_MAIN_DAC_SEL_W(s->dac_index);
		}
		if (s->dac_index == 0)
			spll_log_dac(y);

		spll_debug(s->dbg_src_id, SPLL_DBG_SIGNAL_PHASE_CURRENT, s->phase_shift_current, 0);
		spll_debug(s->dbg_src_id, SPLL_DBG_SIGNAL_PHASE_TARGET, s->phase_shift_target, 0);
		spll_debug(s->dbg_src_id, SPLL_DBG_SIGNAL_TIME_MS, timer_get_tics(), 0);
		spll_debug(s->dbg_src_id, SPLL_DBG_SIGNAL_REF, s->dref_dt, 0);
		spll_debug(s->dbg_src_id, SPLL_DBG_SIGNAL_TAG, s->dout_dt, 0);
		spll_debug(s->dbg_src_id, SPLL_DBG_SIGNAL_ERR, err, 0);
		spll_debug(s->dbg_src_id, SPLL_DBG_SIGNAL_SAMPLE_ID, s->sample_n++, 0);
		spll_debug(s->dbg_src_id, SPLL_DBG_SIGNAL_Y, y, 1);

		s->tag_out = -1;
		s->tag_ref = -1;

		if (s->adder_ref > 2 * MPLL_TAG_WRAPAROUND
		    && s->adder_out > 2 * MPLL_TAG_WRAPAROUND) {
			s->adder_ref -= MPLL_TAG_WRAPAROUND;
			s->adder_out -= MPLL_TAG_WRAPAROUND;
		}

		if (s->locked && !s->ps_freeze) {
			if (s->phase_shift_current < s->phase_shift_target) {
				s->phase_shift_current++;
#if defined(CONFIG_TARGET_WR_SWITCH)
				s->adder_ref++;
#else
				s->adder_ref--;
#endif
			} else if (s->phase_shift_current >
				   s->phase_shift_target) {
				s->phase_shift_current--;
#if defined(CONFIG_TARGET_WR_SWITCH)
				s->adder_ref--;
#else
				s->adder_ref++;
#endif
			}
		}

		if(s->freq_ld.locked)
		{
			if (s->dac_index == 0) {
				diag_phase_lock_count_before = (uint32_t)s->phase_ld.lock_cnt;
				if (s->phase_ld.locked)
					diag_flags |= SPLL_MAIN_DIAG_FLAG_PHASE_LOCK_BEFORE;
				diag_flags |= SPLL_MAIN_DIAG_FLAG_PHASE_CALLED;
				if (err >= -s->phase_ld.threshold &&
				    err <= s->phase_ld.threshold)
					diag_flags |= SPLL_MAIN_DIAG_FLAG_PHASE_IN_BAND;
				else
					diag_flags |= SPLL_MAIN_DIAG_FLAG_PHASE_OUT_OF_BAND;
			}

			ld_update((spll_lock_det_t *)&s->phase_ld, err);
			if( s->phase_ld.lock_changed) 
			{
				spll_debug(s->dbg_src_id, SPLL_DBG_SIGNAL_EVENT, 
				s->phase_ld.locked ? SPLL_DBG_EVT_LOCK_ACQUIRED : SPLL_DBG_EVT_LOCK_LOSS, 1);

				if( s->phase_ld.locked )
				{
					s->last_phase_lock_duration_ms = timer_get_tics() - s->lock_start_ms;
				}
			}

			mpll_handle_gain_schedule(s);
		}

		if (s->dac_index == 0) {
			diag_freq_lock_count_after = (uint32_t)s->freq_ld.lock_cnt;
			diag_phase_lock_count_after = (uint32_t)s->phase_ld.lock_cnt;
			if (s->freq_ld.locked)
				diag_flags |= SPLL_MAIN_DIAG_FLAG_FREQ_LOCK_AFTER;
			if (s->phase_ld.locked)
				diag_flags |= SPLL_MAIN_DIAG_FLAG_PHASE_LOCK_AFTER;
			if (!s->vco_freeze)
				diag_flags |= SPLL_MAIN_DIAG_FLAG_DAC_WRITE;
			if (s->vco_freeze)
				diag_flags |= SPLL_MAIN_DIAG_FLAG_VCO_FREEZE;

			diag_update_id = ++spll_main_diag_update_id;
			++spll_main_diag_total_updates;
			if (diag_branch == SPLL_MAIN_DIAG_BRANCH_FREQUENCY) {
				++spll_main_diag_frequency_branch_updates;
				spll_main_diag_last_frequency_branch_update_id = diag_update_id;
			} else if (diag_branch == SPLL_MAIN_DIAG_BRANCH_PHASE) {
				++spll_main_diag_phase_branch_updates;
				spll_main_diag_last_phase_branch_update_id = diag_update_id;
			}
			if (diag_branch == SPLL_MAIN_DIAG_BRANCH_PHASE)
				++spll_main_diag_phase_detector_updates;
			if (diag_branch == SPLL_MAIN_DIAG_BRANCH_PHASE &&
			    (diag_flags & SPLL_MAIN_DIAG_FLAG_PHASE_IN_BAND))
				++spll_main_diag_phase_in_band_updates;
			if (diag_branch == SPLL_MAIN_DIAG_BRANCH_PHASE &&
			    (diag_flags & SPLL_MAIN_DIAG_FLAG_PHASE_OUT_OF_BAND))
				++spll_main_diag_phase_out_of_band_updates;
			if (spll_main_diag_last_branch != SPLL_MAIN_DIAG_BRANCH_NONE &&
			    spll_main_diag_last_branch != diag_branch) {
				if (spll_main_diag_last_branch == SPLL_MAIN_DIAG_BRANCH_FREQUENCY &&
				    diag_branch == SPLL_MAIN_DIAG_BRANCH_PHASE)
					++spll_main_diag_frequency_to_phase_transitions;
				else if (spll_main_diag_last_branch == SPLL_MAIN_DIAG_BRANCH_PHASE &&
					 diag_branch == SPLL_MAIN_DIAG_BRANCH_FREQUENCY)
					++spll_main_diag_phase_to_frequency_transitions;
				spll_main_diag_latest_transition_update_id = diag_update_id;
				spll_main_diag_latest_transition =
					(spll_main_diag_last_branch << 8) | diag_branch;
			}
			spll_main_diag_last_branch = diag_branch;
			diag_flags |= SPLL_MAIN_DIAG_FLAG_VALID;
			diag_frame.update_id = diag_update_id;
			diag_frame.init_generation = wrpc_spll_init_count;
			diag_frame.producer_identity =
				((uint32_t)s->dac_index & 0xffU) |
				(((uint32_t)s->id_ref & 0xffU) << 8) |
				(((uint32_t)s->id_out & 0xffU) << 16);
			diag_frame.freq_error = (int32_t)freq_error;
			diag_frame.branch_id = diag_branch;
			diag_frame.branch_error = (int32_t)err;
			diag_frame.pi_x = (int32_t)s->pi.trace_x;
			diag_frame.pi_output = (int32_t)y;
			diag_frame.pi_clamp_side = (int32_t)s->pi.trace_clamp_side;
			diag_frame.flags = diag_flags;
			diag_frame.freq_lock_count_before = diag_freq_lock_count_before;
			diag_frame.freq_lock_count_after = diag_freq_lock_count_after;
			diag_frame.phase_lock_count_before = diag_phase_lock_count_before;
			diag_frame.phase_lock_count_after = diag_phase_lock_count_after;
			diag_frame.sample_n = (uint32_t)s->sample_n;
			diag_frame.source_ids =
				((uint32_t)s->id_ref & 0xffU) |
				(((uint32_t)s->id_out & 0xffU) << 8);
			diag_frame.total_updates = spll_main_diag_total_updates;
			diag_frame.frequency_branch_updates = spll_main_diag_frequency_branch_updates;
			diag_frame.phase_branch_updates = spll_main_diag_phase_branch_updates;
			diag_frame.frequency_to_phase_transitions =
				spll_main_diag_frequency_to_phase_transitions;
			diag_frame.phase_to_frequency_transitions =
				spll_main_diag_phase_to_frequency_transitions;
			diag_frame.phase_detector_updates = spll_main_diag_phase_detector_updates;
			diag_frame.phase_in_band_updates = spll_main_diag_phase_in_band_updates;
			diag_frame.phase_out_of_band_updates = spll_main_diag_phase_out_of_band_updates;
			diag_frame.latest_transition_update_id =
				spll_main_diag_latest_transition_update_id;
			diag_frame.latest_transition = spll_main_diag_latest_transition;
			diag_frame.status = SPLL_MAIN_DIAG_STATUS_VALID;
			diag_frame.last_frequency_branch_update_id =
				spll_main_diag_last_frequency_branch_update_id;
			diag_frame.last_phase_branch_update_id =
				spll_main_diag_last_phase_branch_update_id;
#if defined(DE5A_F4L_MAIN_PHASE_DIAG) && DE5A_F4L_MAIN_PHASE_DIAG
			spll_main_f4l_diag_record(
				diag_update_id, wrpc_spll_init_count,
				((uint32_t)s->dac_index & 0xffU) |
					(((uint32_t)s->id_ref & 0xffU) << 8) |
					(((uint32_t)s->id_out & 0xffU) << 16),
				((uint32_t)s->id_ref & 0xffU) |
					(((uint32_t)s->id_out & 0xffU) << 8),
				diag_branch, diag_flags, (int32_t)err,
				(int32_t)freq_error,
				diag_f4l_pi_x, diag_f4l_pi_output,
				diag_f4l_pi_clamp_side, diag_f4l_phase_shift_current,
				diag_f4l_integrator_before, diag_f4l_i_new,
				diag_f4l_integrator_after, diag_f4l_pi_ki);
#endif
			spll_main_diag_publish(&diag_frame);
		}

		if(s->locked)
			return SPLL_LOCKED;
	}

	return SPLL_LOCKING;
}

#ifdef CONFIG_WRPC_PPSI /* use __div64_32 from ppsi library to save libgcc memory */
static int32_t from_picos(int32_t ps)
{
	uint64_t ups = ps;

	if (ps >= 0) {
		ups *= 1 << HPLL_N;
		__div64_32(&ups, CLOCK_PERIOD_PICOSECONDS);
		return ups;
	}
	ups = -ps * (1 << HPLL_N);
	__div64_32(&ups, CLOCK_PERIOD_PICOSECONDS);
	return -ups;
}
#else /* previous implementation: ptp-noposix has no __div64_32 available */
static int32_t from_picos(int32_t ps)
{
	return (int32_t) ((int64_t) ps * (int64_t) (1 << HPLL_N) /
			  (int64_t) CLOCK_PERIOD_PICOSECONDS);
}
#endif

int mpll_set_phase_shift(struct spll_main_state *s,
				int desired_shift_ps)
{
	int div = (DIVIDE_DMTD_CLOCKS_BY_2 ? 2 : 1);
	s->phase_shift_target = from_picos(desired_shift_ps) / div;
	return 0;
}

int mpll_shifter_busy(struct spll_main_state *s)
{
	return s->phase_shift_target != s->phase_shift_current;
}
