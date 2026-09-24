# EXP-WRPC-STEP5-HPLL-TRACKER-CODE-PER-STEP-64-CLOSED-LOOP-20260830

## Verdict

```text
STEP4B = PASS
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The 64-code-per-step normal-HPLL tracker was built and programmed to the
intended Master/Slave pair.  The tracker accounting and forced-path guards
passed, but the 300-second closed-loop acceptance criteria were not met.
The branch is not eligible to merge into `main`.

## Provenance

```text
branch = exp/step5-softpll-lock
implementation commit = 431c826
date = 2026-08-30 (Asia/Taipei)
Master cable = DE5 [1-11.1]
Slave cable = DE5 [1-11.2]
```

This experiment changed only the normal HPLL virtual applied-code update.
Each successful physical FINC/FDEC transaction still increments the physical
step counter by one, while the virtual applied code moves by at most 64
codes toward the latest absolute target and saturates exactly at that target.
The update avoids wraparound and overshoot.  The forced burst path, PI gains,
lock thresholds, DMTD, PTP/PHY, Main PLL, and reset behavior were not changed.

## Build and programming

Both fresh Quartus builds completed successfully with Quartus Prime 17.0
Build 595.  Timing remains open:

```text
Master worst setup slack = -0.221 ns
Slave  worst setup slack = -0.396 ns
TIMING_CLOSED = NO
```

Both images were programmed successfully with 0 errors and 0 warnings.
The saved programming logs record the image checksums:

```text
Master checksum = 0x30B1ED22
Slave  checksum = 0x30A66617
```

## Step4B regression

The dashboard captured after the 300-second Slave tracker window reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_ALLOWED               = YES
STEP4B_RESULT                = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
Step 4B Slave SoftPLL Startup pass
```

This confirms that the 64-code change did not regress the Step4B startup and
event-processing chain.

## Tracker evidence

### Immediate Slave sanity window

The read-only Slave tracker window showed normal transactions with no forced
burst activity:

```text
NORMAL_HPLL_REQUEST_DELTA   = 767
NORMAL_HPLL_COMPLETED_DELTA = 767
BURST_TRIGGER_DELTA         = 0
FORCED_HPLL_PENDING_DELTA   = 0
FORCED_HPLL_COMPLETED_DELTA = 0
TRACKER_PROGRESS            = INCONCLUSIVE
NORMAL_TRANSACTION_ACCOUNTING = PASS
```

The final sanity samples were already saturated at the same target and
applied code:

```text
TARGET_CODE = 65531
APPLIED_CODE = 65531
TARGET_MINUS_APPLIED = 0
```

### 300-second fresh-program Slave window

The long window began with the tracker at the same state and then showed no
additional normal transactions for the remainder of the observation:

```text
initial TARGET_CODE = 65531
initial APPLIED_CODE = 65531
initial NORMAL_HPLL_REQUEST_COUNT = 2177
initial NORMAL_HPLL_COMPLETED_COUNT = 2177

final TARGET_CODE = 65531
final APPLIED_CODE = 65531
final NORMAL_HPLL_REQUEST_COUNT = 2177
final NORMAL_HPLL_COMPLETED_COUNT = 2177

TARGET_DELTA = 0
APPLIED_DELTA = 0
NORMAL_HPLL_COMPLETED_DELTA = 0
BURST_TRIGGER_DELTA = 0
FORCED_HPLL_PENDING_DELTA = 0
FORCED_HPLL_COMPLETED_DELTA = 0
```

The tracker did not exhibit arithmetic wrap or overshoot, but the control
loop did not produce a valid lock progression.  The Helper error remained at
the observed negative saturated value rather than converging toward zero.

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

was not observed during the required 300-second window.  Therefore this is a
Step4B PASS / Step5 NOT COMPLETE result, not a Step5 PASS.

## Raw evidence

All raw evidence is saved under:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-TRACKER-CODE-PER-STEP-64-CLOSED-LOOP-20260830/
```

Key files:

- `tracker-slave-immediate-30s.log`
- `tracker-slave-300s.log`
- `dashboard-after-300s.log`
- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`
- `build_jtag_master.log`
- `build_jtag_slave.log`
- `program-master.log`
- `program-slave.log`
