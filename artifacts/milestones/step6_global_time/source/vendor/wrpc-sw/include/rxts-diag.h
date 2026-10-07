#ifndef WRPC_RXTS_DIAG_H
#define WRPC_RXTS_DIAG_H
#include "net.h"

/* Diagnostic RAM only; no caller receives or consumes these records. */
#define RXTS_DIAG_WORDS 18
#define RXTS_DIAG_RECORDS 32
#define RXTS_DIAG_PAGE_ROWS 4
void rxts_diag_record(const void *packet, size_t length,
                      const struct wr_timestamp *ts, int64_t raw_sec,
                      int transition_point, int clock_period);
int rxts_diag_show_page(unsigned page);
#endif
