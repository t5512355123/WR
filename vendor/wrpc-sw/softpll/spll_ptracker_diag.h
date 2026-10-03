/* Private passive publication metadata; NOT the shared-memory tracker ABI. */
#ifndef SPLL_PTRACKER_DIAG_H
#define SPLL_PTRACKER_DIAG_H
#include <stdint.h>
struct spll_ptracker_diag_frame {
    uint32_t epoch, generation, publications, published_ms;
    int32_t phase_raw, reference_tag, input_tag;
    uint32_t ready_enabled;
};
int spll_ptracker_diag_copy(unsigned channel, struct spll_ptracker_diag_frame *out);
#endif
