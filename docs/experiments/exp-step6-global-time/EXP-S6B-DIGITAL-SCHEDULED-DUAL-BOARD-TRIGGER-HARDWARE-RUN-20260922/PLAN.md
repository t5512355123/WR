# EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-HARDWARE-RUN-20260922

## Purpose

Run the approved Step6B-1 hardware validation using the already fitted and
post-fit-timing-proven Master and Slave SOFs. Step6A global-time validity is
requalified before any trigger write. This experiment evaluates the internal
digital scheduler only; it does not measure physical SMA edge skew.

## Fixed artifact contract

```text
DESIGN_SOURCE_COMMIT = c24568e383be3355ac8684b7d13f293115931586
SLAVE_SOF_SHA256     = 66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151
MASTER_SOF_SHA256    = 1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5
POSTFIT_TIMING       = PASS_STEP6B_POSTFIT_TIMING_PROVEN
TARGET_CYCLES        = 62500000
```

No firmware build or Quartus compile is permitted. The runner must verify the
SOF, MIF, source, and post-fit timing provenance before touching either board.
Any mismatch stops with zero programming count.

## Hardware contract

* Program Slave `DE5 [1-11.2]` exactly once.
* Program Master `DE5 [1-11.1]` exactly once, last.
* No power cycle, CPU/WR/PHY reset, mode command, fiber/QSFP change,
  autonegotiation change, SI5340 change, MDIO write, or SMA routing change.
* A Slave `ptp stop` followed by `ptp start` is allowed at most once, and only
  if the exact known terminal-fallback signature is observed:
  healthy link, RX pattern ready, SoftPLL sequence ready, PSTAT/Main locked,
  `PTP_STATE=9`, `PD_STATE=4`, `EXT_STATE=2`, `WR_STATE=WRS_IDLE`, and
  `TIME_VALID=0`. Master PTP restart is never allowed.

## Pre-arm qualification

Before writing a target or ARM source:

* collect at least five paired healthy samples within 60 seconds;
* both boards must have valid time/PPS snapshots and healthy link/reset state;
* find at least three distinct common `SNAPSHOT_TAI` labels with equal cycles;
* Slave must have SoftPLL sequence ready, PSTAT locked, and Main locked;
* verify both `ARM_SOURCE=0`, `FIRED=0`, and `FIRE_COUNT=0`.

Failure stops without arming. No second target or recovery is attempted.

## Scheduled trigger

Use the last common label `T0` and set the same target on both boards:

```text
TARGET_TAI    = T0 + 20
TARGET_CYCLES = 62500000
```

Write each target once while ARM remains zero, wait at least 150 ms, verify
readback, then raise Master ARM once and Slave ARM once. After both ARM writes,
verify latched target, armed state, no fire yet, and at least 10 seconds remain
to target. Then perform read-only capture at 200–500 ms cadence through target
plus two seconds. After both boards fire, preserve at least three additional
read-only samples to verify the one-shot count remains one.

## Formal PASS

```text
RESULT = PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER
STEP6A = PASS
STEP6B_POSTFIT_TIMING = PASS
STEP6B_1_DIGITAL_SCHEDULED_TRIGGER = PASS
MASTER_FIRE_COUNT = 1
SLAVE_FIRE_COUNT = 1
TARGET_MATCH = PASS
ACTUAL_TIMESTAMP_MATCH = PASS
DIGITAL_TRIGGER_DELTA_TICKS = 0
DIGITAL_TRIGGER_DELTA_NS = 0
STEP6B_PHYSICAL_EDGE = NOT_EVALUATED
```

Any one-sided fire, timestamp mismatch, target miss, count above one, runtime
state change, transport/decode failure, programming failure, or missing
provenance is a hard stop and must not be retried in the same session.
