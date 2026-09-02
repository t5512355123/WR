# EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS302-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-RECOVERED

## Scope and control

This is the requested Step 5 proportional-gain bracket refinement at `kp=-302`,
between the trusted `kp=-300` and `kp=-305` points. The firmware change was
limited to the WR-node PI proportional gain; the read-only observer expectation
and experiment labels were aligned to the same value so the new image could be
audited correctly.

```text
branch = exp/step5-softpll-lock
source/control commit = ad2b6c7
bootstrap = 6208
code_per_physical_step = 128
kp = -302
ki = -1
shift = 12
bias = 5
threshold = 200
lock_samples = 10000
QSFPA lane = 2
CONTROL_VARIABLE = kp (-300 -> -302)
FITTER_STATUS = Successful
TIMING_CLOSED = NO
```

No other controller variable, actuator mapping, lane, bootstrap value, or lock
criterion was changed. The Tcl observer change only updated the expected PI
constant and experiment metadata; it was not a functional firmware change.

## Build, program, and settled preflight

Pain pulled commit `ad2b6c7`, rebuilt both firmware images and both Quartus JTAG
images, then freshly programmed Slave first and Master second.

```text
Slave firmware build = PASS
Master firmware build = PASS
Slave Quartus clean compile = PASS
Master Quartus clean compile = PASS
Slave programming = PASS, checksum 0x30B1A8DF
Master programming = PASS, checksum 0x30B1A900
Slave SOF_SHA256 = d2f3f371071f2146d14b4b824c5995257050fd2df098e992bcf13aedcfb528eb
Master SOF_SHA256 = 3a8226f3a27fbb78aaf7da572137ff377975c83e6e9622ab8c1f5246d454edd1
Slave MIF_SHA256 = f276f1c5563336b834089ac8348694150406d0430fba284ab2cbf41b29a84e47
Master MIF_SHA256 = d2a8b405f8a7478399fed27ef214ff9adab5ddf0dd7817523f558f6f534fbc
Slave worst setup slack = -0.266 ns
Master worst setup slack = -0.050 ns
TIMING_CLOSED = NO
```

Three consecutive settled preflight windows passed:

```text
initial = PASS
retry1 = PASS
retry2 = PASS

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

Raw preflight logs on pain:

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-KP-MINUS302-PREFLIGHT-INITIAL-20260902.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-KP-MINUS302-PREFLIGHT-RETRY1-20260902.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-KP-MINUS302-PREFLIGHT-RETRY2-20260902.log
```

The two-sample observer smoke test passed before the long run:

```text
FRAME_VALID = 1 for both samples
PI_CONSTANTS reject = 0
KP = -302
KI = -1
PI_PROP_TERM = -45300000
observer/transport = PASS
```

## Trusted 600-second Step 5 run

Raw log on pain:

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS302-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-RUN1-OBSERVER-FIXED.log
```

The run completed normally and passed all observation/data-quality gates:

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

Snapshot transport and rejection attribution were clean:

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

## kp=-302 dynamics

```text
HELPER_ERROR_SAMPLES = 600
HELPER_ERROR_MEAN = 150000.000
HELPER_ERROR_RMS = 150000.000
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0%
RAW_ERROR_SAMPLES = 600
RAW_ERROR_MEAN = 874732500.018
RAW_ERROR_MIN = 263772303
RAW_ERROR_MAX = 1529333247
RAW_ERROR_POSITIVE_FRACTION = 100.0%
UNCLAMPED_BELOW_MIN_SAMPLES = 600
LOW_RAIL_SAMPLES = 600 / 600 = 100.000%
HIGH_RAIL_SAMPLES = 0 / 600 = 0.000%
NO_RAIL_FRACTION = 0.000%
ERROR_BAND_EXIT_EVENTS = 0
FREQ_ERROR_SAMPLES = 600
FREQ_ERROR_MEAN = 312.555
FREQ_ERROR_RMS = 404.7599313255
FREQ_ERROR_MAX_ABS = 518
FREQ_ZERO_CROSSINGS = 1
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
MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_EVER = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_EVER = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_EVER = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_EVER = 0
PSTAT_LOCKED_FINAL = 0
SPLL_INIT_COUNT_FIRST/FINAL = 1/1
POST_INITIAL_SPLL_INIT_DELTA = 0
CLEAR_DACS_FIRST/FINAL = 1/1
CLEAR_DACS_DELTA = 0
SPLL_DELOCK_COUNT_FIRST/FINAL = 0/0
HELPER_EPOCH_RESET_COUNT = 0
NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 0
FORCED_COMPLETED_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 6208
BOOTSTRAP_COMPLETED_DELTA = 0
BOOTSTRAP_DONE_FINAL = 1
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
PI_INTEGRATOR_BEFORE_FINAL = 45390290
PI_I_NEW_FINAL = 45240290
PI_INTEGRATOR_AFTER_FINAL = 45390290
PI_UNCLAMPED_FINAL = -10
PI_CLAMPED_FINAL = 5
PI_CLAMP_SIDE_FINAL = -1
RAW_ERROR_FINAL = 1491505691
LD_ERROR_FINAL = 150000
PI_PROP_TERM_FINAL = -45300000
PI_Y_PREROUND_FINAL = -57662
```

The trusted bracket now shows a sharp transition between the current best
`kp=-300` dynamics and the `kp=-302` low-rail collapse. The latter did not cross
the first Step 5 lock gate.

## Provisional verdict

This is a trusted, complete negative Step 5 result. Step 4B was revalidated on
three settled preflight windows, the observer and transport were clean for all
600 samples, and the controller remained reset-stable. However, the full window
was 100% low rail and `HELPER_LOCK_COUNT_MAX` stayed zero.

```text
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED = YES
KP_MINUS302_DYNAMICS_VERDICT = TRUSTED_NO_LOCK
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This report does not authorize a merge. The next action is for 分支5 to review
the latest GitHub record and specify the next single-variable experiment. Merge
must remain blocked until 分支5 explicitly returns both `STEP5_COMPLETE=YES` and
`MERGE_APPROVED=YES`.
