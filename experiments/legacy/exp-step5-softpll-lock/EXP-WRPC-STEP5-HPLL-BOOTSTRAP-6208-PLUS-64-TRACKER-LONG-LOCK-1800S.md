# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6208-PLUS-64-TRACKER-LONG-LOCK-1800S

## Verdict

```text
STEP4B_COMPLETE = YES
STEP4B_RESULT = PASS
STEP5_BOOTSTRAP_6208 = PASS
STEP5_NORMAL_TRACKER_HANDOFF = PASS (smoke only)
STEP5_LONG_LOCK_WINDOW = COMPLETE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The fresh-program gate passed Step 1, Step 2, Step 3, and Step4B on the
Slave. The 1800-second read-only convergence window completed normally, but
the Helper never reached a valid lock state. Step5 is therefore incomplete
and this branch is not eligible to merge into `main`.

## Source and scope

```text
Branch = exp/step5-softpll-lock
Source commit = 4c02cc5
Experiment = EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6208-PLUS-64-TRACKER-LONG-LOCK-1800S
Board = DE5 [1-11.2]
Bootstrap physical steps = 6208
Normal tracker code per step = 64
Polarity = A
kp = -150
ki = -2
Helper threshold = 200
Helper lock samples = 10000
```

The only functional experiment change from the preceding 6272 run was the
bootstrap setting `6272 -> 6208`. The observer and WDIAGS refresh cadence are
read-only observability support; DMTD/PTP/PHY, Main PLL, reset tree, and the
normal tracker algorithm were not changed in this run.

## Build, programming, and gate

The Slave build and programming completed successfully:

```text
Slave FITTER = Successful
TIMING_CLOSED = NO
Slave SOF checksum = 0x30BA235B
Programming errors = 0
Programming warnings = 0
```

The fresh-program dashboard gate reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_ALLOWED                = YES
STEP4B_RESULT                 = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

The displayed `Step 1 error` was not reproduced by this fresh gate. The
latest raw gate reports `Step 1 pass`; the failure in this experiment is
downstream at Helper lock convergence.

The short smoke observation also showed bootstrap completion and normal
tracker activity before the long window:

```text
BOOTSTRAP_COMPLETED = 6208
BOOTSTRAP_DONE = 1
NORMAL_REQ = 2050
DCO_STEP = 8258
HELPER_LOCKED = 0
HELPER_LOCK_COUNT = 0
HELPER_ERROR_SIGNED = 150000
HELPER_OUTPUT_SIGNED = 5
```

## 1800-second convergence observation

The hardened read-only observer completed the requested window:

```text
SAMPLES = 18000
VALID_FRAMES = 17982
INVALID_FRAMES = 18
WINDOW_SECONDS = 1799.900
WDIAGS cadence = 100 ms
```

The raw observer summary was:

```text
HELPER_LOCK_COUNT_MAX = 0
HELPER_LOCK_COUNT_FINAL = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
FIRST_HELPER_LOCK_SAMPLE = NONE
LOCK_CHANGED_EVENTS = 0

HELPER_ERROR_MEAN = 150000.0
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD = 0.0
HELPER_OUTPUT_RAIL5_SAMPLES = 17982
HELPER_OUTPUT_RAIL5_FRACTION = 100.0
HELPER_ERROR_PLUS150000_SAMPLES = 17982
HELPER_ERROR_PLUS150000_FRACTION = 100.0

MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
SPLL_DELOCK_COUNT_MAX = 0

NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 0
FORCED_ACTIVITY_DELTA = 0
BOOTSTRAP_DONE_FINAL = 1
NORMAL_TRANSACTION_ACCOUNTING = PASS
```

The final paired dashboard independently reported:

```text
spll_helper_state = 0x00000000
spll_helper_limits = 0x271000C8   # lock_samples=10000, threshold=200
spll_helper_error = 0x000249F0    # +150000
spll_helper_output = 0x00000005   # rail 5
spll_main_state = 0x00000000
pstat_locked = 0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

All reset deltas remained zero during the long window:

```text
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

Therefore the 6208 setting did not produce Helper convergence. It reached
bootstrap completion, but the long observation stayed saturated at error
`+150000` and output rail 5, with no valid Helper lock and no downstream Main
or PSTAT lock.

## Merge decision

```text
STEP4B_COMPLETE = YES
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

No merge request is justified from this result. The next experiment must be
selected and explicitly approved by the branch5 reviewer after this report is
published.

## Raw evidence

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6208-PLUS-64-TRACKER-LONG-LOCK-1800S/build_slave.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6208-PLUS-64-TRACKER-LONG-LOCK-1800S/program_slave.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6208-PLUS-64-TRACKER-LONG-LOCK-1800S/dashboard_gate.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6208-PLUS-64-TRACKER-LONG-LOCK-1800S/observer_smoke.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6208-PLUS-64-TRACKER-LONG-LOCK-1800S/lock_convergence_100ms_1800s.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6208-PLUS-64-TRACKER-LONG-LOCK-1800S/dashboard_after_1800s.log
```
