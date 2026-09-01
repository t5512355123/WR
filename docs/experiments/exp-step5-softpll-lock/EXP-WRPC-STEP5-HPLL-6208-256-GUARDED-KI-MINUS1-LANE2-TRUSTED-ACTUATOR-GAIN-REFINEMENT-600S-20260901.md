# EXP-WRPC-STEP5-HPLL-6208-256-GUARDED-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-GAIN-REFINEMENT-600S-20260901

## Purpose

在目前最佳已知 bootstrap `6208` 上，將 actuator mapping 的
`code_per_physical_step` 由 128 調整至 256，保持 `kp`、`ki`、bootstrap、lane
與 lock gate 不變，驗證降低 effective actuator aggressiveness 是否能讓
Helper PLL 累積 lock。

## Configuration

```text
board                 = DE5 [1-11.2]
bootstrap_steps       = 6208
code_per_physical_step= 256
kp                    = -150
ki                    = -1
shift                 = 12
bias                  = 5
y_min                 = 5
y_max                 = 65531
lock_threshold        = 200
lock_samples          = 10000
QSFPA lane             = 2
samples                = 600
sample_gap             = 1000 ms
snapshot_mode          = single atomic frozen snapshot
```

## Build identity

```text
branch                 = exp/step5-softpll-lock
HEAD                   = 85394fc166424f7163551536b6d2f6478472ad72
slave SOF SHA-256      = f2b3bf57fb0cea43d4f44040a98c6a59ead0de8e3fe02e976be2ccbae96e08cf
TIMING_CLOSED          = NO
```

## Trusted preflight

```text
STEP4A_RESULT                  = PASS
STEP4B_ALLOWED                 = YES
STEP4B_RESULT                  = PASS
WB_TRANSPORT_PROTOCOL          = PRELOAD_THEN_TOGGLE_COMMIT
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH        = TRUSTED
DMTD_REF_DECREASE_COUNT        = 0
DMTD_FB_DECREASE_COUNT         = 0
RXERR_DELTA                    = 0
all reset deltas               = 0
SPLL init stable               = YES
```

## 600-second result

```text
SAMPLES                        = 600
VALID_FRAMES                   = 600
INVALID_FRAMES                 = 0
WINDOW_SECONDS                 = 599.000
PI_TRACE_PRESENT               = 600
PI_TRACE_FRACTION              = 100.000%
PI_SNAPSHOT_REJECTS            = 0
PI_ACCOUNTING_FAILS            = 0
PI_OUTPUT_MISMATCH_FAILS       = 0
ANTI_WINDUP_VIOLATIONS         = 0
```

### Atomic snapshot transport

```text
SNAPSHOT_REQ_COUNT             = 600
SNAPSHOT_BANK_COMMIT_COUNT     = 600
SNAPSHOT_ACK_COUNT             = 600
SNAPSHOT_OVERWRITE_COUNT       = 0
ACK_TIMEOUT                    = 0
ACK_MISMATCH                   = 0
EPOCH_GENERATION_MISMATCH      = 0
EPOCH_CHANGED_DURING_READ     = 0
ATOMIC_SNAPSHOT_TRANSPORT_V3   = PASS
```

### Helper/PI dynamics

```text
HELPER_ERROR_SAMPLES           = 600
HELPER_ERROR_MEAN              = 93297.2883333
HELPER_ERROR_RMS               = 118349.839744
HELPER_ERROR_MAX_ABS           = 150000
FRACTION_ABS_ERROR_LE_200      = 1.5
RAW_ERROR_MEAN                 = 153752381.972
RAW_ERROR_MIN                  = -36073
RAW_ERROR_MAX                  = 768440083
RAW_ERROR_POSITIVE_FRACTION    = 81.0%
UNCLAMPED_BELOW_MIN_SAMPLES    = 374
LOW_RAIL_SAMPLES               = 374
LOW_RAIL_FRACTION              = 62.333%
HIGH_RAIL_SAMPLES              = 0
HIGH_RAIL_FRACTION             = 0.000%
NO_RAIL_FRACTION               = 37.667%
ERROR_BAND_EXIT_EVENTS         = 6
FREQ_ERROR_MEAN               = 200.155
FREQ_ERROR_RMS                = 326.4467669972
FREQ_ERROR_MAX_ABS            = 549
FREQ_ZERO_CROSSINGS            = 54
RAIL_TO_RAIL_CYCLE_COMPLETE    = 0
DYNAMICS_CANDIDATE             = UNDERDAMPED_OR_OVERAGGRESSIVE_CANDIDATE
LOW_RAIL_SATURATION            = NO
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = NOT_CONFIRMED
CAUSALITY_CASE                 = B
```

The observer classified this run as `MEASUREMENT_COHERENCE=PASS`,
`POSITION_ACCOUNTING=PASS`, and `TRANSACTION_ACCOUNTING=PASS`. The slower mapping
did create substantial interior activity, but it did not create a sustained lock
window and the output still returned to the lower rail repeatedly.

### Lock and runtime stability

```text
HELPER_LOCKED_EVER             = 0
HELPER_LOCKED_FINAL            = 0
HELPER_LOCK_COUNT_MAX          = 0
HELPER_LOCK_COUNT_FINAL        = 0
MAIN_ENABLED_EVER              = 0
MAIN_FREQ_LOCKED_EVER         = 0
MAIN_PHASE_LOCKED_EVER        = 0
MAIN_LOCKED_EVER              = 0
PSTAT_LOCKED_EVER              = 0
SPLL_INIT_COUNT_FIRST          = 1
SPLL_INIT_COUNT_FINAL          = 1
POST_INITIAL_SPLL_INIT_DELTA   = 0
CLEAR_DACS_COUNT_FIRST         = 1
CLEAR_DACS_COUNT_FINAL         = 1
SPLL_DELOCK_COUNT_DELTA        = 0
RXERR_DELTA                    = 0
RESET_BOOT_GENERATION_DELTA    = 0
RESET_CPU_DELTA                = 0
RESET_WR_CORE_DELTA            = 0
RESET_SI_CONFIG_DELTA          = 0
RESET_STABLE                   = PASS
```

## Comparison with the previous mapping

```text
bootstrap / mapping   LOW_RAIL    NO_RAIL    |error|<=200    LOCK_MAX
6208 / 128             51.333%     48.667%        3.5%          0
6208 / 256             62.333%     37.667%        1.5%          0
```

The 256 mapping therefore changes the transient response but does not improve
the hard lock criterion over the previously tested 128 mapping.

## Interpretation

The trusted Step4B path remains healthy: the Slave initialized SoftPLL once,
completed bootstrap 6208, and the 600-second observer remained coherent without
reset, de-lock, RX errors, or transport faults. The Step5 blocker remains the
first downstream gate: `HELPER_LOCK_COUNT_MAX` never became positive.

This experiment is a valid actuator-dynamics result, not a Step5 pass. Interior
activity alone is insufficient because the required lock counter did not rise.

## Milestone status

```text
STEP4B_COMPLETE       = YES
STEP4B_REVALIDATED    = YES
ACTUATOR_GAIN_256_EFFECTIVE = NO
STEP5_COMPLETE        = NO
MERGE_APPROVED        = NO
```

No merge authorization is implied. The next control change requires explicit
review by branch5.

## Remote raw evidence

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-256-GUARDED-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-GAIN-REFINEMENT-600S-20260901-PREFLIGHT.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-256-GUARDED-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-GAIN-REFINEMENT-600S-20260901.log
```
