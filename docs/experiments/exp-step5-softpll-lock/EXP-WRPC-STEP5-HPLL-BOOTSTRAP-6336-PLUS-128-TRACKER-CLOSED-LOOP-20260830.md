# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6336-PLUS-128-TRACKER-CLOSED-LOOP-20260830

## Verdict

```text
STEP4B_COMPLETE = YES
STEP4B_RESULT = PASS
STEP5_BOOTSTRAP_6336 = PASS
STEP5_NORMAL_TRACKER_HANDOFF = PASS
STEP5_CLOSED_LOOP_305S = PASS_WITHOUT_LOCK
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This experiment kept the branch5-approved 6336-step startup bootstrap and
changed only the Slave normal tracker mapping from 64 to 128 DCO codes per
physical step. The bootstrap and normal tracker accounting remained valid,
but the Helper did not obtain sustained lock. Step4B remains confirmed; Step5
is not complete and this branch is not eligible to merge into `main`.

## Source and scope

```text
Branch = exp/step5-softpll-lock
Source commit = 28e603882e7cd1b2a815faa92db9437ea6e52fe3
Experiment = EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6336-PLUS-128-TRACKER-CLOSED-LOOP-20260830
```

The only functional change was the Slave instance generic:

```text
HPLL_TRACKER_CODE_PER_PHYSICAL_STEP: 64 -> 128
```

The read-only tracker diagnostic was updated to use 128 for quantization
checks and to identify this experiment. The 6336 physical-step bootstrap,
A polarity, PI gains, Helper threshold, lock sample count, DMTD, PTP/PHY,
Main PLL, reset logic, and quantized-residual tracker semantics were
preserved.

## Build and programming

Both Quartus Prime 17.0 Build 595 builds completed successfully on pain:

```text
Master FITTER = Successful
Slave FITTER = Successful
Master TIMING_CLOSED = NO, worst setup slack = -0.453 ns
Slave TIMING_CLOSED = NO, worst setup slack = -0.365 ns
```

Fresh programming of both boards completed successfully with zero errors and
zero warnings:

```text
Master SOF checksum = 0x30B897E6
Slave SOF checksum = 0x30B88385
Master SOF SHA256 = ad9ba58b3a6230a0260872ac285c221ff79c9e1a83e78c98d026ba098183fa03
Slave SOF SHA256 = fc1123893bc9fd531c4ff876c453b28c7f00778dc46eee96c2e55e2f22210ecc
```

## Step4B regression

The valid final Slave dashboard reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_ALLOWED                = YES
STEP4B_RESULT                 = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

During the formal tracker window, the reset-related deltas remained zero:

```text
BOOT_GENERATION delta      = 0
CPU_RESET_COUNT delta      = 0
WR_CORE_RESET_COUNT delta  = 0
SI_CONFIG_DROP_COUNT delta = 0
```

Thus the 128-code experiment did not regress Step4B or introduce a reset
event.

## Bootstrap and normal tracker evidence

The formal Slave window ran for 305 samples over 309.722 seconds:

```text
BOOTSTRAP_COMPLETED_DELTA = 0
BOOTSTRAP_STARTED = 1
BOOTSTRAP_DONE = 1
BOOTSTRAP_NORMAL_ZERO_BEFORE_DONE = PASS
```

Normal tracker activity was:

```text
TARGET_DELTA = 11727
APPLIED_DELTA = 11648
NORMAL_REQUEST_DELTA = 6659
NORMAL_COMPLETED_DELTA = 6659
BURST_TRIGGER_DELTA = 0
FORCED_PENDING_DELTA = 0
FORCED_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 6659
INITIAL_TARGET_MINUS_APPLIED = 0
FINAL_TARGET_MINUS_APPLIED = 79
QUANTIZED_SETTLED = PASS
TRACKER_PROGRESS = INCONCLUSIVE
NORMAL_TRANSACTION_ACCOUNTING = CHECK_FINE_GRAIN
```

Normal request and completion deltas matched exactly, and no new forced
activity occurred. The final residual remained within the 128-code
quantization cell (`79 < 128`); the overall tracker-progress field is
`INCONCLUSIVE` because the target continued moving during the observation
window.

The Helper statistics over the same window were:

```text
HELPER_ERROR_SAMPLES = 305
HELPER_ERROR_MEAN = 45620.213
HELPER_ERROR_RMS = 287998.717
HELPER_ERROR_MAX_ABS = 3055772
HELPER_ERROR_FRACTION_ABS_LE_200 = 5.574 percent
HELPER_LOCK_COUNT_MAX = 704
HELPER_LOCK_COUNT_FINAL = 100
NORMAL_COMPLETED_PER_SECOND = 21.500
WINDOW_SECONDS = 309.722
```

Compared with the 64-code result, 128 reduced the normal completion rate and
still preserved exact request/completion accounting, but its lock-count peak
fell from 3438 to 704, the in-threshold fraction fell from 12.131 percent to
5.574 percent, and RMS error increased from 136187.504 to 287998.717. It
therefore did not provide the expected damping improvement.

## Step5 result

The final Slave dashboard reported:

```text
STEP5_LOCKDET_BEFORE: HELPER locked=0 changed=0 cnt=100/10000 threshold=200
STEP5_LOCKDET_AFTER:  HELPER locked=0 changed=0 cnt=100/10000 threshold=200
PSTAT_locked = 0
MAIN enabled = 0
MAIN locked = 0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

Therefore 128-code tracking did not establish the sustained Helper lock
required by Step5. The correct milestone conclusion is:

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

Raw logs are stored under:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6336-PLUS-128-TRACKER-CLOSED-LOOP-20260830/
```

Key files:

- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`
- `build_master.log`
- `build_slave.log`
- `dashboard_gate.log`
- `tracker_slave_305s.log`
- `dashboard_after_305s.log`

