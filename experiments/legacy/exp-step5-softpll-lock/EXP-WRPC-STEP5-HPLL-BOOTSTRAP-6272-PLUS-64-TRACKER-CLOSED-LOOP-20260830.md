# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6272-PLUS-64-TRACKER-CLOSED-LOOP-20260830

## Verdict

```text
STEP4B_COMPLETE = YES
STEP4B_RESULT = PASS
STEP5_BOOTSTRAP_6272 = PASS
STEP5_NORMAL_TRACKER_HANDOFF = PASS
STEP5_CLOSED_LOOP_305S = PASS_WITHOUT_LOCK
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This experiment followed the branch5 instruction to move the bootstrap anchor
from 6336 to 6272 physical A-direction steps while restoring the 64-code
normal tracker. The new anchor produced a large improvement in Helper error,
but the Helper lock gate still did not remain asserted for the required
duration. Step4B is confirmed; Step5 is not complete and this branch is not
eligible to merge into `main`.

## Source and scope

```text
Branch = exp/step5-softpll-lock
Implementation commit = 609231c201d5c29c3a8920029573765c4e8d5bfd
Experiment = EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6272-PLUS-64-TRACKER-CLOSED-LOOP-20260830
```

The only functional change from the previous 6336 + 64 experiment was:

```text
STEP5_BOOTSTRAP_STEPS: 6336 -> 6272
```

The normal tracker remained `HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 64`.
A polarity, PI gains, Helper threshold, lock sample count, DMTD, PTP/PHY,
Main PLL, reset logic, and quantized-residual semantics were unchanged. The
tracker diagnostic remained read-only and used the 64-code quantization rule.

## Build and programming

Both Quartus Prime 17.0 Build 595 builds completed successfully on pain:

```text
Master FITTER = Successful
Slave FITTER = Successful
Master TIMING_CLOSED = NO, worst setup slack = -0.453 ns
Slave TIMING_CLOSED = NO, worst setup slack = -0.283 ns
```

Fresh programming of both boards completed successfully with zero errors and
zero warnings:

```text
Master SOF checksum = 0x30B897E6
Slave SOF checksum = 0x30B0ACE7
Master SOF SHA256 = 817724b0884811c23e52f35131c00df3bdd143e82cf6f872557a11f7bc498644
Slave SOF SHA256 = 1dbf4d5664b87967d0adef130785e8cbcce408dda167ef1677ac05c1b61ee56e
```

## Step4B regression

The gate dashboard before the formal window reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_ALLOWED                = YES
STEP4B_RESULT                 = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

The final dashboard also reported the same Step4B result. During the formal
window, all reset-related deltas remained zero:

```text
BOOT_GENERATION delta      = 0
CPU_RESET_COUNT delta      = 0
WR_CORE_RESET_COUNT delta  = 0
SI_CONFIG_DROP_COUNT delta = 0
```

## Bootstrap and normal tracker evidence

The formal Slave window ran for 305 samples over 309.714 seconds:

```text
BOOTSTRAP_COMPLETED_DELTA = 0
BOOTSTRAP_STARTED = 1
BOOTSTRAP_DONE = 1
BOOTSTRAP_NORMAL_ZERO_BEFORE_DONE = PASS
```

Normal tracker activity was:

```text
TARGET_DELTA = 4562
APPLIED_DELTA = 4672
NORMAL_REQUEST_DELTA = 7927
NORMAL_COMPLETED_DELTA = 7927
BURST_TRIGGER_DELTA = 0
FORCED_PENDING_DELTA = 0
FORCED_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 7927
INITIAL_TARGET_MINUS_APPLIED = 61
FINAL_TARGET_MINUS_APPLIED = -49
QUANTIZED_SETTLED = PASS
TRACKER_PROGRESS = TOWARD_TARGET
NORMAL_TRANSACTION_ACCOUNTING = CHECK_FINE_GRAIN
```

The normal request and completion deltas matched exactly, with no new forced
activity. The final residual was inside the 64-code quantization cell.

Helper statistics over the same window were:

```text
HELPER_ERROR_SAMPLES = 305
HELPER_ERROR_MEAN = -37.544
HELPER_ERROR_RMS = 1110.879
HELPER_ERROR_MAX_ABS = 3113
HELPER_ERROR_FRACTION_ABS_LE_200 = 14.098 percent
HELPER_LOCK_COUNT_MAX = 46080
HELPER_LOCK_COUNT_FINAL = 100
NORMAL_COMPLETED_PER_SECOND = 25.595
WINDOW_SECONDS = 309.714
```

The error distribution improved substantially relative to the 6336 + 64
baseline: RMS fell from `136187.504` to `1110.879`, and the fraction inside
the ±200 threshold rose from `12.131` percent to `14.098` percent. The raw
tracker lock-count statistic reached 46080, while the paired dashboard's
actual lock detector remained below its 10000-sample requirement; the raw
statistic is therefore not treated as proof of lock.

## Step5 result

The final paired Slave dashboard reported:

```text
STEP5_LOCKDET_BEFORE: HELPER locked=0 changed=0 cnt=2576/10000 threshold=200
STEP5_LOCKDET_AFTER:  HELPER locked=0 changed=0 cnt=3180/10000 threshold=200
PSTAT_locked = 0
MAIN enabled = 0
MAIN locked = 0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

Although the 6272 anchor brought the Helper error close to zero for much of
the window, the lock counter did not reach 10000 and the downstream Main and
PSTAT lock states remained inactive. Therefore:

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

Raw logs are stored under:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6272-PLUS-64-TRACKER-CLOSED-LOOP-20260830/
```

Key files:

- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`
- `build_master.log`
- `build_slave.log`
- `dashboard_gate.log`
- `tracker_slave_305s.log`
- `dashboard_after_305s.log`

