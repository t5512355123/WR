# EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS305-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-RECOVERED

## Scope and control

This is the requested Step 5 proportional-gain bracket refinement from `kp=-310` to
`kp=-305`. The firmware change was limited to the WR-node PI proportional gain;
the observer was then aligned to the same expected constant so that its math audit
could validate the new image.

```text
branch = exp/step5-softpll-lock
experiment HEAD = 1bf0362
source/control commit = db45dea
observer-alignment commit = 1bf0362
bootstrap = 6208
code_per_physical_step = 128
kp = -305
ki = -1
shift = 12
bias = 5
threshold = 200
lock_samples = 10000
QSFPA lane = 2
CONTROL_VARIABLE = kp (-310 -> -305)
FITTER_STATUS = Successful
TIMING_CLOSED = NO
```

No other controller variable, actuator mapping, lane, bootstrap value, or lock
criterion was changed. The observer edit only changed its expected PI constant and
experiment labels; it was not a functional firmware change.

## Build, program, and settled preflight

Pain pulled commit `1bf0362`, rebuilt both images, and freshly programmed Slave
first and Master second. Both builds and both programming operations succeeded.
Timing remained open (`TIMING_CLOSED=NO`), as in the preceding experiments.

The first post-program retry was excluded as startup settling because the Slave
reported a transient uncalibrated PTP state. The next settled retry passed:

```text
settled retry3 = PASS
Master Step1/Step2/Step4A = PASS
Slave Step1/Step2/Step3/Step4B = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
Master RXERR_DELTA = 0
Slave RXERR_DELTA = 0
WDIAGS_PTP = valid MASTER/SLAVE state
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
DMTD_REF_DECREASE_COUNT = 0
DMTD_FB_DECREASE_COUNT = 0
```

The two-sample observer smoke test also passed after the observer alignment:

```text
FRAME_VALID = 1 for both samples
PI_CONSTANTS reject = 0
KP = -305
KI = -1
PI_PROP_TERM = -45750000
observer/transport = PASS
```

The earlier `RUN1` attempt is explicitly excluded from this result. It used the
old observer expectation `PI_KP=-310`, so it stopped on `PI_CONSTANTS` rejection
around sample 75 even though the programmed image was `kp=-305`. It is an observer
mismatch, not a hardware or controller result.

## Trusted 600-second Step 5 run

Raw log on pain:

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS305-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-RUN2-OBSERVER-FIXED.log
```

The corrected run completed normally and passed the observation/data-quality
gates:

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

Snapshot transport was also clean:

```text
SNAPSHOT_REQ_COUNT = 602
SNAPSHOT_BANK_COMMIT_COUNT = 602
SNAPSHOT_ACK_COUNT = 602
SNAPSHOT_REQ/BANK_COMMIT/ACK delta = 599/599/599
SNAPSHOT_OVERWRITE_COUNT = 0
ACK_TIMEOUT = 0
ACK_MISMATCH = 0
EPOCH_GENERATION_MISMATCH = 0
EPOCH_CHANGED_DURING_READ = 0
ATOMIC_SNAPSHOT_TRANSPORT_V3 = PASS
FROZEN_BANK_READ_STABILITY = PASS
REJECT_PI_MATH_CONSTANT_FAIL = 0
REJECT_OTHER = 0
```

## kp=-305 dynamics

```text
HELPER_ERROR_SAMPLES = 600
HELPER_ERROR_MEAN = 150000.000
HELPER_ERROR_RMS = 150000.000
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0%
RAW_ERROR_SAMPLES = 600
RAW_ERROR_MEAN = 696387285.165
RAW_ERROR_MIN = 405171026
RAW_ERROR_MAX = 1371579183
RAW_ERROR_POSITIVE_FRACTION = 100.0%
UNCLAMPED_BELOW_MIN_SAMPLES = 600
LOW_RAIL_SAMPLES = 600 / 600 = 100.000%
HIGH_RAIL_SAMPLES = 0 / 600 = 0.000%
NO_RAIL_FRACTION = 0.000%
ERROR_BAND_EXIT_EVENTS = 0
FREQ_ERROR_SAMPLES = 600
FREQ_ERROR_MEAN = 222.185
FREQ_ERROR_RMS = 352.9766134698
FREQ_ERROR_MAX_ABS = 501
FREQ_ZERO_CROSSINGS = 0
RAIL_TO_RAIL_CYCLE_COMPLETE = 0
DYNAMICS_CANDIDATE = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT_CANDIDATE
LOW_RAIL_SATURATION = CONFIRMED
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = CONFIRMED
CAUSALITY_CASE = A
```

The controller stayed runtime-stable but did not enter closed-loop lock:

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
SPLL_INIT_COUNT_FIRST/FINAL = 1/1
POST_INITIAL_SPLL_INIT_DELTA = 0
CLEAR_DACS_FIRST/FINAL = 1/1
CLEAR_DACS_DELTA = 0
SPLL_DELOCK_COUNT_FIRST/FINAL = 0/0
HELPER_EPOCH_RESET_COUNT = 0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
RESET_STABLE = PASS
RXERR_DELTA = 0
```

Final observed control state:

```text
TARGET_FINAL = 5
APPLIED_FINAL = 5
HELPER_ERROR_FINAL = 150000
HELPER_OUTPUT_FINAL = 5
PI_EPOCH_FINAL = 1200
PI_INTEGRATOR_BEFORE_FINAL = 45851877
PI_I_NEW_FINAL = 45701877
PI_INTEGRATOR_AFTER_FINAL = 45701877
PI_UNCLAMPED_FINAL = -7
PI_CLAMPED_FINAL = 5
PI_CLAMP_SIDE_FINAL = -1
RAW_ERROR_FINAL = 1371579183
LD_ERROR_FINAL = 150000
PI_PROP_TERM_FINAL = -45750000
PI_Y_PREROUND_FINAL = -46075
```

## Provisional verdict

The `kp=-305` run is a trusted, complete negative Step 5 result. Step 4B is
revalidated, the PI observer and transport are clean, and the full 600-second
window confirms steady low-rail saturation. The hard Step 5 lock gate remains
unmet because `HELPER_LOCK_COUNT_MAX` is zero.

```text
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED = YES
KP_MINUS305_DYNAMICS_VERDICT = TRUSTED_NO_LOCK
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This report does not authorize a merge. The next action is for 分支5 to review the
latest GitHub record and issue the next single-variable experiment or explicitly
approve Step 5 and merge when its required hard gate is met.
