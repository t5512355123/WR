# EXP-WRPC-STEP5-HPLL-6212-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-BRACKET-REFINEMENT-600S-20260901

## Purpose

在已通過 Step4B 的 Slave SoftPLL startup 路徑上，將 bootstrap operating point
由 6216 調整至 6212，保持 `code_per_physical_step=128`，並以可信的 preload→toggle
commit、單一 atomic frozen snapshot 進行 600 秒 helper/PI 動態觀測。此輪只改變
bootstrap 設定，不改變 `kp`、`ki`、lane 或 lock gate。

## Configuration

```text
board                 = DE5 [1-11.2]
bootstrap_steps       = 6212
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
HEAD                   = cb097f718b90c3e2ff03a780ac25c1a1107f4f7e
slave SOF SHA-256      = 834405304f4cc74cff52febc604adca3d0e8f14c4e40847cded96cb18f2746b8
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
HELPER_ERROR_MEAN              = 150000.0
HELPER_ERROR_RMS               = 150000.0
HELPER_ERROR_MAX_ABS           = 150000
FRACTION_ABS_ERROR_LE_200      = 0.0
RAW_ERROR_MEAN                 = 753688040.227
RAW_ERROR_MIN                  = 221573622
RAW_ERROR_MAX                  = 900068936
RAW_ERROR_POSITIVE_FRACTION    = 100.0%
UNCLAMPED_BELOW_MIN_SAMPLES    = 600
LOW_RAIL_SAMPLES               = 600
LOW_RAIL_FRACTION              = 100.000%
HIGH_RAIL_SAMPLES              = 0
HIGH_RAIL_FRACTION             = 0.000%
NO_RAIL_FRACTION               = 0.000%
ERROR_BAND_EXIT_EVENTS         = 0
FREQ_ERROR_MEAN               = 153.766666667
FREQ_ERROR_RMS                = 311.604728248
FREQ_ERROR_MAX_ABS            = 564
FREQ_ZERO_CROSSINGS            = 1
RAIL_TO_RAIL_CYCLE_COMPLETE    = 0
DYNAMICS_CANDIDATE             = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT_CANDIDATE
LOW_RAIL_SATURATION            = CONFIRMED
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = CONFIRMED
CAUSALITY_CASE                 = A
```

The observer classified this run as `MEASUREMENT_COHERENCE=PASS`,
`POSITION_ACCOUNTING=PASS`, and `TRANSACTION_ACCOUNTING=PASS`. The helper remained
at the lower output rail for the entire trusted observation window, with no
error-band occupancy and no rail-to-rail cycle.

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
completed bootstrap 6212, and the observer remained coherent without reset,
de-lock, or RX errors. The failure is downstream of startup: the helper never
met the Step5 lock gate and remained at the minimum output rail for all 600
samples.

Compared with the nearby operating points:

```text
6208 / 128   lock max = 0; low rail = 51.333%; no rail = 48.667%
6212 / 128   lock max = 0; low rail = 100.000%; no rail = 0.000%
6216 / 128   lock max = 0; low rail = 87.167%; no rail = 12.833%
6224 / 128   lock max = 0; low rail = 100.000%; no rail = 0.000%
```

This confirms that moving `ki=-1` bootstrap from 6216 down to 6212 does not
produce lock progress. The strict Step5 hard gate remains
`HELPER_LOCK_COUNT_MAX > 0`; no further 6209/6210/6211 bootstrap micro-search
should be inferred from this report without branch5 approval.

## Milestone status

```text
STEP4B_COMPLETE       = YES
STEP4B_REVALIDATED    = YES
KI_REDUCTION_DIRECTION_EFFECTIVE = NO
STEP5_COMPLETE        = NO
MERGE_APPROVED        = NO
```

This report must not be used as merge authorization. The next experiment requires
explicit review by branch5 and should address actuator dynamics rather than
continue bootstrap-only refinement.

## Remote raw evidence

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6212-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-BRACKET-REFINEMENT-600S-20260901-PREFLIGHT.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6212-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-OPERATING-POINT-BRACKET-REFINEMENT-600S-20260901.log
```
