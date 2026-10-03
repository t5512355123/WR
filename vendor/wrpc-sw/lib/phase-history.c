#include <stdint.h>
#include <string.h>
#include <errno.h>
#include "phase-history.h"
#include "pp-printf.h"
#include "../softpll/spll_main_diag.h"
#include "../softpll/spll_ptracker_diag.h"
extern uint32_t timer_get_tics(void);
extern volatile uint32_t wrpc_spll_init_count;
static uint32_t ring[WR_PHASE_HISTORY_RECORDS][WR_PHASE_HISTORY_WORDS];
static uint32_t snapshot[WR_PHASE_HISTORY_RECORDS][WR_PHASE_HISTORY_WORDS];
static uint32_t total, snapshot_id, snapshot_total;
static unsigned head, count, snapshot_count;
static int snapshot_ready;
static void put64(uint32_t *p, int64_t v)
{
    p[0] = (uint32_t)((uint64_t)v >> 32); p[1] = (uint32_t)v;
}
void wr_phase_history_record(uint32_t update, uint32_t state, int32_t before,
    int32_t after, uint32_t writes, int64_t cko_sec, int64_t cko_scaled_ns,
    int64_t dms_sec, int64_t dms_scaled_ns)
{
    struct spll_main_diag_frame m;
    struct spll_ptracker_diag_frame p;
    uint32_t *r = ring[head];
    memset(r, 0, sizeof(ring[0]));
    r[0] = ++total; r[1] = update; r[2] = state;
    r[3] = (uint32_t)before; r[4] = (uint32_t)after; r[5] = writes;
    r[6] = wrpc_spll_init_count;
    /* Timestamp precedes the two independent copies. Not a Main publication
     * timestamp; sample_n/update_id progression establishes fresh updates. */
    r[7] = timer_get_tics();
    put64(r + 8, cko_sec); put64(r + 10, cko_scaled_ns);
    put64(r + 12, dms_sec); put64(r + 14, dms_scaled_ns);
    r[16] = spll_main_diag_copy(&m);
    if (r[16]) {
        r[17] = m.update_id; r[18] = m.init_generation; r[19] = m.branch_id;
        r[20] = (uint32_t)m.branch_error; r[21] = (uint32_t)m.freq_error;
        r[22] = (uint32_t)m.pi_x; r[23] = (uint32_t)m.pi_output;
        r[24] = m.flags; r[25] = m.sample_n; r[35] = m.producer_epoch;
    }
    r[26] = spll_ptracker_diag_copy(0, &p);
    if (r[26]) {
        r[27] = p.generation; r[28] = p.publications; r[29] = p.published_ms;
        r[30] = (uint32_t)p.phase_raw; r[31] = p.ready_enabled;
        r[32] = (uint32_t)p.reference_tag; r[33] = (uint32_t)p.input_tag;
        r[34] = p.epoch;
    }
    head = (head + 1) % WR_PHASE_HISTORY_RECORDS;
    if (count < WR_PHASE_HISTORY_RECORDS) count++;
}
int wr_phase_history_show_page(unsigned page)
{
    unsigned i, j, first, end;
    if (page >= WR_PHASE_HISTORY_RECORDS / 2) return -EINVAL;
    if (!page) {
        snapshot_count = count; snapshot_total = total; snapshot_id++;
        first = (head + WR_PHASE_HISTORY_RECORDS - count) % WR_PHASE_HISTORY_RECORDS;
        for (i = 0; i < count; i++)
            memcpy(snapshot[i], ring[(first + i) % WR_PHASE_HISTORY_RECORDS], sizeof(ring[0]));
        snapshot_ready = 1;
    }
    if (!snapshot_ready) return -EAGAIN;
    pp_printf("PHIST_PAGE v=1 snapshot=%08x total=%08x page=%u count=%u words=36\n",
        snapshot_id, snapshot_total, page, snapshot_count);
    first = page * 2; end = first + 2;
    if (end > snapshot_count) end = snapshot_count;
    for (i = first; i < end; i++) {
        pp_printf("PHIST_V1 idx=%u words=", i);
        for (j = 0; j < WR_PHASE_HISTORY_WORDS; j++)
            pp_printf("%08x%c", snapshot[i][j], j + 1 == WR_PHASE_HISTORY_WORDS ? '\n' : ' ');
    }
    pp_printf("PHIST_END snapshot=%08x page=%u\n", snapshot_id, page);
    return 0;
}
