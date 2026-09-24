# 300-second four-lock audit

Source: `raw/f4l_threshold20_phase_ki1_stability_300s_retry.log`

```text
session_elapsed_ms                 = 300321
target_duration_ms                 = 300000
hard_duration_ms                   = 310000
run_end_reason                     = TARGET_REACHED
stop_reason                        = NONE
quartus_exit                       = 0
single_reader                      = PASS

F4L_MAIN_DIAG                      = 316/316
F4L_MAIN_VALID                     = 316/316
BRANCH_ID=PHASE                    = 316/316
FLAGS=383                          = 316/316
FREQ_LOCK_AFTER                    = 316/316
PHASE_LOCK_BEFORE                  = 316/316
PHASE_LOCK_AFTER                   = 316/316

HELPER_LOCKED                      = 316/316
PSTAT_LOCKED                       = 316/316
PHY_LINK_USABLE                    = 316/316
TERMINAL=0                         = 316/316
RESET_CHANGED=0                    = 316/316
SPLL_DELOCK_COUNT=0                = 316/316
BOOT_GENERATION stable              = 316/316
```

`FLAGS=383 (0x17F)` is decoded using
`vendor/wrpc-sw/softpll/spll_main_diag.h`: valid, frequency lock before and
after, phase lock before and after, phase detector called, phase in-band, and
DAC write; phase-out-of-band is clear.

The strict paged-frame analyzer reports 312 schema-consistent rows and four
repeated-observation accounting warnings (two repeated frame identities at
cycles 50/51 and 274/275). Those four rows still carry the same `FLAGS=383`
lock evidence. The caveat is retained in the report; it is not silently
discarded and does not alter the per-cycle four-lock audit.

Therefore the functional four-lock gate is **PASS for a 300.321-second
session**. Quartus timing closure remains an independent implementation
caveat.
