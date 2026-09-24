# EXP-WRPC-STEP5-HPLL-6208-64-WRPC-LOCKING-ENABLE-IDEMPOTENT-GUARD

Date: 2026-08-30 (Asia/Taipei)
Branch: `exp/step5-softpll-lock`
Source commit: `fe858bd` (`fix: make WR locking enable idempotent`)

## Objective

Apply the branch5-approved minimal fix for the confirmed repeated
`WRPC_LOCKING_ENABLE` re-initialization. The fix must preserve the first
Slave initialization while preventing a repeated `spll_init()` during the
same active Slave locking session.

## Functional change

Only `vendor/wrpc-sw/ppsi/arch-wrpc/wrpc-spll.c` was changed functionally.
After the existing grand-master early return, `wrpc_spll_locking_enable()` now
returns after re-enabling the phase tracker when all of these are true:

```text
softpll.mode == SPLL_MODE_SLAVE
timingMode == WRH_TM_BOUNDARY_CLOCK
softpll.seq_state != SEQ_DISABLED
```

Otherwise it keeps the original initialization path, including the tagged
`spll_init(SPLL_MODE_SLAVE, ...)` call and T24P initialization. No PI gain,
bootstrap, DMTD, PTP/PHY, tracker mapping, or reset-tree setting was changed.

The observer was extended only to report the existing
`WRPC_LOCK_ENABLE_COUNT` register (`0x00100A9C`) and derive its observation-
window delta beside `SPLL_INIT_COUNT`.

## Build and programming

Both clean Quartus builds completed successfully from `fe858bd` on pain.
Timing closure remains the known separate caveat (`TIMING_CLOSED=NO`).

```text
Slave:
  GIT_COMMIT=fe858bdf994c0eaf6ad4d73c81c0c8f0005b3b63
  MIF_SHA256=3dfdcbff86a0f3352b963681dba58f625b4b63850a0d2a672f53f7acfc11cf95
  SOF_SHA256=734151fc57976db50c720a4954d2b01fed3ced774cca4e7cc631555c6d198414
  COMPILE_RESULT=Full Compilation was successful

Master:
  GIT_COMMIT=fe858bdf994c0eaf6ad4d73c81c0c8f0005b3b63
  MIF_SHA256=4070098a9b26ffafbb82115d3ace3de3a8ef78365a5a551409db7c297df9616a
  SOF_SHA256=f3c7980c1dc546380bde064df29b99ddc84bef1eceb7aff9c8c2c0e2e5ee9c79
  COMPILE_RESULT=Full Compilation was successful
```

Fresh programming of both boards succeeded with zero errors and zero
warnings. The preserved logs are:

```text
artifacts/EXP-WRPC-STEP5-HPLL-6208-64-WRPC-LOCKING-ENABLE-IDEMPOTENT-GUARD/raw-20260830/program-jtag-slave.log
artifacts/EXP-WRPC-STEP5-HPLL-6208-64-WRPC-LOCKING-ENABLE-IDEMPOTENT-GUARD/raw-20260830/program-jtag-master.log
```

## 1800-sample guard smoke audit

The valid observer run was started after the fresh pair programming and
completed successfully:

```text
artifacts/EXP-WRPC-STEP5-HPLL-6208-64-WRPC-LOCKING-ENABLE-IDEMPOTENT-GUARD/raw-20260830/reinit-guard-smoke-1800samples.log
```

Key final summary:

```text
SAMPLES=1800
COHERENT_MEASUREMENT_SNAPSHOTS=1800
MEASUREMENT_ACCOUNTING_FAILS=0
ACCOUNTING_REJECTED=22

SPLL_INIT_COUNT_FIRST=1
SPLL_INIT_COUNT_FINAL=1
SPLL_INIT_COUNT_DELTA=0
CLEAR_DACS_COUNT_FIRST=1
CLEAR_DACS_COUNT_FINAL=1

LOCK_ENABLE_COUNT_FIRST=4
LOCK_ENABLE_COUNT_FINAL=4
LOCK_ENABLE_COUNT_DELTA=0
REDUNDANT_LOCK_ENABLE_CALLS=0

HELPER_EPOCH_OR_UPDATE_RESET_ALIGNED=0
EXACTLY_ONE_REASON_CHANGED=0
SPLL_REINIT_DURING_LOCK_ATTEMPT=NOT_CONFIRMED

RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
RESET_STABLE=PASS
MEASUREMENT_COHERENCE=PASS
```

The observer started with `LOCK_ENABLE_COUNT=4` but only one
`WRPC_LOCKING_ENABLE`-attributed `spll_init()` already recorded. This is
consistent with three redundant enable entries having been skipped before the
first observer snapshot. During the complete 1800-sample observation window,
neither the enable count nor the init count increased, and no Helper epoch or
update reset aligned with an init event. The run also kept all reset deltas at
zero.

The observer emitted 24 unaligned candidate init observations internally, but
the raw register stream and final counters show no actual init-count increase:
`SPLL_INIT_COUNT` remained 1, `SPLL_INIT_COUNT_DELTA=0`, and
`HELPER_EPOCH_OR_UPDATE_RESET_ALIGNED=0`. Those unaligned candidates are not
used as re-init evidence.

## Result

The idempotent guard passed its direct objective: repeated lock-enable entry
does not cause a second `spll_init()` or reset the Helper accumulation during
the observed session. This addresses the confirmed re-init cause.

It did not complete Step 5. At the end of the smoke run:

```text
HELPER_LOCKED=0
MAIN_ENABLED=0
MAIN_LOCKED=0
PSTAT_LOCKED=1
```

The smoke run therefore proves the guard behavior, not a stable closed-loop
lock. A long run is only a Step 5 pass if the full chain reaches and maintains
Helper lock, Main lock, and `PSTAT_locked=1` for at least 300 seconds with no
re-init, de-lock, or reset.

Current status:

```text
IDEMPOTENT_GUARD = PASS
STEP4B_COMPLETE = YES
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

Per branch5 instruction, the next review must decide whether the remaining
failure is loop-dynamics/PI behavior now that re-init is removed. This branch
must not be merged until branch5 explicitly returns both:

```text
STEP5_COMPLETE = YES
MERGE_APPROVED = YES
```
