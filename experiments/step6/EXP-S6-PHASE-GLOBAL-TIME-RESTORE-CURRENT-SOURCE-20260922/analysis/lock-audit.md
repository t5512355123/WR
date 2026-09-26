# Step5 four-lock audit

Source: `raw/observe/step5-four-locks-300s.log`

```text
session_elapsed_ms                 = 300588
target_duration_ms                 = 300000
hard_duration_ms                   = 310000
run_end_reason                     = TARGET_REACHED
stop_reason                        = NONE
single_reader                      = PASS

F4L_SLAVE_CYCLE                    = 316/316
F4L_MAIN_DIAG                      = 316/316
MAIN_F4L_VALID                     = 316/316
TRANSPORT_COHERENT                 = 316/316
BRANCH_ID=PHASE                    = 316/316
FLAGS=383 (0x17F)                  = 316/316

HELPER_LOCKED                      = 316/316
PSTAT_LOCKED                       = 316/316
PHY_LINK_USABLE                    = 316/316
TERMINAL=0                         = 316/316
RESET_CHANGED=0                    = 316/316
SPLL_DELOCK_COUNT=0                = 316/316
SI_CONFIG_DROP_COUNT=0             = 316/316
BOOT_GENERATION=1                  = 316/316
WR_FAILURE_REASON=0                = 316/316
STOP_REASON=NONE                   = 316/316
```

`FLAGS=383 (0x17F)` is decoded from the checked-in
`vendor/wrpc-sw/softpll/spll_main_diag.h`: valid, frequency lock before and
after, phase lock before and after, phase detector called, phase in-band, and
DAC write; phase-out-of-band is clear.

The observer's optional schedule-page fields were not valid in this reader
(`schedule_valid=0`). They are not used as a substitute for the direct F4L
four-lock evidence. The raw `MAIN_F4L_VALID`, Main diagnostic flags, Helper
lock, and PSTAT lock fields are valid and consistent in all 316 cycles.

Therefore the functional Step5 four-lock gate is **PASS for a 300.588-second
session**. Timing closure remains an independent implementation caveat and is
not part of this functional verdict.
