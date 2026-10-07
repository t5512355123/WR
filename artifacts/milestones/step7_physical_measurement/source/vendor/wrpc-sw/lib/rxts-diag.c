/* Passive packet-specific RX timestamp diagnostic; no control feedback. */
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include "rxts-diag.h"
#include "pp-printf.h"

static uint32_t ring[RXTS_DIAG_RECORDS][RXTS_DIAG_WORDS];
static uint32_t snapshot[RXTS_DIAG_RECORDS][RXTS_DIAG_WORDS];
static uint32_t total, snapshot_id, snapshot_total;
static unsigned head, count, snapshot_count;
static int snapshot_ready;

static uint32_t be32(const uint8_t *p)
{
    return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 |
           (uint32_t)p[2] << 8 | p[3];
}

void rxts_diag_record(const void *packet, size_t length,
                      const struct wr_timestamp *ts, int64_t raw_sec,
                      int transition_point, int clock_period)
{
    const uint8_t *p = packet;
    uint32_t *r;
    unsigned type, declared, port;
    int phase_r;

    if (!p || !ts || length < 34 || (p[1] & 15) != 2)
        return;
    type = p[0] & 15;
    if (type != 0 && type != 1 && type != 8 && type != 9)
        return;
    declared = (unsigned)p[2] << 8 | p[3];
    if (declared > length || declared < (type == 9 ? 54u : 44u))
        return;
    r = ring[head];
    /* Main-loop producer and shell consumer are serialized on WRPC. No ISR
     * writes this ring. Page zero copies RAM before any console output. */
    r[0] = ++total;
    r[1] = type << 24 | (uint32_t)p[4] << 16 |
           (uint32_t)p[30] << 8 | p[31];
    r[2] = be32(p + 20);
    r[3] = be32(p + 24);
    port = (unsigned)p[28] << 8 | p[29];
    phase_r = ts->raw_phase - transition_point;
    if (phase_r < 0)
        phase_r += clock_period;
    r[4] = port | (ts->correct != 0) << 16 |
           (ts->raw_ahead != 0) << 17 |
           (phase_r > 3 * clock_period / 4 || phase_r < clock_period / 4) << 18;
    r[5] = (uint32_t)((uint64_t)raw_sec >> 32);
    r[6] = (uint32_t)raw_sec;
    r[7] = (uint32_t)ts->raw_nsec;
    r[8] = (uint32_t)ts->raw_phase;
    r[9] = (uint32_t)transition_point;
    r[10] = (uint32_t)((uint64_t)ts->sec >> 32);
    r[11] = (uint32_t)ts->sec;
    r[12] = (uint32_t)ts->nsec;
    r[13] = (uint32_t)ts->phase;
    /* Wire body timestamp. For Follow_Up/Delay_Resp this identifies the remote
     * T1/T4; Sync/Delay_Req body may be zero and must not be called valid T1/T3. */
    r[14] = (uint32_t)p[34] << 8 | p[35];
    r[15] = be32(p + 36);
    r[16] = be32(p + 40);
    r[17] = (uint32_t)clock_period;
    head = (head + 1) % RXTS_DIAG_RECORDS;
    if (count < RXTS_DIAG_RECORDS)
        count++;
}

int rxts_diag_show_page(unsigned page)
{
    unsigned i, j, start, end;
    if (page >= RXTS_DIAG_RECORDS / RXTS_DIAG_PAGE_ROWS)
        return -EINVAL;
    if (!page) {
        snapshot_count = count;
        snapshot_total = total;
        snapshot_id++;
        start = (head + RXTS_DIAG_RECORDS - count) % RXTS_DIAG_RECORDS;
        for (i = 0; i < count; i++)
            memcpy(snapshot[i], ring[(start + i) % RXTS_DIAG_RECORDS],
                   sizeof(snapshot[i]));
        snapshot_ready = 1;
    }
    if (!snapshot_ready)
        return -EAGAIN;
    pp_printf("RXTS_PAGE v=1 snapshot=%08x total=%08x page=%u count=%u\n",
              snapshot_id, snapshot_total, page, snapshot_count);
    start = page * RXTS_DIAG_PAGE_ROWS;
    end = start + RXTS_DIAG_PAGE_ROWS;
    if (end > snapshot_count)
        end = snapshot_count;
    for (i = start; i < end; i++) {
        pp_printf("RXTS_V1 idx=%u words=", i);
        for (j = 0; j < RXTS_DIAG_WORDS; j++)
            pp_printf("%08x%c", snapshot[i][j],
                      j + 1 == RXTS_DIAG_WORDS ? '\n' : ' ');
    }
    pp_printf("RXTS_END snapshot=%08x page=%u\n", snapshot_id, page);
    return 0;
}
