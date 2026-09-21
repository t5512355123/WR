# EXP-S6-GLOBAL-TIME-LATE-RECOVERY-TAIL-STABILITY-20260922

## Purpose

Revalidate the existing post-`ptp start` runtime session after the previous
30-second capture ended with its first valid Slave Global-Time snapshot at
29.772 seconds. The only question is whether that was a late stable recovery
or a transient sample.

## Contract

This experiment is completely read-only:

- no compile, firmware build, program, CPU/WR/PHY reset, PTP restart, mode
  command, power-cycle, QSFP/fiber change, polarity/bit-slip change,
  autonegotiation, SI5340, or MDIO write;
- only `scripts/jtag/`, `scripts/analysis/`, `scripts/experiment/`,
  `scripts/tests/`, and this experiment directory may be changed;
- preserve the current hardware/runtime session from the preceding recovery
  experiment.

## Phase A: current-session gate

Collect three paired Master/Slave samples. Every pair must have valid and
healthy link diagnostics, stable boot/CPU/WR-core/SI-config counters, and for
Slave also `RX_LOCKED_TO_DATA=1`, `RX_PATTERN_READY=1`, and changing RX
activity. Slave `TIME_VALID` is intentionally not a precondition.

If the gate fails, stop with:

```text
RESULT=INCONCLUSIVE_TAIL_PRECONDITION_CHANGED
STEP6A_1=NOT_EVALUATED
STEP6B=NOT_RUN
```

## Phase B: tail capture

Capture both boards for at most 15 seconds with an approximately 400 ms
requested gap. Save PTP/WR state, WR signals and counters, S_LOCK trace,
SoftPLL/PSTAT/Main lock fields, status time/PPS bits, snapshot validity/count,
snapshot TAI/cycles, and live TAI/cycles. Master Global Time is retained as a
control trace; same-PPS equality is not evaluated in this experiment.

The formal accepted Slave sample requires:

```text
TIME_VALID=1
SNAPSHOT_VALID=1
SNAPSHOT_TIME_VALID=1
SNAPSHOT_PPS_VALID=1
CORE_LINK_OK=1
CORE_TM_LINK_UP=1
RX_LOCKED_TO_DATA=1
RX_PATTERN_READY=1
SPLL_SEQ_STATE=SEQ_READY
PSTAT_LOCKED=1
MAIN_LOCKED=1
0 <= snapshot_cycles <= 124999999
```

The live time is converted to `TAI * 125000000 + cycles`; adjacent accepted
samples must increase. A pass requires five consecutive accepted Slave samples
and at least two snapshot-count advances in that window.

## Stop/result mapping

- `PASS_LATE_RECOVERY_STABLE`: Step6A-1 PASS; Step6B remains not run.
- `FAIL_LATE_RECOVERY_NOT_SUSTAINED`: at least five consecutive terminal
  fallback samples with the SoftPLL still ready.
- `FAIL_INTERMITTENT_GLOBAL_TIME_VALIDITY`: active extension with time-valid
  oscillation but no formal window.
- `FAIL_GLOBAL_TIME_PPS_SNAPSHOT_NOT_ADVANCING`: time-valid streak is long
  enough but snapshot count does not advance twice.
- `FAIL_GLOBAL_TIME_RECOVERY_LOST`: a valid snapshot was followed by loss;
  three post-loss samples are retained.
- `INCONCLUSIVE_RUNTIME_STATE_CHANGED`: transport, decode, link, RX, reset, or
  counter-baseline invalidity.

No result from this experiment permits Step6B scheduled triggering. Same-PPS
consistency remains a later Step6A-2 experiment.
