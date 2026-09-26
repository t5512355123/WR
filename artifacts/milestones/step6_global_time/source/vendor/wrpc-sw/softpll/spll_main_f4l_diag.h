/*
 * Read-only Main phase-drift and PI-integrator diagnostics for F4L.
 *
 * The frame is deliberately a versioned, paged wire image.  It is not part
 * of spll_main_state or any WRPC shared-memory ABI.  The producer updates its
 * private counters in a bounded seqlock and the diagnostics task copies one
 * page at a time into the existing WDIAGS Main overlay.
 */
#ifndef __SPLL_MAIN_F4L_DIAG_H
#define __SPLL_MAIN_F4L_DIAG_H

#include <stdint.h>

#define SPLL_MAIN_F4L_DIAG_SCHEMA_VERSION 1U
#define SPLL_MAIN_F4L_DIAG_MAGIC 0x46344c31U /* "F4L1" */
#define SPLL_MAIN_F4L_DIAG_PAGE_COUNT 3U
#define SPLL_MAIN_F4L_DIAG_FRAME_WORDS 34U

#define SPLL_MAIN_F4L_PAGE_SUMMARY 0U
#define SPLL_MAIN_F4L_PAGE_INTEGRATOR 1U
#define SPLL_MAIN_F4L_PAGE_HISTOGRAM 2U

/* Clamp encoding used in the packed branch/flags word. */
#define SPLL_MAIN_F4L_CLAMP_NONE 0U
#define SPLL_MAIN_F4L_CLAMP_POSITIVE 1U
#define SPLL_MAIN_F4L_CLAMP_NEGATIVE 2U

struct spll_main_f4l_diag_frame {
	uint32_t words[SPLL_MAIN_F4L_DIAG_FRAME_WORDS];
};

void spll_main_f4l_diag_reset(void);

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
				       int32_t pi_ki);

/* Copy one coherent page.  The transport publication epoch (word 0) is
 * filled by the WDIAGS writer, not by this source-side copy. */
int spll_main_f4l_diag_copy(uint32_t page,
				    struct spll_main_f4l_diag_frame *out);

#endif /* __SPLL_MAIN_F4L_DIAG_H */
