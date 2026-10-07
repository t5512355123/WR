/*
 * Read-only Main SoftPLL producer snapshot.
 *
 * This is deliberately separate from spll_main_state.  The latter is part
 * of the WRPC shared-memory ABI and must not be extended for an experiment.
 */
#ifndef __SPLL_MAIN_DIAG_H
#define __SPLL_MAIN_DIAG_H

#include <stdint.h>

#define SPLL_MAIN_DIAG_SCHEMA_VERSION 1U
#define SPLL_MAIN_DIAG_MAGIC 0x4d50344aU /* "MP4J" */

#define SPLL_MAIN_DIAG_BRANCH_NONE 0U
#define SPLL_MAIN_DIAG_BRANCH_FREQUENCY 1U
#define SPLL_MAIN_DIAG_BRANCH_PHASE 2U

#define SPLL_MAIN_DIAG_FLAG_VALID             (1U << 0)
#define SPLL_MAIN_DIAG_FLAG_FREQ_LOCK_BEFORE  (1U << 1)
#define SPLL_MAIN_DIAG_FLAG_FREQ_LOCK_AFTER   (1U << 2)
#define SPLL_MAIN_DIAG_FLAG_PHASE_LOCK_BEFORE (1U << 3)
#define SPLL_MAIN_DIAG_FLAG_PHASE_LOCK_AFTER  (1U << 4)
#define SPLL_MAIN_DIAG_FLAG_PHASE_CALLED      (1U << 5)
#define SPLL_MAIN_DIAG_FLAG_PHASE_IN_BAND     (1U << 6)
#define SPLL_MAIN_DIAG_FLAG_PHASE_OUT_OF_BAND (1U << 7)
#define SPLL_MAIN_DIAG_FLAG_DAC_WRITE         (1U << 8)
#define SPLL_MAIN_DIAG_FLAG_VCO_FREEZE        (1U << 9)

#define SPLL_MAIN_DIAG_STATUS_INVALID 0U
#define SPLL_MAIN_DIAG_STATUS_VALID   1U

/* Every member is exactly one 32-bit word.  The frame is copied by a
 * bounded seqlock reader and then published through the WDIAGS overlay. */
struct spll_main_diag_frame {
	uint32_t producer_epoch;
	uint32_t update_id;
	uint32_t init_generation;
	uint32_t producer_identity;
	int32_t freq_error;
	uint32_t branch_id;
	int32_t branch_error;
	int32_t pi_x;
	int32_t pi_output;
	int32_t pi_clamp_side;
	uint32_t flags;
	uint32_t freq_lock_count_before;
	uint32_t freq_lock_count_after;
	uint32_t phase_lock_count_before;
	uint32_t phase_lock_count_after;
	uint32_t sample_n;
	uint32_t source_ids;
	uint32_t total_updates;
	uint32_t frequency_branch_updates;
	uint32_t phase_branch_updates;
	uint32_t frequency_to_phase_transitions;
	uint32_t phase_to_frequency_transitions;
	uint32_t phase_detector_updates;
	uint32_t phase_in_band_updates;
	uint32_t phase_out_of_band_updates;
	uint32_t latest_transition_update_id;
	uint32_t latest_transition;
	uint32_t status;
	uint32_t last_frequency_branch_update_id;
	uint32_t last_phase_branch_update_id;
};

/* Copy only a completed, internally coherent Main producer frame. */
int spll_main_diag_copy(struct spll_main_diag_frame *out);

#endif /* __SPLL_MAIN_DIAG_H */
