# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-TRUSTED-TRANSPORT-LONG-DYNAMICS-1800S-20260901

## Purpose

Execute the branch-5 requested Step5 long-dynamics experiment after the V4
exclusive PI-bank ownership and trusted transport smoke validation.

This run is observability-only. No firmware, RTL, PI, PHY, PTP, lane,
manual-DCO, or programming changes were made for the run.

## Configuration

```text
branch       = exp/step5-softpll-lock
HEAD         = a132d8c
board        = DE5 [1-11.2]
lane         = QSFPA lane 2
bootstrap    = 6176
code_step    = 64
kp           = -150
ki           = -1
shift        = 12
bias         = 5
y_min        = 5
y_max        = 65531
threshold    = 200
lock_samples = 10000
samples      = 1800
sample_gap   = 1000 ms
window       = 1799 s
transport    = trusted preload-then-toggle-commit
snapshot     = one atomic frozen snapshot per sample
```

## Preflight

The fresh preflight completed successfully before the long run:

```text
Master Step1  = PASS
Master Step2  = PASS
Master Step4A = PASS
Slave  Step1  = PASS
Slave  Step2  = PASS
Slave  Step3  = PASS
Slave  Step4B = PASS
WB_TRANSPORT_PROTOCOL                 = PRELOAD_THEN_TOGGLE_COMMIT
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH               = TRUSTED
RXERR delta                            = 0
reset deltas                           = 0
SPLL init stability                    = PASS
```

Preflight raw output:

```text
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-TRUSTED-TRANSPORT-LONG-DYNAMICS-1800S-20260901-PREFLIGHT.log
```

## Long-run result

The full 1800-sample run completed successfully on the DE5. The remote
Quartus/Tcl process exited successfully after 00:50:59.

```text
SAMPLES                         = 1800
VALID_FRAMES                   = 1773
INVALID_FRAMES                 = 27
WINDOW_SECONDS                 = 1799.000
PI_TRACE_FRACTION              = 98.500%
PI_SNAPSHOT_REJECTS            = 27
PI_ACCOUNTING_FAILS            = 0
PI_OUTPUT_MISMATCH_FAILS       = 0
POSITION_ACCOUNTING            = PASS
TRANSACTION_ACCOUNTING         = PASS
MEASUREMENT_COHERENCE           = PASS
```

The 27 invalid frames were fully attributed to `REJECT_OTHER`; they were not
transport timeouts, ACK mismatches, epoch changes, frozen-bank mismatches, or
PI arithmetic failures. The valid samples remained coherent and the trusted
transport counters completed without timeout or overwrite:

```text
SNAPSHOT_REQ_COUNT              = 2000
SNAPSHOT_BANK_COMMIT_COUNT      = 2000
SNAPSHOT_ACK_COUNT               = 2000
SNAPSHOT_OVERWRITE_COUNT        = 0
ACK_TIMEOUT                     = 0
ACK_MISMATCH                    = 0
EPOCH_GENERATION_MISMATCH       = 0
EPOCH_CHANGED_DURING_READ      = 0
RXERR delta                     = 0
```

## Closed-loop evidence

```text
HELPER_LOCKED_EVER              = 0
HELPER_LOCKED_FINAL             = 0
HELPER_LOCK_COUNT_MAX            = 0
MAIN_ENABLED_EVER               = 0
MAIN_FREQ_LOCKED_EVER           = 0
MAIN_PHASE_LOCKED_EVER          = 0
MAIN_LOCKED_EVER                = 0
PSTAT_LOCKED_EVER                = 0
SPLL_INIT_COUNT first/final      = 1 / 1
SPLL_DELOCK_COUNT delta          = 0
BOOT_GENERATION delta            = 0
CPU reset delta                  = 0
WR-core reset delta              = 0
SI_CONFIG drop delta             = 0
```

The controller did not produce a closed-loop lock interval. The helper error
remained at the ±150000 clamp, and the output reached both rails:

```text
HELPER_ERROR_MEAN                = 322571.9120135
HELPER_ERROR_RMS                 = 150000.0
HELPER_ERROR_MAX_ABS             = 150000
FRACTION_ABS_ERROR_LE_200        = 0.0%
LOW_RAIL_SAMPLES                 = 1079 (60.857%)
HIGH_RAIL_SAMPLES                = 694  (39.143%)
NO_RAIL_SAMPLES                  = 0
FREQ_ERROR_ZERO_CROSSINGS        = 11
RAIL_TO_RAIL_CYCLE_COMPLETE      = 0
LOCK_COUNT_MAX/final              = 0 / 0
```

The run therefore does not support the stronger Case-B claim of steady
low-rail saturation. Instead, it shows a rail-to-rail bounded response with
no completed full cycle and no lock evidence:

```text
DYNAMICS_CANDIDATE                = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT_CANDIDATE
LOW_RAIL_SATURATION               = NO
ACTUATOR_RANGE_LIMIT_CONFIRMED   = NO
CAUSALITY_CASE                    = B
KI_REDUCTION_DIRECTION_EFFECTIVE  = INCONCLUSIVE
STEADY_LOW_RAIL_SATURATION        = NO
```

## Milestone decision pending branch-5 review

The required Step5 completion condition is not met: there was no helper/main/
PSTAT lock, let alone continuous lock for 300 seconds. Step4B remains
revalidated by the preflight, but this experiment does not promote Step5.

```text
STEP4B_COMPLETE                   = YES
STEP4B_REVALIDATED                = YES
STEP5_COMPLETE                    = NO
MERGE_APPROVED                    = NO
```

The complete raw run is retained on the remote host at:

```text
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-TRUSTED-TRANSPORT-LONG-DYNAMICS-1800S-20260901.log
```

