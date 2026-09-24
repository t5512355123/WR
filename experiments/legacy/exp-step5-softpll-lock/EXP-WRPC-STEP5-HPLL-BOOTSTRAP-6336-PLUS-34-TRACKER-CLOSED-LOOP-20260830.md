# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6336-PLUS-34-TRACKER-CLOSED-LOOP-20260830

## Verdict

```text
STEP4B_COMPLETE = YES
STEP4B_RESULT = PASS
STEP5_BOOTSTRAP_6336 = PASS
STEP5_NORMAL_TRACKER_HANDOFF = PASS
STEP5_CLOSED_LOOP_300S = PASS_WITHOUT_LOCK
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This experiment implemented the branch5-approved startup bootstrap: the
Slave first performs exactly 6336 physical A-direction HPLL steps, then
releases the existing 34-code quantized-residual tracker. The bootstrap and
normal tracker accounting are correct, but the Slave never reaches Helper
lock, so Step5 is not complete and this branch is not eligible to merge into
`main`.

## Source and scope

```text
Branch = exp/step5-softpll-lock
Source commit = f38d33604e3e218ec167754ff210ee540433185e
Experiment requested by branch5 = EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6336-PLUS-34-TRACKER-CLOSED-LOOP
```

The functional change is limited to the Step5 bootstrap gate in
`quartus/jtag_runtime_diag/si5340a_controller_dco.v`:

```text
fresh-program
  -> gate normal tracker
  -> execute 6336 serialized A-direction physical steps
  -> bootstrap_done = 1
  -> release existing 34-code quantized-residual tracker
```

The following were preserved: A polarity, `CODE_PER_PHYSICAL_STEP=34`, PI
gains, helper thresholds, lock sample counts, DMTD, PTP/PHY, Main PLL, reset
logic, and the quantized residual rule. No runtime JTAG trigger was used.

Probe 42 reports the persistent bootstrap state. The observed final state was
`remaining=0`, `completed=6336`, `started=1`, `done=1`, `pending=0`, and
`current=0`.

## Build and programming

Both builds used Quartus Prime 17.0 Build 595 on pain and completed
successfully:

```text
Master FITTER = Successful
Slave FITTER = Successful
Master TIMING_CLOSED = NO, worst setup slack = -0.453 ns
Slave TIMING_CLOSED = NO, worst setup slack = -0.357 ns
```

The fresh-program pair completed successfully with zero errors and zero
warnings:

```text
Master SOF checksum = 0x30B897E6
Slave SOF checksum = 0x30AE4324
Master SOF SHA256 = 25d9fe33446a6ebf32759c0a9a5727c6200c32e037ff4e529ff9f68b00571e20
Slave SOF SHA256 = a7c28107b673630603c22082c70ed1392ae44868a65ccf66b7b316c430df2956
```

## Step4B regression

The final Slave dashboard reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
STEP4B_ALLOWED                = YES
STEP4B_RESULT                 = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

Across the final 305-second tracker window, the reset counters remained
stable. The dashboard also reported no new boot generation, CPU reset,
WR-core reset, or SI configuration drop.

## Bootstrap and tracker evidence

The 305-second Slave tracker window ran for approximately 309.6 seconds:

```text
initial BOOTSTRAP_COMPLETED = 6336
final BOOTSTRAP_COMPLETED = 6336
BOOTSTRAP_COMPLETED_DELTA = 0
BOOTSTRAP_STARTED = 1
BOOTSTRAP_DONE = 1
BOOTSTRAP_NORMAL_ZERO_BEFORE_DONE = PASS
```

After handoff to the normal tracker:

```text
NORMAL_REQUEST_DELTA = 7977
NORMAL_COMPLETED_DELTA = 7977
BURST_TRIGGER_DELTA = 0
FORCED_PENDING_DELTA = 0
FORCED_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 7977
INITIAL_TARGET_MINUS_APPLIED = -24
FINAL_TARGET_MINUS_APPLIED = -10
QUANTIZED_SETTLED = PASS
TRACKER_PROGRESS = TOWARD_TARGET
NORMAL_TRANSACTION_ACCOUNTING = CHECK_FINE_GRAIN
```

The tracker samples continuously showed `BOOTSTRAP_REMAINING=0`,
`BOOTSTRAP_COMPLETED=6336`, `BOOTSTRAP_DONE=1`, and normal request/completion
counters advancing together. The `FORCED_HPLL_COMPLETED=192` field is an
8-bit diagnostic view of 6336 (`6336 mod 256 = 192`), not an additional
forced transaction count; its delta was zero during the observation window.

## Step5 result

The final Slave dashboard reported:

```text
STEP5_LOCKDET_BEFORE: HELPER locked=0 changed=0 cnt=262/10000 threshold=200
STEP5_LOCKDET_AFTER:  HELPER locked=0 changed=0 cnt=100/10000 threshold=200
PSTAT_locked = 0
MAIN enabled = 0
MAIN locked = 0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

Therefore the bootstrap solved the startup transaction-accounting boundary,
and Step4B remains a confirmed PASS, but it did not produce the Helper lock
required by Step5. The correct conclusion is:

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The early post-program dashboard is retained as raw evidence but is not used
for the final verdict because it was captured before the Slave Step4B
upstream gate had become active. The final dashboard after the 305-second
window is the authoritative runtime result.

## Raw evidence

Raw logs are stored under:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6336-PLUS-34-TRACKER-CLOSED-LOOP-20260830/
```

Key files:

- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`
- `program_master.log`
- `program_slave.log`
- `tracker_slave_305s.log`
- `dashboard_after_305s.log`
- `dashboard_after_program.log` (early, non-authoritative gate snapshot)
