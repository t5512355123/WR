# EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS319-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902

## Verdict

This experiment applied the single control change requested by branch5:

```text
kp: -300 -> -319
```

All other controls were held fixed:

```text
bootstrap = 6208
code_per_physical_step = 128
ki = -1
shift = 12
bias = 5
threshold = 200
lock_samples = 10000
QSFPA lane = 2
observer baseline = db627a2
```

The run was a clean trusted 600-sample window. Step 5 lock was not reached; the helper remained at the low actuator rail for the full observation window.

```text
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED = YES
PROPORTIONAL_GAIN_KP_MINUS319_EFFECTIVE = NO
PROPORTIONAL_GAIN_KP_MINUS319_DIRECTION = LOW_RAIL_SATURATION
TRUSTED_600S_VERDICT = ACCEPTED
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

Do not merge based on this experiment.

## Source and image provenance

```text
branch = exp/step5-softpll-lock
source/control commit = b5ad140
report commit = this report commit
observer signed-32-bit baseline = db627a2
FITTER_STATUS = Successful
TIMING_CLOSED = NO
```

The only functional source delta from the prior `kp=-300` point was:

```text
vendor/wrpc-sw/softpll/spll_helper.c
  CONFIG_WR_NODE: s->pi.kp = -319;
  s->pi.ki = -1;
```

The Tcl audit constants and experiment labels were updated to `kp=-319`. No transport, frozen-bank, signed arithmetic, or PI checker logic was changed.

## Fresh-program and trusted preflight

Master and Slave images were freshly built and programmed in the established Slave-first order. Both programming operations completed successfully with zero Quartus errors and warnings.

The first post-program preflight showed the known short Slave `WDIAGS_PTP=UNCALIBRATED` startup transient and was excluded. Settled retry1 passed the complete upstream gate:

```text
Master Step1/Step2/Step4A = PASS
Slave Step1/Step2/Step3/Step4B = PASS
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
WDIAGS_RXERR delta = 0
```

## Trusted 600-second result

Raw log:

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS319-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-RUN1.log
```

```text
SAMPLES = 600
VALID_FRAMES = 600
INVALID_FRAMES = 0
WINDOW_SECONDS = 599.000
PI_TRACE_PRESENT = 600
PI_TRACE_FRACTION = 100.000%
PI_SNAPSHOT_REJECTS = 0
PI_ACCOUNTING_FAILS = 0
PI_OUTPUT_MISMATCH_FAILS = 0
ANTI_WINDUP_VIOLATIONS = 0
POSITION_CONTEXT_FAILS = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
TRANSACTION_ACCOUNTING = PASS
```

Transport and frozen-bank checks were clean:

```text
SNAPSHOT_REQ_COUNT = 600
SNAPSHOT_BANK_COMMIT_COUNT = 600
SNAPSHOT_ACK_COUNT = 600
SNAPSHOT_OVERWRITE_COUNT = 0
ACK_TIMEOUT = 0
ACK_MISMATCH = 0
EPOCH_GENERATION_MISMATCH = 0
EPOCH_CHANGED_DURING_READ = 0
ATOMIC_SNAPSHOT_TRANSPORT_V3 = PASS
FROZEN_BANK_READ_STABILITY = PASS
REJECT_PI_MATH_RAW_ERROR_FAIL = 0
REJECT_OTHER = 0
```

## Dynamics

```text
HELPER_ERROR_MEAN = 150000.000000
HELPER_ERROR_RMS = 150000.000000
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0%
RAW_ERROR_MEAN = 250230703.417
RAW_ERROR_MIN = 1126599
RAW_ERROR_MAX = 642147241
RAW_ERROR_POSITIVE_FRACTION = 100.0%
UNCLAMPED_BELOW_MIN_SAMPLES = 600
LOW_RAIL_SAMPLES = 600 / 600 = 100.000%
HIGH_RAIL_SAMPLES = 0 / 600 = 0.000%
NO_RAIL_FRACTION = 0.000%
ERROR_BAND_EXIT_EVENTS = 0
FREQ_ERROR_MEAN = 74.8833333333
FREQ_ERROR_RMS = 281.594756106
FREQ_ERROR_MAX_ABS = 398
FREQ_ZERO_CROSSINGS = 0
RAIL_TO_RAIL_CYCLE_COMPLETE = 0
DYNAMICS_CANDIDATE = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT_CANDIDATE
LOW_RAIL_SATURATION = CONFIRMED
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = CONFIRMED
CAUSALITY_CASE = A
```

The controller remained at the low rail. The requested constants were present in the captured PI state:

```text
KP = -319
KI = -1
TARGET_FINAL = 5
APPLIED_FINAL = 5
HELPER_ERROR_FINAL = 150000
HELPER_OUTPUT_FINAL = 5
PI_INTEGRATOR_BEFORE_FINAL = 47927978
PI_I_NEW_FINAL = 47777978
PI_INTEGRATOR_AFTER_FINAL = 47927978
PI_UNCLAMPED_FINAL = -13
PI_CLAMPED_FINAL = 5
PI_CLAMP_SIDE_FINAL = -1
RAW_ERROR_FINAL = 642147241
```

## Lock and runtime stability

No Helper/Main/PSTAT lock progress occurred:

```text
HELPER_LOCKED_EVER = 0
HELPER_LOCKED_FINAL = 0
HELPER_LOCK_COUNT_MAX = 0
HELPER_LOCK_COUNT_FINAL = 0
MAIN_ENABLED_EVER = 0
MAIN_FREQ_LOCKED_EVER = 0
MAIN_PHASE_LOCKED_EVER = 0
MAIN_LOCKED_EVER = 0
PSTAT_LOCKED_EVER = 0
PSTAT_LOCKED_FINAL = 0
```

Runtime remained stable:

```text
SPLL_INIT_COUNT_FIRST/FINAL = 1/1
POST_INITIAL_SPLL_INIT_DELTA = 0
CLEAR_DACS_DELTA = 0
SPLL_DELOCK_COUNT_FIRST/FINAL = 0/0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
RESET_STABLE = PASS
RXERR_DELTA = 0
```

The Step 5 hard condition remains unmet:

```text
HELPER_LOCK_COUNT_MAX > 0   # not satisfied; observed 0
```

Therefore this is a valid negative control result and not a Step 5 completion.
