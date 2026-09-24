# EXP-S5-F4J-HELPER-ACQUISITION-CORRELATION-20260920

## Verdict

```text
SESSION_IMAGE                    = F4J fresh image retained
REPROGRAM                        = NO
SAMPLES                          = 20
GAP_MS                           = 500
SLAVE_HELPER_ACQUISITION         = PASS
SLAVE_HELPER_LOCK_ACQUIRED_HELD  = YES (20/20)
SLAVE_HELPER_LOCK_COUNT           = 1000/1000 (20/20)
SLAVE_HELPER_ERROR_BAND           = PASS (-162..+188, threshold=2000)
SLAVE_DCO_STEP_SERVICE            = ACTIVE (19/20 step events)
SLAVE_DCO_ERROR                   = 0 (20/20)
F4J_ACCEPTANCE_AUDIT              = STILL_NOT_RUN
DIRECT_RUNTIME_FOLLOWUP           = NOT_RUN BY DESIGN
STEP5_RESULT                      = NO
STOP_REASON                       = SAMPLE_20_COMPLETE
```

The bounded capture proves that the Slave Helper acquisition path was active, converged, and held lock during the observation window. It does not prove Main start, F4J producer correlation, or Step5 lock; the advisor explicitly required stopping before any follow-up gate or F4J run.

## Provenance

```text
experiment                         EXP-S5-F4J-HELPER-ACQUISITION-CORRELATION-20260920
branch                             exp/step5-softpll-lock
source/image provenance            F4J image from source commit 63bf952a
prior program/report commit        701416ca
prior Slave SOF SHA256             f70d688bd1e703177e4e59b713f8165d871fe4b3c735888b169ddea9526346a6
prior Master SOF SHA256            7cbe368bab2f94a8e7276cb7d8f066ee386e02f8e072b686a6e2a9ca59b96f1c
command                            quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 20 500
remote start/end                   2026-09-20 00:12:14 / 00:12:43+08:00
raw SHA256                         E06CB484BB403E2417506AE7E5A2DB043A200D49AF4F6B45E968D624AC1E8CA6
raw size                           41268 bytes
```

This experiment intentionally has no new source/build/program stage: the instruction was to keep the freshly programmed F4J image and live session unchanged and perform one read-only correlation capture.

## Slave result (`DE5 [1-11.2]`)

All 20 Slave samples were in the same operating state:

```text
PSTAT                           = 1 in 20/20
LOCK_ENABLE                     = 4 in 20/20
SPLL_STATE                      = 00030006 in 20/20
HELPER_STATE                    = 03E80001 in 20/20
HELPER_LOCKED                   = 1 in 20/20
HELPER_LOCK_COUNT               = 1000 in 20/20
```

The Helper error remained tightly centered around zero:

```text
HELPER_ERROR_SIGNED min         = -162
HELPER_ERROR_SIGNED max         = +188
maximum absolute error          = 188
configured threshold            = 2000
```

The actuator/service path was active:

```text
STEP_DELTA nonzero               = 19/20 samples
STEP_EVENT                       = 1 in 19/20 samples
STEP_DELTA range after baseline  = 575..586
BUSY                             = 1 in 20/20 samples
DCO ERROR                        = 0 in 20/20 samples
HELPER_UPDATE_COUNT              = 0x004513EB -> 0x0045E18B overall
```

The first sample is the correlation baseline (`STEP_DELTA=0`, `STEP_EVENT=0`). The remaining samples show completed DCO steps, not a request permanently stuck at zero progress. `BUSY=1` is an instantaneous sample of a dense request stream and, together with the nonzero completed-step deltas and zero error flag, is not evidence of a DCO deadlock.

## Master reference (`DE5 [1-11.1]`)

The Master is not the target for this Helper acquisition decision. It remained inactive as expected for this Slave-focused observation:

```text
LOCK_ENABLE                     = 0 in 20/20
HELPER_STATE                    = 00060100 in 20/20
HELPER_ERROR_SIGNED             = -150000 in 20/20
STEP_DELTA                      = 0 in 20/20
DCO ERROR                       = 0 in 20/20
```

No Master inference is used for the Slave Helper result.

## Interpretation and boundary

The observed chain is:

```text
fresh F4J image / same session
        ↓
Slave Helper service active
        ↓
Helper error enters and stays inside ±2000
        ↓
Helper lock count = 1000/1000
        ↓
DCO completed steps continue, DCO error = 0
        ↓
HELPER_ACQUISITION = PASS
        ↓
Main/F4J producer audit = not yet evaluated
```

This rules out the advisor's `DCO service regression` case for this window and moves the next boundary to the already-defined next-stage confirmation. It does not authorize that confirmation automatically: the required stop is sample 20, and the next action must come from the advisor.
