# EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS75-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-600S-20260901

## Purpose

Run the branch5-approved proportional-gain experiment at the established
bootstrap operating point. The only intended control change from the prior
6208/128 run is the Slave helper proportional gain:

```text
kp: -150 -> -75
```

The experiment was repeated after correcting the build configuration so that
the hardware PI coefficient, the physical-step mapping, and the read-only
observer expectations all matched.

## Configuration and provenance

```text
branch       = exp/step5-softpll-lock
source HEAD  = e685b8c9cc06a05926da9d2c0b63aad1bd2c47d8
board        = DE5 [1-11.2]
lane         = QSFPA lane 2
bootstrap    = 6208
code_step    = 128
kp           = -75
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

The functional PI gain change is in `92164ec`; the final mapping change is in
`e685b8c`. Both boards were fresh-programmed from the corresponding branch
builds:

```text
Master SOF SHA256 = 019b2937a187436df1f10d485c3ff4ca6fc262923e0fec295dcf6b75be8abf6b
Slave  SOF SHA256 = ef2e66bc7655308ada83f6b98a983d4f618d38c1e94583341a938e66d746c068
FITTER_STATUS     = Successful
TIMING_CLOSED     = NO
```

## Preflight

After the final Slave fresh-program and startup settling, the trusted
preflight passed for both boards:

```text
Master Step1/Step2/Step4A = PASS
Slave  Step1/Step2/Step3/Step4B = PASS
STEP1_REGRESSION          = PASS
STEP2_REGRESSION          = PASS
STEP3_REGRESSION          = PASS
STEP4B_ALLOWED            = YES
STEP4B_RESULT             = PASS
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH   = TRUSTED
```

An early post-program preflight was transiently blocked while the two boards
re-established PTP/link state. It was not used for the long run; the settled
retry above was the gate for this experiment.

## Trusted 600-second result

The complete window finished without transport or snapshot invalidation:

```text
SAMPLES                         = 600
VALID_FRAMES                   = 600
INVALID_FRAMES                 = 0
WINDOW_SECONDS                 = 599.000
PI_TRACE_PRESENT               = 600
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

The raw controller statistics were:

```text
HELPER_ERROR_SAMPLES           = 600
HELPER_ERROR_MEAN              = 137509.3301667
HELPER_ERROR_RMS               = 143619.859481
HELPER_ERROR_MAX_ABS            = 150000
FRACTION_ABS_ERROR_LE_200       = 0.0%
RAW_ERROR_MEAN                  = 762737209.665
RAW_ERROR_MIN                   = -7459
RAW_ERROR_MAX                   = 1343244994
RAW_ERROR_POSITIVE_FRACTION     = 96.0%
UNCLAMPED_BELOW_MIN_SAMPLES     = 550
LOW_RAIL_SAMPLES                = 550 (91.667%)
HIGH_RAIL_SAMPLES               = 0 (0.000%)
NO_RAIL_FRACTION                = 8.333%
ERROR_BAND_EXIT_EVENTS          = 0
FREQ_ERROR_MEAN                 = 349.031666667
FREQ_ERROR_RMS                  = 428.243503551
FREQ_ERROR_MAX_ABS              = 551
FREQ_ERROR_ZERO_CROSSINGS       = 14
RAIL_TO_RAIL_CYCLE_COMPLETE     = 0
DYNAMICS_CANDIDATE              = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT_CANDIDATE
LOW_RAIL_SATURATION             = NO
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = NOT_CONFIRMED
CAUSALITY_CASE                  = B
```

The helper never accumulated lock:

```text
HELPER_LOCKED_EVER              = 0
HELPER_LOCKED_FINAL             = 0
HELPER_LOCK_COUNT_MAX           = 0
HELPER_LOCK_COUNT_FINAL         = 0
MAIN_ENABLED_EVER               = 0
MAIN_FREQ_LOCKED_EVER           = 0
MAIN_PHASE_LOCKED_EVER          = 0
MAIN_LOCKED_EVER                = 0
PSTAT_LOCKED_EVER               = 0
```

Runtime stability remained good:

```text
SPLL_INIT_COUNT first/final     = 1 / 1
POST_INITIAL_SPLL_INIT_DELTA    = 0
CLEAR_DACS_COUNT first/final    = 1 / 1
CLEAR_DACS_DELTA                = 0
SPLL_DELOCK_COUNT first/final   = 0 / 0
BOOTSTRAP_COMPLETED_FINAL       = 6208
BOOTSTRAP_COMPLETED_DELTA       = 0
BOOTSTRAP_DONE_FINAL            = 1
BOOT_GENERATION delta            = 0
CPU reset delta                  = 0
WR-core reset delta              = 0
SI_CONFIG drop delta             = 0
RXERR delta                      = 0
RESET_STABLE                     = PASS
```

## Trusted transport result

```text
SNAPSHOT_REQ_COUNT              = 600
SNAPSHOT_BANK_COMMIT_COUNT      = 600
SNAPSHOT_ACK_COUNT              = 600
SNAPSHOT_OVERWRITE_COUNT        = 0
SNAPSHOT_REQ_DELTA              = 599
SNAPSHOT_BANK_COMMIT_DELTA      = 599
SNAPSHOT_ACK_DELTA              = 599
ACK_TIMEOUT                     = 0
ACK_MISMATCH                    = 0
EPOCH_GENERATION_MISMATCH       = 0
EPOCH_CHANGED_DURING_READ       = 0
ATOMIC_SNAPSHOT_TRANSPORT_V3    = PASS
```

The frozen-bank compatibility audit also reported 600 valid transactions,
600 valid PI math checks, no mismatches, and `FROZEN_BANK_READ_STABILITY=PASS`.

## Comparison with prior 6208/128, kp=-150

```text
metric                         kp=-150          kp=-75
HELPER_ERROR_MEAN              76983.1866667    137509.3301667
HELPER_ERROR_RMS               107480.886829    143619.859481
NO_RAIL_FRACTION               48.667%          8.333%
LOW_RAIL_FRACTION              51.333%          91.667%
FRACTION_ABS_ERROR_LE_200      3.5%             0.0%
FREQ_ERROR_ZERO_CROSSINGS      75               14
HELPER_LOCK_COUNT_MAX          0                0
```

Reducing `kp` to `-75` is therefore effective as a real hardware control
change, but it moves the operating point substantially toward low-rail
saturation and does not create Helper lock. The observer and transport
evidence are valid; the no-lock result is not a diagnostic-read failure.

## Milestone status pending branch5 review

```text
STEP4B_COMPLETE                   = YES
STEP4B_REVALIDATED                = YES
PROPORTIONAL_GAIN_KP_MINUS75_EFFECTIVE = YES (hardware and observer constants match; dynamics changed)
STEP5_COMPLETE                    = NO
MERGE_APPROVED                    = NO
```

The branch must not be merged until branch5 explicitly returns both
`STEP5_COMPLETE=YES` and `MERGE_APPROVED=YES`.

## Evidence

```text
remote preflight log:
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS75-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-600S-20260901-PREFLIGHT.log

remote 600-second log:
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS75-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-600S-20260901.log
```
