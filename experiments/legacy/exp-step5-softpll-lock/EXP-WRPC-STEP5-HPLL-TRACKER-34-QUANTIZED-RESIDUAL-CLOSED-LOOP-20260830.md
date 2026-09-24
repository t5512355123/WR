# EXP-WRPC-STEP5-HPLL-TRACKER-34-QUANTIZED-RESIDUAL-CLOSED-LOOP-20260830

## Verdict

```text
STEP4B_COMPLETE = YES
CODE_PER_PHYSICAL_STEP = 34
QUANTIZED_RESIDUAL_TRACKER = IMPLEMENTED
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

The normal HPLL tracker was changed to use a quantized residual.  The
hardware run preserved Step4B, but did not reach Helper lock, Main lock, or
`PSTAT_locked=1`; this branch is not eligible to merge into `main`.

## Implementation

Source commit: `c445e7f`.

The only functional change was in
`quartus/jtag_runtime_diag/si5340a_controller_dco.v`:

```text
residual >= +34 -> admit one physical FINC step
residual <= -34 -> admit one physical FDEC step
|residual| < 34 -> no normal physical transaction

normal completion -> APPLIED_CODE += 34 or -= 34
```

The completion path no longer assigns `APPLIED_CODE=TARGET_CODE` for a
sub-step residual, so it cannot claim partial virtual credit for a full
physical DCO step.  The comparisons are sign-safe and avoid 16-bit
subtraction wraparound.

The read-only tracker diagnostic was updated in commit `86e8903` to report
`QUANTIZED_SETTLED=PASS` when `abs(TARGET_CODE-APPLIED_CODE) < 34`, and to
report `PASS_SETTLED` when a settled window has no new normal or forced
transactions.

No A polarity, PI gains, lock thresholds, DMTD, PTP/PHY, Main PLL, forced
burst path, or reset logic was changed.

## Build and programming

Both Quartus Prime 17.0 Build 595 builds completed successfully:

```text
Master FITTER = Successful
Slave FITTER = Successful
Master TIMING_CLOSED = NO, worst setup slack = -0.453 ns
Slave TIMING_CLOSED = NO, worst setup slack = -0.369 ns
```

The fresh-program pair completed successfully with 0 errors and 0 warnings:

```text
Master checksum = 0x30B897E6
Slave checksum = 0x30B79B1A
JTAG ID = 0x02E660DD on both cables
```

## Step4B regression

The final paired dashboard reported:

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake            pass
STEP4B_ALLOWED                = YES
STEP4B_RESULT                 = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

The 300-second window also kept `BOOT_GENERATION`, CPU reset count, WR-core
reset count, and SI configuration drop count unchanged.

## Quantized tracker evidence

Immediately after programming, the Slave settled at:

```text
TARGET_CODE = 65531
APPLIED_CODE = 65523
TARGET_MINUS_APPLIED = +8
QUANTIZED_SETTLED = PASS
```

The 300-second tracker window ran for approximately 304.5 seconds.  Its
initial and final samples were identical:

```text
initial TARGET_CODE = 65531
initial APPLIED_CODE = 65523
initial NORMAL_HPLL_REQUEST_COUNT = 3207
initial NORMAL_HPLL_COMPLETED_COUNT = 3207

final TARGET_CODE = 65531
final APPLIED_CODE = 65523
final NORMAL_HPLL_REQUEST_COUNT = 3207
final NORMAL_HPLL_COMPLETED_COUNT = 3207

TARGET_DELTA = 0
APPLIED_DELTA = 0
NORMAL_HPLL_COMPLETED_DELTA = 0
BURST_TRIGGER_DELTA = 0
FORCED_HPLL_PENDING_DELTA = 0
FORCED_HPLL_COMPLETED_DELTA = 0
```

The updated diagnostic was then run on the settled state and reported:

```text
TARGET_CODE = 5
APPLIED_CODE = 5
TARGET_MINUS_APPLIED = 0
QUANTIZED_SETTLED = PASS
NORMAL_REQUEST_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
BURST_TRIGGER_DELTA = 0
FORCED_PENDING_DELTA = 0
FORCED_COMPLETED_DELTA = 0
NORMAL_TRANSACTION_ACCOUNTING = PASS_SETTLED
```

This proves the settled definition and the no-transaction guard.  The
one-second sampled window is not treated as a per-transaction pulse trace;
the exact `+34/-34` invariant is established by the HDL completion rule.

## Step5 result

After the 300-second run, the final Slave dashboard still reported:

```text
HELPER locked = 0
MAIN enabled = 0
MAIN locked = 0
PSTAT_locked = 0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

Therefore the quantized-residual fix is implemented and Step4B remains a
PASS, but Step5 is not complete:

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

Raw JTAG logs are stored under:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-TRACKER-34-QUANTIZED-RESIDUAL-CLOSED-LOOP-20260830/
```

Key files:

- `tracker-slave-initial.log`
- `tracker-slave-300s.log`
- `tracker-slave-quantized-settled.log`
- `dashboard-initial.log`
- `dashboard-final.log`
- `dashboard-post-settled.log`
