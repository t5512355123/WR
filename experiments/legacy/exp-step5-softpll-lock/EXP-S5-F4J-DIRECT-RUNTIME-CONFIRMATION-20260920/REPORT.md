# EXP-S5-F4J-DIRECT-RUNTIME-CONFIRMATION-20260920

## Verdict

```text
REPROGRAM                         = NO
DIRECT_RUNTIME_OPERATING_GATE      = PASS
SLAVE_LINK                         = PASS
SLAVE_PTP_PARENT_CALIBRATED        = PASS
SLAVE_HELPER_LOCK                  = PASS (1000/1000)
SLAVE_SPLL_SEQ                     = PASS (6 / SEQ_WAIT_MAIN)
SLAVE_MAIN_ENABLED                 = PASS
SLAVE_MAIN_FREQ_LOCKED             = PASS
SLAVE_MAIN_PHASE_LOCKED            = NO (expected research state)
SLAVE_PSTAT_LOCKED                 = NO (expected research state)
RESET_GENERATION_STABILITY         = PASS
JTAG_WB_TRANSPORT                  = PASS
WR_FAILURE_REASON                  = 3 (sticky historical WRS_S_LOCK timeout)
F4J_OBSERVER_FRESHNESS_BLOCKER     = YES
F4J_30S_PRODUCER_AUDIT             = NOT_ALLOWED_YET
F4J_ACCEPTANCE_AUDIT               = NOT_RUN
STEP5_RESULT                       = NO
STOP_REASON                        = HISTORICAL_WR_FAILURE_REQUIRES_FRESHNESS_FIX
```

The actual SoftPLL operating state is now suitable for the intended F4J audit, but the current F4J observer is not yet safe to use because a historical failure reason remains present. This run therefore proves Main start/frequency-lock readiness only; it does not evaluate producer-frame acceptance versus hysteresis and is not a Step5 pass.

## Provenance

```text
experiment                         EXP-S5-F4J-DIRECT-RUNTIME-CONFIRMATION-20260920
branch                             exp/step5-softpll-lock
session image                      F4J image retained from source commit 63bf952a
prior program/report commit        701416ca
Slave SOF SHA256                   f70d688bd1e703177e4e59b713f8165d871fe4b3c735888b169ddea9526346a6
Master SOF SHA256                  7cbe368bab2f94a8e7276cb7d8f066ee386e02f8e072b686a6e2a9ca59b96f1c
command                            quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
remote start/end                   2026-09-20 00:29:39 / 00:29:54+08:00
raw SHA256                         22B048FC545178A116EB1BAFCC7F7FA35861E5355B9A88E7292A3424CF358A36
raw size                           22088 bytes
```

No source, firmware, RTL, SDB, control parameter, image, or hardware route was changed in this experiment.

## Slave operating-state gate (`DE5 [1-11.2]`)

The upstream and SoftPLL state satisfied the direct confirmation:

```text
CORE_TM_LINK_UP                   = 1
CORE_LINK_OK                      = 1
PHY_LINK_USABLE                   = 1
PSTAT_LINK                        = 1
WDIAGS_PTP                        = 9 SLAVE (raw=00004109)
parentCalibrated                  = 1
LOCK_ENABLE                       = 4
STEP4B_ALLOWED                    = YES
STEP4B_RESULT                     = PASS
SPLL_MODE                         = 3 (SLAVE)
SPLL_SEQ_STATE                    = 6 (SEQ_WAIT_MAIN)
HELPER_LOCKED                     = 1
HELPER_LOCK_COUNT                 = 1000/1000
MAIN_ENABLED                      = 1
MAIN_FREQ_LOCKED                  = 1
MAIN_PHASE_LOCKED                 = 0
MAIN_FREQ_COUNT                   = 50/50
MAIN_PHASE_COUNT                  = 100/1000
PSTAT_LOCKED                      = 0
```

The diagnostic window also showed active DMTD/tag/TRR/helper counters, `RXERR delta=0`, and no reset or SI configuration drop:

```text
BOOT_GENERATION delta             = 0
CPU_RESET_COUNT delta             = 0
WR_CORE_RESET_COUNT delta         = 0
SI_CONFIG_DROP_COUNT delta        = 0
```

The `MAIN_PHASE_LOCKED=0` / `PSTAT_LOCKED=0` state is the intended frequency-locked, phase-unlocked research state and is not the reason this run was stopped.

## Historical failure/freshness boundary

The same raw capture contains:

```text
WR_FAILURE_DEBUG                  = TIMEOUT
last_fail_state                   = WRS_S_LOCK
failure_count                     = 35329
LOCK_RESULT_RAW                   = 6D6E0601
```

Using the repository's lock-result packing, bits `[15:9]` of `0x6D6E0601` decode to failure reason `3` (`WR_S_LOCK_TIMEOUT`). The reason is present in the direct confirmation while the current operating state is otherwise healthy, so it is treated as a sticky historical failure shadow, not proof that this one-shot reader created a new timeout.

The advisor explicitly identified that the current F4J path still uses legacy terminal semantics. Therefore running the 30-second F4J observer now could incorrectly turn this historical reason into a fresh terminal. The correct boundary is:

```text
Helper acquisition                  PASS
Main start                          PASS
Main frequency lock                 PASS
Operating runtime gate              PASS
F4J observer freshness               NOT PROVEN
F4J producer audit                   NOT ALLOWED YET
```

## Master reference (`DE5 [1-11.1]`)

Master remained healthy for the shared runtime check: Step 1/2/4A passed, RXERR and reset/generation deltas were stable, and its Step5 status was not applicable. Master data is not used to override the Slave freshness stop.

## Non-results

```text
FREQ_ERROR ↔ FREQ_COUNT_BEFORE/AFTER correlation = NOT MEASURED
BRANCH_ID / FLAGS / UPDATE_ID producer frames    = NOT MEASURED
acceptance-margin vs hysteresis classification   = NOT EVALUATED
F4J 30-second observer                            = NOT RUN
Step5 phase lock                                  = NO
```

The next action must be an observer-freshness-only decision; no production-control inference is made from this capture.
