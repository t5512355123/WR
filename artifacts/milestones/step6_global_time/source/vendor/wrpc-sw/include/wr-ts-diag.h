#ifndef WR_TS_DIAG_H
#define WR_TS_DIAG_H
#include <stdint.h>
/* Main-loop RAM only, not a control input or shared-memory ABI change.
 * V1 words: 0 serial; 1 UCNT; 2 state-before:state-after; 3/4 SETP before/after;
 * 5 Sync:DelayResp sequence; 6 msg:domain:remote-port; 7/8 remote clock ID;
 * 9 E2E; 10 WR phase writes; 11 WR inits; 12 fixed-latch flags; 13 SPLL inits;
 * 14 servo flags; 15 return code. All 64-bit words below are high,low pairs.
 * 16..31 raw T1..T4; 32..47 calibrated T1..T4; 48..63 TXm,RXs,TXs,RXm deltas;
 * 64..79 corrected RTT,DMS,meanDelay,CKO; 80..83 raw RTT; 84..85 asymmetry.
 * Each pp_time uses signed64 seconds followed by signed64 scaled ns (2^16).
 * Raw means before WR fixed-delta correction, not raw OOB/coarse counter.
 */
#define WR_TS_DIAG_WORDS 86
#define WR_TS_DIAG_RECORDS 16
int wr_ts_diag_show_page(unsigned page);
#endif
