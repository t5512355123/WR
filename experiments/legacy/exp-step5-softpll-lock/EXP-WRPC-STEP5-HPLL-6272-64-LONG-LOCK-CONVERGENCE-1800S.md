# EXP-WRPC-STEP5-HPLL-6272-64-LONG-LOCK-CONVERGENCE-1800S

## Verdict

```text
STEP4B_COMPLETE = YES
STEP4B_RESULT = PASS
STEP5_BOOTSTRAP_6272 = PASS
STEP5_NORMAL_TRACKER_HANDOFF = PASS
STEP5_LONG_LOCK_WINDOW = COMPLETE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The fresh-program gate passed Step 1, Step 2, Step 3, and Step4B on the
Slave. The 1800-second read-only convergence window completed, but the
closed-loop lock chain did not reach a valid stable lock. This branch is not
eligible to merge into `main`.

## Source and scope

```text
Branch = exp/step5-softpll-lock
FPGA/firmware build source = 3773105
Observer source used for this run = b71bc40
Observer semantic hardening after the run = 348c8a5
Experiment = EXP-WRPC-STEP5-HPLL-6272-64-LONG-LOCK-CONVERGENCE-1800S
Board = DE5 [1-11.2]
```

The functional configuration remained the established 6272 physical-step
bootstrap with 64-code normal tracker, unchanged A polarity, `kp=-150`,
`ki=-2`, Helper threshold 200, and Helper lock sample count 10000. The only
firmware change was the read-only WDIAGS mirror refresh cadence from 1 s to
100 ms. The observer performed read-only mailbox and Direct Probe reads.

## Build and programming

Master and Slave firmware/Quartus builds completed successfully. The existing
timing caveat remains:

```text
Master FITTER = Successful
Slave FITTER = Successful
TIMING_CLOSED = NO
```

Fresh programming completed with zero errors and zero warnings:

```text
Master SOF checksum = 0x30B897E6
Slave SOF checksum = 0x30B0ACE7
```

## Step4B gate

The fresh-program gate for the Slave reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_ALLOWED                = YES
STEP4B_RESULT                 = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

The reset counters remained unchanged over the long observation:

```text
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA              = 0
RESET_WR_CORE_DELTA          = 0
RESET_SI_CONFIG_DELTA        = 0
```

Therefore the `Step 1 error` display is not reproduced by the latest fresh
gate; the latest raw dashboard reports `Step 1 pass`. The remaining failure
is not PHY/link or Step4B startup.

## Long convergence observation

The observer collected the requested window:

```text
SAMPLES       = 18000
WINDOW_SECONDS = 1799.900
VALID_FRAMES  = 17558
INVALID_FRAMES = 442
WDIAGS cadence = 100 ms
```

The raw observer summary was:

```text
HELPER_LOCK_COUNT_FINAL = 100
MAIN_ENABLED_FINAL      = 0
MAIN_LOCKED_FINAL       = 0
MAIN_FREQ_LOCKED_FINAL  = 0
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL      = 0
FORCED_ACTIVITY_DELTA   = 0
NORMAL_REQ_DELTA        = 10545
NORMAL_COMPLETED_DELTA  = 10545
DCO_STEP_DELTA          = 10545
BOOTSTRAP_DONE_FINAL    = 1
```

Some raw samples showed `HELPER_LOCKED=1` together with a lock count of zero
or another value below 10000. That combination is not a valid state under
the source-defined `ld_update()` state machine: a valid locked sample must
have `HELPER_LOCKED=1` and `HELPER_LOCK_COUNT=10000`. There were no such
complete pairs in the 18000-sample log. The initial observer summary counted
these torn shadow reads as locks; commit `348c8a5` now rejects them.

The final paired dashboard independently reported:

```text
STEP5_LOCKDET_AFTER: HELPER locked=0 cnt=100/10000
MAIN enabled=0 locked=0 freq=0 phase=0
PSTAT_locked=0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

Thus the long observation proves activity and repeated normal tracker
transactions, but not Helper lock, Main lock, PSTAT lock, or a stable closed
loop. Step5 remains incomplete.

## Raw evidence

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6272-64-LONG-LOCK-CONVERGENCE-1800S/lock_convergence_100ms_1800s.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6272-64-LONG-LOCK-CONVERGENCE-1800S/dashboard_gate.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6272-64-LONG-LOCK-CONVERGENCE-1800S/dashboard_after_1800s.log
```

