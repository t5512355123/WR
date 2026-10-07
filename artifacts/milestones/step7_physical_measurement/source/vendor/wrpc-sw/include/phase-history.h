#ifndef WR_PHASE_HISTORY_H
#define WR_PHASE_HISTORY_H
#include <stdint.h>
#define WR_PHASE_HISTORY_WORDS 36
#define WR_PHASE_HISTORY_RECORDS 32
/* Accepted WR calculation -> bounded passive Main/tracker copies. Independent
 * groups: not packet-time atomic and not proof of physical phase causality. */
void wr_phase_history_record(uint32_t update, uint32_t state, int32_t before,
    int32_t after, uint32_t writes, int64_t cko_sec, int64_t cko_scaled_ns,
    int64_t dms_sec, int64_t dms_scaled_ns);
int wr_phase_history_show_page(unsigned page);
#endif
