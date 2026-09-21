# EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-LIVE-SESSION-20260922

## Purpose

Use the already programmed and Step6A-requalified V2 session to test a
Global-Time scheduled digital trigger on both DE5a boards. This experiment
does not reprogram or recover the boards.

## Fixed hardware contract

```text
MASTER/SLAVE COMPILE = NO
FIRMWARE BUILD       = NO
MASTER/SLAVE PROGRAM = NO
MASTER/SLAVE PTP RESTART = NO
CPU/WR/PHY RESET     = NO
POWER CYCLE          = NO
FIBER/QSFP CHANGE    = NO
SI5340/MDIO WRITE    = NO
SMA_CLKOUT CHANGE    = NO
```

The only functional writes allowed after all read-only gates pass are exactly:

```text
Master instance 67: TARGET_TAI, once
Slave  instance 67: TARGET_TAI, once
Master instance 68: ARM 0 -> 1, once
Slave  instance 68: ARM 0 -> 1, once
```

No write of zero is allowed for preparation and no target rewrite or re-arm is
allowed after a failed verification.

## Read-only pre-write gate

For at most 10 seconds, obtain at least three paired healthy samples and three
distinct common snapshot TAI labels. Each common label must have equal Master
and Slave snapshot cycles. Both boards must be time/PPS valid, link-up,
snapshot-valid and reset-stable. Slave must also remain RX-pattern-ready,
SoftPLL sequence-ready, PSTAT locked, Main locked, and in `PD_STATE=3`,
`EXT_STATE=1`.

Failure result:

```text
INCONCLUSIVE_LIVE_SESSION_PREWRITE_GATE_FAILED
```

Then verify the pristine scheduler state on both boards: target source,
ARM source/sync, armed, fired, fire count, actual TAI and actual cycles must
all be zero. If not, stop without clearing anything:

```text
INCONCLUSIVE_STEP6B_INITIAL_STATE_NOT_PRISTINE
```

## Target and ARM protocol

Set `T0` to the latest common snapshot TAI and use only:

```text
TARGET_TAI    = T0 + 20
TARGET_CYCLES = 62500000
```

After both target writes, wait at least 150 ms and verify target readback and
healthy runtime state. Before ARM, both boards must still have at least 12
seconds to the target. Then write ARM on Master followed by Slave, once each;
wait at least 120 ms and verify both boards are armed, synchronized, latched
to the exact target, not fired, and still have at least 10 seconds remaining.

Any failed check stops functional writes immediately. Target and ARM failures
are classified separately in the raw observer result.

## Read-only capture and formal result

After both boards are armed, perform no more writes. Observe until the target
plus one second for a functional miss, with a safety window through target plus
two seconds. A formal PASS requires both boards to fire once at exactly
`(TARGET_TAI, 62500000)`, with armed cleared after firing, followed by at
least three healthy post-fire samples with no second fire.

```text
PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER
STEP6A_REQUALIFICATION = PASS
STEP6B_POSTFIT_TIMING  = PASS
STEP6B_PHYSICAL_EDGE   = NOT_EVALUATED
```

An early fire, one-sided fire, missed fire, timestamp mismatch, target miss,
one-shot violation, runtime loss, reset, or transport/decode error stops the
experiment. The `0 ns` digital delta, if obtained, means equal 8 ns-resolution
internal Global-Time labels; it is not a physical SMA skew measurement.
