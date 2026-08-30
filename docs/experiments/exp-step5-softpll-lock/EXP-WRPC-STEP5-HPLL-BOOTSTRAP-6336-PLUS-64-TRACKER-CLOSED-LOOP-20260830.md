# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6336-PLUS-64-TRACKER-CLOSED-LOOP-20260830

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

This experiment used the branch5-approved 6336-step startup bootstrap and
changed only the Slave normal tracker accounting from 34 DCO codes per
physical step to 64. The bootstrap completed and the normal tracker ran with
matching request/completion deltas, but the Helper did not obtain sustained
lock. Step4B is confirmed; Step5 is not complete and this branch is not
eligible to merge into `main`.

## Source and scope

```text
Branch = exp/step5-softpll-lock
Source commit = 8350dd4e7de2c81a898cbb57672536a8e458105d
Experiment = EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6336-PLUS-64-TRACKER-CLOSED-LOOP-20260830
```

The only functional parameter change was the Slave normal tracker
`HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 64`. The existing 6336 physical-step
bootstrap remained enabled. All gains, thresholds, DMTD/PTP/PHY logic, Main
PLL logic, reset logic, and the quantized residual rule were preserved.

The Tcl tracker readback was updated to account for 64-code quantization and
to report Helper error and lock statistics. It remained read-only with
respect to the target hardware.

## Build and programming

Both Quartus Prime 17.0 Build 595 builds completed successfully on pain:

```text
Master FITTER = Successful
Slave FITTER = Successful
Master TIMING_CLOSED = NO, worst setup slack = -0.453 ns
Slave TIMING_CLOSED = NO, worst setup slack = -0.357 ns
```

Fresh programming of both boards completed successfully with zero errors and
zero warnings:

```text
Master SOF checksum = 0x30B897E6
Slave SOF checksum = 0x30B076E3
Master SOF SHA256 = 25d9fe33446a6ebf32759c0a9a5727c6200c32e037ff4e529ff9f68b00571e20
Slave SOF SHA256 = a7c28107b673630603c22082c70ed1392ae44868a65ccf66b7b316c430df2956
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
BOOT_GENERATION delta     = 0
CPU_RESET_COUNT delta     = 0
WR_CORE_RESET_COUNT delta = 0
SI_CONFIG_DROP_COUNT delta= 0
```

This confirms that Step4B remained active and that the 64-code tracker test
did not introduce a reset regression.

## Bootstrap and normal tracker evidence

The valid formal Slave window ran for 305 samples over 309.605 seconds:

```text
BOOTSTRAP_COMPLETED_DELTA = 0
BOOTSTRAP_STARTED = 1
BOOTSTRAP_DONE = 1
BOOTSTRAP_NORMAL_ZERO_BEFORE_DONE = PASS
```

The tracker then operated normally:

```text
TARGET_DELTA = -6063
APPLIED_DELTA = -6016
NORMAL_REQUEST_DELTA = 6984
NORMAL_COMPLETED_DELTA = 6984
BURST_TRIGGER_DELTA = 0
FORCED_PENDING_DELTA = 0
FORCED_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 6984
INITIAL_TARGET_MINUS_APPLIED = 47
FINAL_TARGET_MINUS_APPLIED = 0
QUANTIZED_SETTLED = PASS
TRACKER_PROGRESS = TOWARD_TARGET
NORMAL_TRANSACTION_ACCOUNTING = CHECK_FINE_GRAIN
```

The per-window request and completion counters matched exactly, and no new
forced activity occurred. The fine-grain accounting label is retained because
the absolute target and applied counters move through many quantized
transactions; it is not a failure of the request/completion equality.

The Helper statistics over the same valid window were:

```text
HELPER_ERROR_SAMPLES = 305
HELPER_ERROR_MEAN = 18738.361
HELPER_ERROR_RMS = 136187.504
HELPER_ERROR_MAX_ABS = 2266926
HELPER_ERROR_FRACTION_ABS_LE_200 = 12.131 percent
HELPER_LOCK_COUNT_MAX = 3438
HELPER_LOCK_COUNT_FINAL = 100
NORMAL_COMPLETED_PER_SECOND = 22.558
WINDOW_SECONDS = 309.605
```

The higher transient lock-count peak did not become sustained lock. Near the
end of the window the target and applied code both remained at 5 while the
Helper output remained 5 and the Helper error readback remained `0x249F0`.

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

Therefore the 64-code change improved the observed transient lock counter but
did not establish the sustained Helper lock required by Step5. The correct
milestone conclusion is:

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

An initial post-program tracker attempt is retained in the raw directory but
was aborted because the Slave Step4B upstream gate had not yet become active
and the counters were transiently all zero. It is excluded from the verdict.
The subsequent `dashboard_gate_retry_2.log` confirmed the valid gate before
the formal window, and `dashboard_after_305s.log` is the authoritative final
runtime result.

## Raw evidence

Raw logs are stored under:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6336-PLUS-64-TRACKER-CLOSED-LOOP-20260830/
```

Key files:

- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`
- `program_master.log`
- `program_slave.log`
- `program_slave_retry.log`
- `tracker_slave_305s_valid.log`
- `dashboard_gate_retry_2.log`
- `dashboard_after_305s.log`
- `tracker_slave_305s.log` (early invalid-window attempt, excluded from verdict)

