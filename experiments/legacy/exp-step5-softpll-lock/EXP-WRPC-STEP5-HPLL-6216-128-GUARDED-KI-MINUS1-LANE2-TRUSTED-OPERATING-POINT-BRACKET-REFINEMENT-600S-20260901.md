# EXP-WRPC-STEP5-HPLL-6216-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-BRACKET-REFINEMENT-600S-20260901

## Purpose

在已通過 Step4B 的 Slave SoftPLL startup 路徑上，將 bootstrap operating point
由 6224 調整至 6216，保持 `code_per_physical_step=128`，並以可信的 preload→toggle
commit、單一 atomic frozen snapshot 進行 600 秒 helper/PI 動態觀測。此輪只改變
bootstrap 設定，不改變 `kp`、`ki`、lane 或 lock gate。

## Configuration

```text
board                 = DE5 [1-11.2]
bootstrap_steps       = 6216
code_per_physical_step= 128
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
HEAD                   = 21f32546ee4046a72295146336dc60a870e6f35c
slave SOF SHA-256      = d7e7aabac6f738fc13854ce6b9b0efe47d96a73a429249e9c7b4a23fd90aa61f
TIMING_CLOSED          = NO
```

## Trusted preflight

The post-program transient was rejected once, then the required retry passed:

```text
STEP4A_RESULT                  = PASS
STEP4B_ALLOWED                 = YES
STEP4B_RESULT                  = PASS
WB_TRANSPORT_PROTOCOL          = PRELOAD_THEN_TOGGLE_COMMIT
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH        = TRUSTED
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
HELPER_ERROR_MEAN              = 1300755.015
HELPER_ERROR_RMS               = 140046.381117
HELPER_ERROR_MAX_ABS           = 150000
FRACTION_ABS_ERROR_LE_200      = 0.833333333333
RAW_ERROR_MEAN                 = 662591900.362
RAW_ERROR_MIN                  = -3616
RAW_ERROR_MAX                  = 1265829750
RAW_ERROR_POSITIVE_FRACTION    = 94.5%
CLAMPED_BELOW_MIN_SAMPLES      = 523
LOW_RAIL_SAMPLES               = 523
LOW_RAIL_FRACTION              = 87.167%
HIGH_RAIL_SAMPLES              = 0
HIGH_RAIL_FRACTION             = 0.000%
NO_RAIL_FRACTION               = 12.833%
ERROR_BAND_EXIT_EVENTS         = 5
FREQ_ERROR_MEAN               = 321.43
FREQ_ERROR_RMS                = 403.871258365
FREQ_ERROR_MAX_ABS            = 512
FREQ_ZERO_CROSSINGS            = 22
RAIL_TO_RAIL_CYCLE_COMPLETE    = 0
DYNAMICS_CANDIDATE             = UNDERDAMPED_OR_OVERAGGRESSIVE_CANDIDATE
CAUSALITY_CASE                 = B
```

The observer classified this run as `MEASUREMENT_COHERENCE=PASS`,
`POSITION_ACCOUNTING=PASS`, and `TRANSACTION_ACCOUNTING=PASS`. The output reached
the lower bound repeatedly, but not on every sample, so this run is not labelled
as confirmed steady low-rail saturation or confirmed actuator range limit.

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

## Interpretation

The trusted Step4B path is still healthy: the Slave initialized SoftPLL once,
completed bootstrap 6216, and generated normal runtime requests without reset,
de-lock, or RX errors. The failure is downstream of startup: the helper never
met the Step5 lock gate and spent 87.167% of the observation window at the
minimum output rail.

Compared with the nearby operating points:

```text
6208 / 128   lock max = 0; low rail = 51.333%; no rail = 48.667%
6216 / 128   lock max = 0; low rail = 87.167%; no rail = 12.833%
6224 / 128   lock max = 0; low rail = 100.000%; no rail = 0%
```

Thus 6216 refines the upper-side behavior of the currently unresolved operating
region, but it does not satisfy Step5. The strict Step5 hard gate remains
`HELPER_LOCK_COUNT_MAX > 0`.

## Milestone status

```text
STEP4B_COMPLETE       = YES
STEP4B_REVALIDATED    = YES
STEP5_COMPLETE        = NO
MERGE_APPROVED        = NO
```

This report must not be used as merge authorization. The next operating-point
experiment requires explicit review by branch5.

## Remote raw evidence

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6216-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-BRACKET-REFINEMENT-600S-20260901-PREFLIGHT-RETRY2.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6216-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-BRACKET-REFINEMENT-600S-20260901.log
```
