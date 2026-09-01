# EXP-WRPC-STEP5-HPLL-6144-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-600S-20260901

## Purpose

Test the branch5-specified operating-point shift from bootstrap `6176` to
`6144`, while retaining the already tested actuator mapping
`code_per_physical_step=128`.

This experiment changes only the Slave bootstrap operating point. The PI
parameters, actuator mapping, lane, PHY/PTP setup, and trusted observer are
unchanged.

## Configuration

```text
branch       = exp/step5-softpll-lock
source HEAD  = 249e228
board        = DE5 [1-11.2]
lane         = QSFPA lane 2
bootstrap    = 6144
code_step    = 128
kp           = -150
ki           = -1
shift        = 12
bias         = 5
y_min        = 5
y_max        = 65531
threshold    = 200
lock_samples = 10000
samples      = 600
sample_gap   = 1000 ms
window       = 599 s
transport    = trusted preload-then-toggle-commit
snapshot     = one atomic frozen snapshot per sample
```

The Slave JTAG image was rebuilt from `249e228` and programmed successfully.
The image reports `FORCED_COMPLETED=6144` and `BOOTSTRAP_COMPLETED=6144`.

## Preflight

The first post-programming preflight saw the expected transient Slave
`PTP=UNCALIBRATED` state, so the long run was not started. After an additional
60 seconds, the retry preflight passed:

```text
Master Step1/Step2/Step4A = PASS
Slave  Step1/Step2/Step3/Step4B = PASS
STEP4B_ALLOWED                    = YES
STEP4B_RESULT                     = PASS
WB_TRANSPORT_PROTOCOL             = PRELOAD_THEN_TOGGLE_COMMIT
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH           = TRUSTED
RXERR delta                       = 0
reset deltas                      = 0
SPLL init stability                = PASS
```

Preflight raw outputs:

```text
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6144-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-600S-20260901-PREFLIGHT.log
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6144-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-600S-20260901-PREFLIGHT-RETRY2.log
```

## Long-run result

The complete trusted 600-sample run finished successfully. All frames were
valid and coherent:

```text
SAMPLES                         = 600
VALID_FRAMES                   = 600
INVALID_FRAMES                 = 0
WINDOW_SECONDS                 = 599.000
PI_TRACE_FRACTION              = 100.000%
PI_SNAPSHOT_REJECTS            = 0
PI_ACCOUNTING_FAILS            = 0
PI_OUTPUT_MISMATCH_FAILS       = 0
ANTI_WINDUP_VIOLATIONS         = 0
POSITION_CONTEXT_FAILS         = 0
MEASUREMENT_COHERENCE           = PASS
POSITION_ACCOUNTING             = PASS
TRANSACTION_ACCOUNTING          = PASS
```

The trusted transport remained clean:

```text
SNAPSHOT_REQ_COUNT              = 600
SNAPSHOT_BANK_COMMIT_COUNT      = 600
SNAPSHOT_ACK_COUNT              = 600
SNAPSHOT_OVERWRITE_COUNT        = 0
ACK_TIMEOUT                     = 0
ACK_MISMATCH                    = 0
EPOCH_GENERATION_MISMATCH       = 0
EPOCH_CHANGED_DURING_READ      = 0
RXERR delta                     = 0
ATOMIC_SNAPSHOT_TRANSPORT_V3    = PASS
```

## Operating-point and lock evidence

```text
HELPER_ERROR_MEAN               = 150000.0
HELPER_ERROR_RMS                = 150000.0
HELPER_ERROR_MAX_ABS            = 150000
FRACTION_ABS_ERROR_LE_200       = 0.0
LOW_RAIL_SAMPLES                = 600 (100.000%)
HIGH_RAIL_SAMPLES               = 0   (0.000%)
NO_RAIL_SAMPLES                 = 0   (0.000%)
ERROR_BAND_EXIT_EVENTS          = 0
FREQ_ERROR_ZERO_CROSSINGS       = 1
RAIL_TO_RAIL_CYCLE_COMPLETE     = 0
```

The operating-point shift did not produce any Helper lock progress:

```text
HELPER_LOCK_COUNT_MAX            = 0
HELPER_LOCK_COUNT_FINAL          = 0
HELPER_LOCKED_EVER               = 0
HELPER_LOCKED_FINAL              = 0
MAIN_ENABLED_EVER                = 0
MAIN_FREQ_LOCKED_EVER            = 0
MAIN_PHASE_LOCKED_EVER           = 0
MAIN_LOCKED_EVER                 = 0
PSTAT_LOCKED_EVER                = 0
PSTAT_LOCKED_FINAL               = 0
```

The runtime remained stable:

```text
SPLL_INIT_COUNT first/final      = 1 / 1
SPLL_DELOCK_COUNT first/final    = 0 / 0
SPLL_INIT_DELTA                  = 0
SPLL_DELOCK_COUNT_DELTA          = 0
BOOT_GENERATION delta            = 0
CPU reset delta                  = 0
WR-core reset delta              = 0
SI_CONFIG drop delta             = 0
RESET_STABLE                     = PASS
```

## Interpretation

Relative to the `6176/128` baseline, this shift worsened the response:

```text
metric                         6176/128       6144/128
NO_RAIL_FRACTION               14.833%        0%
LOW_RAIL_FRACTION              85.167%        100%
FRACTION_ABS_ERROR_LE_200      1.0            0.0
HELPER_LOCK_COUNT_MAX          0              0
```

Branch5 acceptance therefore fails on the required lock-progress condition
and on all direction-of-improvement conditions:

```text
HELPER_LOCK_COUNT_MAX > 0         = NO
FRACTION_ABS_ERROR_LE_200 > 1.0   = NO
NO_RAIL_FRACTION > 14.833%        = NO
LOW_RAIL_FRACTION < 85.167%       = NO
```

The observer and transport evidence are valid; this is a genuine runtime
operating-point result, not a diagnostic read failure.

## Milestone status pending branch5 review

```text
STEP4B_COMPLETE                   = YES
STEP4B_REVALIDATED                = YES
OPERATING_POINT_SHIFT_EFFECTIVE   = NO
STEP5_COMPLETE                    = NO
MERGE_APPROVED                    = NO
```

The complete raw run is retained on the remote host at:

```text
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6144-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-600S-20260901.log
```

