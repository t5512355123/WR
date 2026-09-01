# EXP-WRPC-STEP5-HPLL-6208-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-UPPER-BRACKET-600S-20260901

## Purpose

Test the branch5-specified upper operating-point bracket by changing the
Slave bootstrap from `6144` to `6208`, while retaining the tested actuator
mapping `code_per_physical_step=128`.

This experiment changes only the Slave bootstrap operating point. The PI
parameters, lane, PHY/PTP setup, and trusted observer are unchanged.

## Configuration

```text
branch       = exp/step5-softpll-lock
source HEAD  = d91924d
board        = DE5 [1-11.2]
lane         = QSFPA lane 2
bootstrap    = 6208
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

The Slave JTAG image was rebuilt and programmed successfully. Build identity:

```text
GIT_COMMIT    = d91924d87eeb2f304e795df1ff86df8304255e7d
SOF_SHA256    = 2c84f26b3945a4e222aac33e66c3f75ca4e29c3d4803a7f8fe57faadf15afb1d
FITTER_STATUS= Successful
TIMING_CLOSED = NO
```

## Preflight

The first post-programming preflight observed the expected transient Slave
PTP-uncalibrated state and was not used for the long run. After waiting for
startup recovery, the retry preflight passed:

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

The first and retry preflight raw outputs are retained remotely at:

```text
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-UPPER-BRACKET-600S-20260901-PREFLIGHT.log
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-UPPER-BRACKET-600S-20260901-PREFLIGHT-RETRY2.log
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
HELPER_ERROR_MEAN               = 76983.1866667
HELPER_ERROR_RMS                = 107480.886829
HELPER_ERROR_MAX_ABS            = 150000
FRACTION_ABS_ERROR_LE_200       = 3.5
LOW_RAIL_SAMPLES                = 308 (51.333%)
HIGH_RAIL_SAMPLES               = 0   (0.000%)
NO_RAIL_FRACTION                = 48.667%
ERROR_BAND_EXIT_EVENTS          = 20
FREQ_ERROR_ZERO_CROSSINGS       = 75
RAIL_TO_RAIL_CYCLE_COMPLETE     = 0
```

The run briefly entered an interior operating region, but later saturated at
the low rail. No Helper lock accumulated:

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
DYNAMICS_CANDIDATE               = UNDERDAMPED_OR_OVERAGGRESSIVE_CANDIDATE
CAUSALITY_CASE                   = B
```

## Interpretation

The three operating points now form the requested bracket:

```text
metric                         6144/128       6176/128       6208/128
NO_RAIL_FRACTION               0%             14.833%        48.667%
LOW_RAIL_FRACTION              100%           85.167%        51.333%
FRACTION_ABS_ERROR_LE_200      0.0            1.0            3.5
HELPER_LOCK_COUNT_MAX          0              0              0
```

The 6208 setting improves interior occupancy relative to 6176, but it still
does not produce the required lock progress (`HELPER_LOCK_COUNT_MAX > 0`).
Therefore this is not Step5 completion evidence. The observer and transport
evidence are valid; the no-lock result is a genuine runtime result, not a
diagnostic read failure.

The observer was run in single-snapshot mode. Its compatibility-labelled
double-read counters are not treated as evidence of a double-read experiment.

## Milestone status pending branch5 review

```text
STEP4B_COMPLETE                   = YES
STEP4B_REVALIDATED                = YES
OPERATING_POINT_SHIFT_EFFECTIVE   = YES (interior occupancy improved)
STEP5_COMPLETE                    = NO
MERGE_APPROVED                    = NO
```

The complete raw run is retained on the remote host at:

```text
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-UPPER-BRACKET-600S-20260901.log
```
