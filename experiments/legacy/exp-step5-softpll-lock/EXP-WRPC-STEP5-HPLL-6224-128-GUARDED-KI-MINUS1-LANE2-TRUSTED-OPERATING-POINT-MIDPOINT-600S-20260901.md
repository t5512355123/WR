# EXP-WRPC-STEP5-HPLL-6224-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-MIDPOINT-600S-20260901

## Purpose

Test the midpoint of the `6208..6240` operating-point bracket by changing
the Slave bootstrap from `6240` to `6224`, while retaining
`code_per_physical_step=128` and all other control parameters.

This experiment changes only the Slave bootstrap operating point.

## Configuration

```text
branch       = exp/step5-softpll-lock
source HEAD  = 5c0c63c
board        = DE5 [1-11.2]
lane         = QSFPA lane 2
bootstrap    = 6224
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

The Slave image was rebuilt and programmed successfully. Build identity:

```text
GIT_COMMIT    = 5c0c63ce093fe4eb16e8a2fbdf29f1627a66d7f5
SOF_SHA256    = 8c54b8acbf5c131cda6ed8952abe5e150cdf404cba8e99d8dd3226f87e6d5a94
FITTER_STATUS = Successful
TIMING_CLOSED = NO
```

## Preflight

The first post-programming preflight saw the expected transient Slave
`PTP=UNCALIBRATED` state and was not used to start the long run. After the
startup recovery interval, the retry preflight passed:

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

Preflight raw outputs are retained remotely at:

```text
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6224-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-MIDPOINT-600S-20260901-PREFLIGHT.log
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6224-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-MIDPOINT-600S-20260901-PREFLIGHT-RETRY2.log
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
MEASUREMENT_COHERENCE          = PASS
POSITION_ACCOUNTING            = PASS
TRANSACTION_ACCOUNTING         = PASS
```

Trusted transport remained clean for the full window:

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
NO_RAIL_FRACTION                = 0.000%
ERROR_BAND_EXIT_EVENTS          = 0
FREQ_ERROR_ZERO_CROSSINGS       = 1
RAIL_TO_RAIL_CYCLE_COMPLETE     = 0
```

The midpoint did not produce Helper lock and remained at the low rail:

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

Runtime and measurement integrity remained stable:

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
KI_REDUCTION_DIRECTION_EFFECTIVE = NO
STEADY_LOW_RAIL_SATURATION       = CONFIRMED
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = CONFIRMED
CAUSALITY_CASE                   = A
```

The normal tracker did not issue additional movement after the initial
bootstrap in this window:

```text
NORMAL_REQ_DELTA                 = 0
NORMAL_COMPLETED_DELTA           = 0
DCO_STEP_DELTA                   = 0
FORCED_COMPLETED_FINAL           = 6224
BOOTSTRAP_COMPLETED_FINAL        = 6224
```

## Interpretation

The midpoint result narrows the best observed operating region:

```text
metric                         6208/128       6224/128       6240/128
NO_RAIL_FRACTION               48.667%        0.000%         0.000%
LOW_RAIL_FRACTION              51.333%        100.000%       100.000%
FRACTION_ABS_ERROR_LE_200      3.5            0.0            0.0
HELPER_LOCK_COUNT_MAX          0              0              0
```

`6208` remains the best observed point and `6224` is already a steady
low-rail negative result. The operating-point search therefore brackets the
best observed interior behavior between `6208` and `6224`, but the midpoint
does not provide the required lock-progress evidence.

The observer was run in single-snapshot mode. Its compatibility-labelled
double-read counters are not treated as double-read evidence. The result is a
valid runtime negative result, not a diagnostic read failure.

## Milestone status pending branch5 review

```text
STEP4B_COMPLETE                   = YES
STEP4B_REVALIDATED                = YES
MIDPOINT_OPERATING_POINT_EFFECTIVE = NO
OPERATING_POINT_BRACKET           = 6208..6224
STEP5_COMPLETE                    = NO
MERGE_APPROVED                    = NO
```

The complete raw run is retained on the remote host at:

```text
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6224-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-MIDPOINT-600S-20260901.log
```
