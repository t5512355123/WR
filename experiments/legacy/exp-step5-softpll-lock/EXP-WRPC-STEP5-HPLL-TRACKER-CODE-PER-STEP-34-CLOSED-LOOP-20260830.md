# EXP-WRPC-STEP5-HPLL-TRACKER-CODE-PER-STEP-34-CLOSED-LOOP-20260830

## Verdict

```text
STEP4B = PASS
CODE_PER_PHYSICAL_STEP = 34
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The calibrated 34-code normal-tracker mapping was built, programmed, and
tested.  Normal transaction accounting passed in the immediate window, but
the 300-second closed-loop test did not reach Helper lock, Main lock, or
`PSTAT_locked=1`.  The branch is not eligible to merge into `main`.

## Provenance

```text
branch = exp/step5-softpll-lock
implementation commit = 43ca9d0
experiment = EXP-WRPC-STEP5-HPLL-TRACKER-CODE-PER-STEP-34-CLOSED-LOOP
date = 2026-08-30 (Asia/Taipei)
Master cable = DE5 [1-11.1]
Slave cable = DE5 [1-11.2]
```

The only normal-tracker mapping change was:

```text
one successful normal physical FINC/FDEC step
→ virtual applied-code movement of at most 34 codes
```

The update saturates to the latest target and cannot overshoot or wrap.  The
normal tracker was re-enabled in the paired images.  A polarity, PI gains,
lock thresholds, DMTD, PTP/PHY, forced burst path, Main PLL, and reset logic
were not changed in this experiment.

## Build and programming

Both Quartus builds completed successfully with Quartus Prime 17.0 Build 595:

```text
Master FITTER = Successful
Slave  FITTER = Successful
Master worst setup slack = -0.169 ns
Slave  worst setup slack = -0.457 ns
TIMING_CLOSED = NO
```

The intended pair was fresh-programmed successfully:

```text
Master checksum = 0x30B5EA46
Slave  checksum = 0x30B58DDD
programmer result = 0 errors, 0 warnings
```

## Step4B regression

The stable post-test dashboard reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_ALLOWED               = YES
STEP4B_RESULT                = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

Thus the 34-code mapping did not regress Step4B startup or the event chain.

## Immediate tracker window

The Slave-only immediate window showed normal transactions and no forced
activity:

```text
NORMAL_REQUEST_DELTA          = 837
NORMAL_COMPLETED_DELTA        = 837
BURST_TRIGGER_DELTA           = 0
FORCED_PENDING_DELTA          = 0
FORCED_COMPLETED_DELTA        = 0
DCO_STEP_DELTA                = 837
NORMAL_TRANSACTION_ACCOUNTING = PASS
```

At the end of that window, the virtual tracker had reached equality:

```text
TARGET_CODE = 65531
APPLIED_CODE = 65531
TARGET_MINUS_APPLIED = 0
```

This equality is only virtual tracker accounting and is not treated as proof
that the physical DCO reached the correct operating point.

## 300-second closed-loop result

The Slave long window ran for approximately 300 seconds.  After the initial
startup transactions, the tracker remained at the same virtual target and
applied value for the rest of the observation:

```text
initial TARGET_CODE = 65531
initial APPLIED_CODE = 65531
initial NORMAL_HPLL_REQUEST_COUNT = 3185
initial NORMAL_HPLL_COMPLETED_COUNT = 3185

final TARGET_CODE = 65531
final APPLIED_CODE = 65531
final NORMAL_HPLL_REQUEST_COUNT = 3185
final NORMAL_HPLL_COMPLETED_COUNT = 3185

TARGET_DELTA = 0
APPLIED_DELTA = 0
NORMAL_HPLL_COMPLETED_DELTA = 0
BURST_TRIGGER_DELTA = 0
FORCED_HPLL_PENDING_DELTA = 0
FORCED_HPLL_COMPLETED_DELTA = 0
```

The Helper error remained at the observed negative saturated value rather
than entering a convergence region.

## Step5 lock result

The final dashboard reported:

```text
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
HELPER locked = 0
MAIN enabled = 0
MAIN locked = 0
PSTAT_locked = 0
```

The required chain

```text
Helper lock -> Main enable -> Main frequency/phase lock -> PSTAT_locked=1
```

was not observed.  Therefore the 34-code mapping is not a Step5 pass:

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

All raw evidence is committed under:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-TRACKER-CODE-PER-STEP-34-CLOSED-LOOP-20260830/
```

Key files:

- `tracker-slave-immediate.log`
- `tracker-slave-300s.log`
- `dashboard-after-300s.log`
- `build-info-master.txt`
- `build-info-slave.txt`
- `program-master.log`
- `program-slave.log`
