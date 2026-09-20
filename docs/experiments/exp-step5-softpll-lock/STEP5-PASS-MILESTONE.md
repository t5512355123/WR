# Step5 Functional PASS Milestone

## 判定

Step5 functional PASS requires one credible, valid WR session with a
continuous observation window of at least 300 seconds and all four conditions:

```text
HPLL / Helper lock        = 1
Main frequency lock      = 1
Main phase lock          = 1
PSTAT.locked             = 1
```

Quartus timing closure is an independent implementation status. It must be
reported, but it is not a gate for this functional milestone.

The 2026-09-20 capture now satisfies the policy:

```text
STEP5_FUNCTIONAL_PASS    = PASS
STEP5_PASS_MILESTONE     = ESTABLISHED
FULL_CHAIN_MAX_SECONDS   = 300.321
FULL_CHAIN_300S           = 1
TIMING_CLOSED             = NO  # independent implementation status
```

## Milestone version

| 欄位 | 值 |
|---|---|
| Experiment | `EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920` |
| Firmware/source commit | `26e138fdc0bfc8426704b397141d563cf4d580a2` |
| Observer contract commit | `47d9a394e53eda31476c82de2a85ad82573494ed` |
| Branch | `exp/step5-softpll-lock` |
| Master SOF SHA-256 | `a2945df48fe86038fdff138f4b6368a777fa3df13f98ac9620fb30baa1ee0129` |
| Slave SOF SHA-256 | `7462d94a521f52e7660295a6873de5141658fbf5392d90a4d4ade7d4e5f36f50` |
| Master WNS | `-0.289 ns` |
| Slave WNS | `-0.361 ns` |
| Functional window | `300321 ms` |

完整 provenance、programmer output、preflight、raw observer log、checksum 與
offline analysis 位於
[`EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920/REPORT.md`](EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920/REPORT.md)。

## Four-lock evidence

```text
HELPER_LOCKED                       = 316/316
PSTAT_LOCKED                        = 316/316
MAIN_F4L_VALID                      = 316/316
BRANCH_ID=PHASE                    = 316/316
FLAGS=383                           = 316/316
FREQ_LOCK_AFTER                     = 316/316
PHASE_LOCK_BEFORE                   = 316/316
PHASE_LOCK_AFTER                    = 316/316
PHY_LINK_USABLE                     = 316/316
TERMINAL=0                          = 316/316
RESET_CHANGED=0                     = 316/316
SPLL_DELOCK_COUNT=0                 = 316/316
```

`FLAGS=383 (0x17F)` is decoded from
`vendor/wrpc-sw/softpll/spll_main_diag.h`: valid, frequency lock before and
after, phase lock before and after, phase detector called, phase in-band, and
DAC write; phase-out-of-band is clear.

## Data-quality caveat

The strict paged F4L analyzer retained four repeated page-accounting warnings
(two repeated frame identities at cycles 50/51 and 274/275). The affected rows
still carry `FLAGS=383`; no lock bit was lost, no raw row was removed, and the
per-cycle four-lock audit remains complete. The raw log and the strict JSON
analysis are preserved beside the report rather than being silently relaxed.

## Historical context

The earlier `17f20ad32c619212133e6134205cf017212d7dd8` candidate remains
historical evidence only: its best complete lock chain was 113.791 seconds and
`FULL_CHAIN_300S=0`. It is not the current milestone and is not used to claim
the present PASS.

Timing closure remains open for a later implementation task, but it does not
invalidate this Step5 functional milestone.
