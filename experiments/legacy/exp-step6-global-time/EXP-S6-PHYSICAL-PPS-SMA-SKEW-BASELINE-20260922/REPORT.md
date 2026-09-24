# EXP-S6-PHYSICAL-PPS-SMA-SKEW-BASELINE-20260922

## Verdict

```text
RESULT = INCONCLUSIVE_PHYSICAL_MEASUREMENT_SETUP
STEP6A_DIGITAL_GLOBAL_TIME = PASS
STEP6B_1_DIGITAL_SCHEDULED_TRIGGER = PASS
STEP6_PHYSICAL_PPS_BASELINE = NOT_EVALUATED
STEP6B_PHYSICAL_SCHEDULED_TRIGGER_EDGE = NOT_EVALUATED
```

The physical PPS acquisition was not performed because no controllable
oscilloscope/instrument window was available in the current remote Windows
environment, and no scope CSV, waveform export, or screenshot was available.
No physical edge result is inferred from the digital `0 tick` result.

## Hardware contract

The fitted design and live session were left unchanged. There was no compile,
firmware build, FPGA programming, PTP restart, CPU/WR/PHY reset, power cycle,
target/ARM write, fiber/QSFP change, SI5340/MDIO write, or SMA logic change.

## Pre-measurement read-only gate

The Pain pre-gate completed successfully:

```text
PAIR_COUNT             = 3
COMMON_TAI_COUNT       = 3
COMMON_TAI_LABELS      = 5015, 5016, 5017
ALL_GATE_ROWS_VALID    = true
RESET_SIGNATURES       = (1,1,1,1) for all six board rows
TARGET_WRITE_COUNT     = 0
ARM_WRITE_COUNT        = 0
PROGRAM_COUNT          = 0
POWER_CYCLE            = 0
```

Thus the session was healthy before any attempted physical measurement. The
pre-gate evidence does not substitute for the missing oscilloscope capture.

## Physical acquisition status

The required setup would have been:

```text
Master SMA_CLKOUT -> oscilloscope CH1
Slave  SMA_CLKOUT -> oscilloscope CH2
20 consecutive rising PPS edges
delta_i = Slave 50% crossing - Master 50% crossing
```

No cable or scope connection was changed, no waveform was acquired, and no
edge CSV was produced. Therefore the formal test
`MAX_ABS_DELTA_NS < 8 ns` was not evaluated. The post-measurement gate was also
not run because there was no acquisition interval to bracket.

## Stop reason

```text
INCONCLUSIVE_PHYSICAL_MEASUREMENT_SETUP
```

This is an instrumentation/setup stop, not a PPS synchronization failure. The
earlier digital Step6B result remains valid, while the physical PPS baseline
and the physical scheduled-trigger edge remain unevaluated.

## Evidence

```text
raw/protocol.txt
raw/pre/gate.log
raw/pre-stop.txt
analysis/pre-gate.json
analysis/pre-gate-analyzer.txt
PLAN.md
```
