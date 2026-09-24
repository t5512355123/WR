# EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-LIVE-SESSION-20260922

## Verdict

```text
STEP6A_REQUALIFICATION = PASS
STEP6B_1_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER = PASS
STEP6B_PHYSICAL_EDGE = NOT_EVALUATED
VERDICT = PASS
```

This is a functional pass for the internal Global-Time scheduled digital
trigger. It is not a measurement of the physical SMA/output-edge skew.

## Hardware session

The already programmed and Step6A-requalified V2 session was reused. No
compile, firmware build, FPGA programming, PTP restart, CPU/WR/PHY reset,
power cycle, fiber/QSFP change, SI5340/MDIO write, or SMA clock-output change
was performed.

The fitted source identity was:

```text
DESIGN_SOURCE_COMMIT = c24568e383be3355ac8684b7d13f293115931586
LIVE_RUNNER_COMMIT   = 77ca75a81340fcf1f64884cb780e5dc72096c655
MASTER_SOF_SHA256    = 1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5
SLAVE_SOF_SHA256     = 66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151
```

## Read-only pre-write gate

The gate produced four paired healthy samples and three distinct common
snapshot TAI labels. Snapshot cycle coherence violations were zero. Link,
time/PPS validity, transport, and reset signatures remained valid. The Slave
was RX-pattern-ready, SoftPLL-ready, PSTAT-locked, Main-locked, and in the
required `PD_STATE=3`, `EXT_STATE=1` state.

The pristine scheduler check passed: both boards had zero target source, zero
ARM source/sync, zero armed, zero fired, zero fire count, and zero actual
trigger timestamp before the first write.

## Scheduled trigger

The latest common pre-write label was `T0=3413`. The exact target was:

```text
TARGET_TAI    = 3433
TARGET_CYCLES = 62500000
```

The permitted writes occurred exactly once and in the required order:

```text
Master instance 67: TARGET_TAI = 3433
Slave  instance 67: TARGET_TAI = 3433
Master instance 68: ARM = 1
Slave  instance 68: ARM = 1
```

The target and ARM readbacks passed, including the required remaining-time
guards. No writes occurred after both boards were armed.

## Observed result

```text
CAPTURE_SAMPLES          = 27
POST_FIRE_SAMPLES        = 3
MASTER_FIRED             = 1
SLAVE_FIRED              = 1
MASTER_FIRE_COUNT        = 1
SLAVE_FIRE_COUNT         = 1
MASTER_ACTUAL_TAI        = 3433
SLAVE_ACTUAL_TAI         = 3433
MASTER_ACTUAL_CYCLES     = 62500000
SLAVE_ACTUAL_CYCLES      = 62500000
DIGITAL_TRIGGER_DELTA    = 0 internal ticks (0 ns label)
COHERENCE_VIOLATION      = 0
```

Both boards fired exactly once at the requested Global-Time timestamp, cleared
their armed state after firing, and remained healthy for the required
post-fire samples. The analyzer returned:

```text
PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER
```

The reported `0 ns` is only the equality of the internal 125 MHz / 8 ns
Global-Time labels. A physical edge comparison still requires an external
measurement instrument and is intentionally outside this experiment.

## Evidence

```text
raw/observe/observe.log
raw/protocol.txt
raw/stop.txt
analysis/analyzer.txt
analysis/summary.json
analysis/summary-local.json
```
