# EXP-WRPC-STEP5-HPLL-ABSOLUTE-TARGET-TRACKER-CLOSED-LOOP-20260830

## Verdict

```text
STEP4B = PASS
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The experiment proves that the normal HPLL path can serialize incremental
SI5340 DCO transactions toward a tracked absolute target, but it does not
prove closed-loop convergence.  The Helper never locks, so the branch is not
eligible to merge into `main`.

## Provenance

```text
branch = exp/step5-softpll-lock
tracker implementation commit = 2e36877
board-filter reader commit    = 98d76da
evidence commit               = bb6bb80
date                         = 2026-08-30 (Asia/Taipei)
```

The implementation changed only the normal HPLL path in
`quartus/jtag_runtime_diag/si5340a_controller_dco.v`:

- retain the latest absolute HPLL target;
- initialize the virtual applied code from the WR node helper bias `y_min=5`;
- admit one normal HPLL transaction at a time;
- recompute direction from the latest target;
- advance virtual applied code by one on each successful non-forced HPLL
  transaction.

The forced-burst path, PI parameters, lock thresholds, DMTD, PTP/PHY, and
Main PLL logic were not changed.  A read-only tracker probe was added at
source-probe instance 39; its fields are target, applied, normal request
count, and normal completed count.

## Build and programming

Both fresh Quartus builds completed successfully with Quartus Prime 17.0
Build 595.  Timing remains open:

```text
Master worst setup slack = -0.288 ns
Slave  worst setup slack = -0.391 ns
TIMING_CLOSED = NO
```

The images were programmed with the intended pairing:

```text
Master cable = DE5 [1-11.1]
Slave  cable = DE5 [1-11.2]
programmer result = 0 errors, 0 warnings
```

Image identities are recorded in the raw build-info and programmer logs.

## Step4B regression

After fresh programming and settling, the fixed-SOF dashboard reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_ALLOWED               = YES
STEP4B_RESULT                = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
FAILURE_CLASSIFICATION       = NO_FAILURE_EVIDENCE
```

This is the admissible current evidence for the fixed images.  The earlier
screen showing Step1/Step4 `error` is not used to override this result because
its image/reader/timing provenance is not the same as this saved fixed-SOF
window.

## Tracker evidence

### 30-second immediate Slave window

The Slave-only read-only window showed the tracker becoming active after
startup and then issuing normal transactions without any forced trigger.  At
the end of the window:

```text
TARGET_CODE = 65531
APPLIED_CODE = 29788
TARGET_MINUS_APPLIED = 35743
NORMAL_HPLL_REQUEST_COUNT = 29832
NORMAL_HPLL_COMPLETED_COUNT = 29831
BURST_TRIGGER_COUNT = 0
FORCED_HPLL_PENDING_COUNT = 0
FORCED_HPLL_COMPLETED_COUNT = 0
```

The one-count request/completion difference is the final in-flight
transaction.  This directly demonstrates the single-outstanding normal
transaction behavior and applied-code movement toward the target.

### 300-second fresh-program Slave window

The fresh-program long window provided the stronger negative result:

```text
NORMAL_HPLL_COMPLETED_DELTA = 49216
NORMAL_TRANSACTION_ACCOUNTING = PASS
BURST_TRIGGER_COUNT = 0
FORCED_HPLL_PENDING_COUNT = 0
FORCED_HPLL_COMPLETED_COUNT = 0
```

However, the latest absolute target did not settle.  It changed between the
two bounded helper outputs `65531` and `5` 39 times during the window.  The
applied code repeatedly chased a moving target and did not converge to the
latest target.  Representative end samples were:

```text
sample 295: TARGET=5     APPLIED=4527  TARGET_MINUS_APPLIED=-4522
sample 296: TARGET=5     APPLIED=3422  TARGET_MINUS_APPLIED=-3417
sample 297: TARGET=5     APPLIED=2317  TARGET_MINUS_APPLIED=-2312
sample 298: TARGET=5     APPLIED=1212  TARGET_MINUS_APPLIED=-1207
sample 299: TARGET=5     APPLIED=107   TARGET_MINUS_APPLIED=-102
sample 300: TARGET=65531 APPLIED=605   TARGET_MINUS_APPLIED=64926
```

The normal tracker was therefore active, but the measured control loop did
not settle.  The Helper error alternated between saturated negative and
positive values, rather than approaching zero.

## Step5 lock result

The final dashboard after the 300-second tracker run reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_RESULT                = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
STEP5_RESULT                 = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
PSTAT_locked                 = 0
HELPER locked                = 0
MAIN enabled                 = 0
MAIN locked                  = 0
```

The required Step5 chain

```text
Helper lock -> Main enable -> Main frequency/phase lock -> PSTAT_locked=1
```

was not observed.  Consequently this experiment cannot be called Step5
PASS, and there is no merge approval.

## Raw evidence

All raw evidence is committed under:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-ABSOLUTE-TARGET-TRACKER-CLOSED-LOOP-20260830/
```

Key files:

- `tracker-slave-immediate-30s.log`
- `tracker-slave-120s.log`
- `tracker-slave-300s.log`
- `dashboard-after-settle.log`
- `dashboard-after-tracker-120s.log`
- `dashboard-after-300s.log`
- `build-info-master.txt`
- `build-info-slave.txt`
- `program-master.log`
- `program-slave-fresh-300s.log`
