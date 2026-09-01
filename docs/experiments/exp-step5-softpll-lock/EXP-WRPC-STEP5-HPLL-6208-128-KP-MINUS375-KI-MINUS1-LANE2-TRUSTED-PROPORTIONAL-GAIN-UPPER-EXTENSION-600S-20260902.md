# EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS375-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-EXTENSION-600S-20260902

## Verdict

This experiment applied the requested single control change:

```text
kp: -300 -> -375
```

All other Step 5 controls remained fixed:

```text
bootstrap = 6208
code_per_physical_step = 128
ki = -1
shift = 12
bias = 5
threshold = 200
lock_samples = 10000
QSFPA lane = 2
```

The source and observer configuration were correctly applied. Both fresh-program attempts reached a settled upstream gate with Step4B PASS, but neither long-run attempt is accepted as a clean trusted 600-sample verdict:

```text
RUN1 = 599 valid / 1 invalid, rejected because sample 167 had PI_RAW_ERROR mismatch
RUN2 = aborted at sample 158 after RXERR_COUNT increased during the window
```

The valid RUN1 population nevertheless shows clear degradation relative to the previous trusted `kp=-300, ki=-1` run: the controller spent the window on both rails, had zero error-band occupancy, and produced no Helper/Main/PSTAT lock. The hard Step 5 gate remains unmet.

```text
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED = YES
PROPORTIONAL_GAIN_KP_MINUS375_EFFECTIVE = NO
PROPORTIONAL_GAIN_KP_MINUS375_DIRECTION = DEGRADED_ON_VALID_RUN1
TRUSTED_600S_VERDICT = NOT_ACCEPTED
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

Do not merge based on this experiment.

## Source and image provenance

```text
branch = exp/step5-softpll-lock
source/control commit = 8ff3e20
prior control/report baseline = e7e2bb9
observer signed-32-bit baseline = db627a2
FITTER_STATUS = Successful
TIMING_CLOSED = NO
```

The only functional source delta from the previous `kp=-300` point was:

```text
vendor/wrpc-sw/softpll/spll_helper.c
  CONFIG_WR_NODE: s->pi.kp = -375;
  s->pi.ki = -1;
```

The Tcl audit constants and experiment labels were updated to `kp=-375`; transport, frozen-bank, signed arithmetic, and PI checking logic were not changed.

## Fresh-program and trusted preflight

Master and Slave images were freshly built and programmed in the established Slave-first order on both attempts. Programming completed successfully with zero Quartus errors and warnings.

The settled preflight retries passed the upstream gates:

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
```

The first post-program preflight on each attempt showed the known short Slave `WDIAGS_PTP=UNCALIBRATED` startup transient. It was excluded. The settled retries recovered to the full Step4B gate. No functional source change was made in response to that transient.

## RUN1: full window, not accepted because of one invalid frame

Raw log:

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS375-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-EXTENSION-600S-20260902-RUN1.log
```

```text
SAMPLES = 600
VALID_FRAMES = 599
INVALID_FRAMES = 1
WINDOW_SECONDS = 599.000
PI_TRACE_PRESENT = 599
PI_SNAPSHOT_REJECTS = 1
PI_ACCOUNTING_FAILS = 0
PI_OUTPUT_MISMATCH_FAILS = 0
ANTI_WINDUP_VIOLATIONS = 0
```

The single rejected frame was:

```text
sample = 167
PRIMARY_REJECT_REASON = OTHER
FAILED_FIELD = PI_RAW_ERROR
```

All other valid RUN1 samples had coherent PI math and accounting. The transport summary was:

```text
SNAPSHOT_REQ_COUNT = 600
SNAPSHOT_BANK_COMMIT_COUNT = 600
SNAPSHOT_ACK_COUNT = 600
SNAPSHOT_OVERWRITE_COUNT = 0
ACK_TIMEOUT = 0
ACK_MISMATCH = 0
EPOCH_GENERATION_MISMATCH = 0
ATOMIC_SNAPSHOT_TRANSPORT_V3 = PASS
FROZEN_BANK_READ_STABILITY = PASS
```

RUN1 dynamics over the 599 valid frames:

```text
HELPER_ERROR_MEAN = 15776.2933823
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0%
LOW_RAIL_SAMPLES = 331 / 599 = 55.259%
HIGH_RAIL_SAMPLES = 268 / 599 = 44.741%
NO_RAIL_FRACTION = 0.000%
FREQ_ERROR_MEAN = 8.48414023372
FREQ_ERROR_RMS = 256.330806714
FREQ_ERROR_MAX_ABS = 412
FREQ_ZERO_CROSSINGS = 0
RAIL_TO_RAIL_CYCLE_COMPLETE = 0
DYNAMICS_CANDIDATE = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT_CANDIDATE
```

No lock or reset progress was observed:

```text
HELPER_LOCKED_EVER = 0
HELPER_LOCK_COUNT_MAX = 0
MAIN_ENABLED_EVER = 0
MAIN_FREQ_LOCKED_EVER = 0
MAIN_PHASE_LOCKED_EVER = 0
MAIN_LOCKED_EVER = 0
PSTAT_LOCKED_EVER = 0
SPLL_INIT_COUNT_FIRST/FINAL = 1/1
SPLL_DELOCK_COUNT_FIRST/FINAL = 0/0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
RESET_STABLE = PASS
RXERR_DELTA = 0
```

The final applied control state confirmed the requested gain:

```text
KP = -375
KI = -1
TARGET_FINAL = 5
APPLIED_FINAL = 5
HELPER_ERROR_FINAL = 150000
HELPER_OUTPUT_FINAL = 5
PI_INTEGRATOR_BEFORE_FINAL = 56337224
PI_I_NEW_FINAL = 56187224
PI_INTEGRATOR_AFTER_FINAL = 56337224
PI_UNCLAMPED_FINAL = -10
PI_CLAMPED_FINAL = 5
PI_CLAMP_SIDE_FINAL = -1
```

## RUN2: aborted after RXERR increase

Raw log:

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS375-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-EXTENSION-600S-20260902-RUN2.log
```

RUN2 was stopped at sample 158 after the runtime `RXERR_COUNT` increased during the observation window. The run was not used for a trusted verdict. Before stopping:

```text
FRAME_VALID = 1 for observed samples
SNAPSHOT_OVERWRITE_COUNT = 0
ACK_TIMEOUT = 0
ACK_MISMATCH = 0
EPOCH_GENERATION_MISMATCH = 0
HELPER_LOCK_COUNT = 0
MAIN_LOCKED = 0
PSTAT_LOCKED = 0
```

This confirms the same qualitative direction as RUN1—no lock progress—but does not replace a clean 600-sample run.

## Comparison with previous trusted kp=-300 / ki=-1

The previous clean `kp=-300` run was:

```text
HELPER_ERROR_RMS = 100998.451818
FRACTION_ABS_ERROR_LE_200 = 8.0%
LOW_RAIL_FRACTION = 45.333%
NO_RAIL_FRACTION = 54.667%
FREQ_ZERO_CROSSINGS = 81
HELPER_LOCK_COUNT_MAX = 0
```

RUN1 at `kp=-375` was worse on every selected full-window dynamics indicator available from its 599 valid frames:

```text
HELPER_ERROR_RMS:             100998.45 -> 150000.0
FRACTION_ABS_ERROR_LE_200:       8.0%   -> 0.0%
NO_RAIL_FRACTION:               54.667% -> 0.000%
FREQ_ZERO_CROSSINGS:                 81 -> 0
HELPER_LOCK_COUNT_MAX:               0  -> 0
```

The `kp=-375` point therefore does not provide Step 5 progress. It should be treated as a rejected upper-gain extension unless a later clean rerun is explicitly required.

## Evidence files

```text
preflight initial:
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS375-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-EXTENSION-600S-20260902-PREFLIGHT-INITIAL.log

preflight retry1:
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS375-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-EXTENSION-600S-20260902-PREFLIGHT-RETRY1.log

preflight retry2:
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS375-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-EXTENSION-600S-20260902-PREFLIGHT-RETRY2.log

preflight retry3:
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS375-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-EXTENSION-600S-20260902-PREFLIGHT-RETRY3.log
```

The preflight retries show the expected startup transient followed by the trusted Step4B upstream gate. The two long-run logs document why no clean trusted `kp=-375` verdict was declared and why Step 5 remains incomplete.
