# EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-COHERENT-HELPER-DYNAMICS-AUDIT-20260830

Date: 2026-08-30 (Asia/Taipei)

## Purpose

Classify the Slave Helper dynamics after the idempotent `wrpc_ptp_set_mode(MASTER)` guard was validated. This is a read-only JTAG audit. It does not change the PI coefficients, DMTD path, bootstrap, Main PLL, reset tree, or firmware control flow.

## Exact configuration

```text
board: DE5 [1-11.2] (Slave)
firmware image: fe858bd (fresh-programmed before this audit sequence)
observer: d4c32f1
idempotent guard: enabled
normal HPLL tracker: enabled
bootstrap steps: 6208
code per physical step: 64
kp: -150
ki: -2
threshold: 200
lock samples: 10000
samples: 1800
requested cadence: 100 ms
observer mode: read-only
```

The observer reads the current coherent WDIAGS measurement snapshot at
`0x00100B00..0x00100B24` and brackets the physical position/transaction
probes. The current firmware image does not mirror the internal PI trace
(`integrator_before`, `i_new`, `integrator_after`, unclamped output, clamp
side) into WDIAGS, so `PI_TRACE_AVAILABLE=NO` is intentional. The audit uses
the source-backed coherent Helper error/output fields instead of inventing PI
values from unrelated registers.

## Validated result

```text
SAMPLES=1800
COHERENT_MEASUREMENT_SNAPSHOTS=1800
REJECTED_ACCOUNTING_CANDIDATES=24
MEASUREMENT_ACCOUNTING_FAILS=0
POSITION_SNAPSHOTS=1800
POSITION_INVARIANT_FAILS=0
TRANSACTION_INVARIANT_FAILS=0
DCO_INVARIANT_FAILS=0

FREQ_ERROR_MEAN=335.672777778
FREQ_ERROR_RMS=425.089516716
FREQ_ERROR_MIN=-64
FREQ_ERROR_MAX=544

HELPER_ERROR_MEAN=150000.0
HELPER_ERROR_RMS=150000.0
HELPER_ERROR_MAX_ABS=150000
FRACTION_ABS_ERROR_LE_200=0.0
HELPER_OUTPUT_SAMPLES=1800
LOW_RAIL_FRACTION=1.0
HIGH_RAIL_FRACTION=0.0
NO_RAIL_FRACTION=0.0
LOCK_COUNT_MAX=100
LOCK_COUNT_FINAL=100
LOCK_COUNT_RISE_EVENTS=16
LOCK_COUNT_FALL_EVENTS=16
ERROR_BAND_EXIT_EVENTS=0
ACTUATOR_HUNT_OBSERVED=NO
HELPER_DYNAMICS=STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT

BOOTSTRAP_COMPLETED_FINAL=6208
BOOTSTRAP_DONE_FINAL=1
NORMAL_REQ_DELTA_OBSERVED=0
NORMAL_COMPLETED_DELTA=0
DCO_STEP_DELTA=0
HELPER_LOCKED_FINAL=0
MAIN_ENABLED_FINAL=0
MAIN_FREQ_LOCKED_FINAL=0
MAIN_PHASE_LOCKED_FINAL=0
MAIN_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
FULL_CHAIN_300S=0
STEP5_CHAIN_RESULT=NOT_COMPLETE

RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
MEASUREMENT_COHERENCE=PASS
POSITION_ACCOUNTING=PASS
RESET_STABLE=PASS
```

## Interpretation

The 1800 accepted coherent snapshots show a persistent low-rail condition:
the Helper error is clamped at `+150000` and the Helper output is clamped at
the lower limit `5`. The Helper lock counter never exceeds its unlocked
floor of `100`, and the Main PLL remains disabled. There is no evidence of a
300-second closed-loop lock interval.

This is therefore **not** an underdamped/over-aggressive trajectory and does
not justify PI retuning yet. The evidence points to a steady bias or an
actuator-range/command-path limitation. The zero post-bootstrap normal-HPLL
request delta is also recorded for branch5 to decide whether the next audit
must attribute the missing DCO request/completion path before any controller
tuning.

## Excluded preliminary capture

The same raw directory contains an earlier 1800-sample capture made before
the Helper payload range gate was added. It reported out-of-range Helper
payload values and is retained for auditability but excluded from the result
above. The earlier PI-state observer capture is also excluded because its
assumed WDIAGS mapping does not match the current firmware image.

## Milestone decision

```text
STEP4B_COMPLETE = YES
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

Raw capture:

`raw/EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-COHERENT-HELPER-DYNAMICS-AUDIT-20260830/guarded-helper-dynamics-1800-validated.log`

