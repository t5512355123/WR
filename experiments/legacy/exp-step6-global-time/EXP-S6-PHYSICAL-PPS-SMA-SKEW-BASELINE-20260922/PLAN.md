# EXP-S6-PHYSICAL-PPS-SMA-SKEW-BASELINE-20260922

## Purpose

Measure the physical rising-edge offset between the existing Master and Slave
`SMA_CLKOUT` PPS outputs. In the fitted design these outputs are the existing
`pps_p_o` signals. This is a physical PPS baseline, not a physical measurement
of the Step6B scheduled-trigger pulse; the fitted scheduler trigger is not
connected to SMA in this experiment.

## Hardware contract

```text
MASTER/SLAVE COMPILE       = NO
FIRMWARE BUILD             = NO
MASTER/SLAVE PROGRAM       = NO
MASTER/SLAVE PTP RESTART   = NO
CPU/WR/PHY RESET           = NO
POWER CYCLE                = NO
TARGET/ARM WRITE           = NO
SMA LOGIC CHANGE           = NO
QSF/SDC/MIF/RTL CHANGE    = NO
FIBER/QSFP CHANGE          = NO
SI5340/MDIO WRITE          = NO
```

The only physical action is connecting:

```text
Master SMA_CLKOUT -> oscilloscope CH1
Slave  SMA_CLKOUT -> oscilloscope CH2
```

Use matching cables and identical channel settings. The QSF declares the
output as 1.8 V single-ended; use DC coupling and High-Z/1 MOhm input unless
the board documentation explicitly establishes safe 50 Ohm drive.

## Phase A: read-only pre-gate

Run the gate observer before connecting/acquiring the scope. It requires three
paired healthy samples and at least two distinct common `SNAPSHOT_TAI` labels
with equal snapshot cycles. Both boards must retain valid time/PPS snapshots,
healthy links, and reset signature `(1,1,1,1)`; the Slave must retain RX
pattern readiness, SoftPLL ready, PSTAT lock, and Main lock.

If the gate fails, stop as
`INCONCLUSIVE_PHYSICAL_PPS_PRECONDITION_CHANGED` and do not recover the
session.

## Phase B: scope acquisition

Use the Master PPS rising edge as the trigger. Record 20 consecutive edges and
calculate each channel's own 50% crossing time:

```text
delta_i_ns = slave_rising_50_percent_ns - master_rising_50_percent_ns
```

Record scope model, sample rate, bandwidth, input impedance, vertical scale,
trigger settings, cable identity/length, and the exported CSV. The accepted
CSV format is either:

```text
edge_index,master_crossing_ns,slave_crossing_ns
```

or:

```text
edge_index,delta_ns
```

## Formal physical result

The measurement passes only when all 20 edges are valid and consecutive, with
no missing/extra edge or one-second slip, and:

```text
MAX_ABS_DELTA_NS < 8
```

The analyzer reports
`PASS_PHYSICAL_PPS_EDGE_WITHIN_ONE_GLOBAL_TIME_TICK`. It must not be reported
as physical skew equal to zero, nor as sub-nanosecond White Rabbit accuracy.

If the complete 20-edge capture is valid but any absolute delta is at least
8 ns, report `FAIL_PHYSICAL_PPS_EDGE_EXCEEDS_ONE_GLOBAL_TIME_TICK` and preserve
the full distribution. If the setup, timing resolution, cable delay, trigger,
or waveform crossing is not trustworthy, report
`INCONCLUSIVE_PHYSICAL_MEASUREMENT_SETUP`.

## Phase C: read-only post-gate

Immediately after the scope acquisition, run the same three-pair/two-common-
label gate. If it fails, report
`INCONCLUSIVE_STEP6A_STATE_CHANGED_DURING_PHYSICAL_MEASUREMENT`; do not use a
good-looking waveform to claim a synchronized result.

The final report must retain the pre/post gate raw logs, scope CSV/screenshot
or an explicit instrumentation reason, analyzer JSON, protocol, and stop
records. `STEP6B_1_DIGITAL_SCHEDULED_TRIGGER` remains PASS from the earlier
experiment, while
`STEP6B_PHYSICAL_SCHEDULED_TRIGGER_EDGE=NOT_EVALUATED`.
