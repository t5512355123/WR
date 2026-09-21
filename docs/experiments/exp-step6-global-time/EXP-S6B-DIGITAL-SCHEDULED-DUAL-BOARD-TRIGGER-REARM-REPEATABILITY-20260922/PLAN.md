# EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-REARM-REPEATABILITY-20260922

## Purpose

Verify that the existing Step6B digital scheduled-trigger scheduler can be
cleanly re-armed in the same live session and fire a second future timestamp
on Master and Slave at the same 8-ns Global-Time label.

This is a digital repeatability experiment. It does not replace the pending
physical PPS/SMA measurement.

## Hardware and design contract

The already-programmed, already-fired Step6B live session is reused.

```text
COMPILE / BUILD        = NO
MASTER/SLAVE PROGRAM   = NO
CPU/WR/PHY RESET       = NO
PTP RESTART            = NO
POWER CYCLE            = NO
MODE COMMAND           = NO
SMA LOGIC CHANGE       = NO
FIBER/QSFP CHANGE      = NO
SI5340/MDIO WRITE      = NO
```

Only these six functional writes are allowed, in this exact order:

```text
1. Master ARM 1 -> 0
2. Slave  ARM 1 -> 0
3. Master TARGET_TAI := NEW_TARGET_TAI
4. Slave  TARGET_TAI := NEW_TARGET_TAI
5. Master ARM 0 -> 1
6. Slave  ARM 0 -> 1
```

No retry, clear, rewrite, re-arm, reset, or recovery command is allowed.

## Preconditions

Before write 1, obtain at least three paired healthy samples and two distinct
common snapshot TAI labels with zero cycle delta. Both boards must still show
the exact post-fire state from the preceding PASS:

```text
TARGET_TAI_SOURCE = 3433
ARM_SOURCE = 1
ARM_SYNC = 1
ARMED = 0
FIRED = 1
FIRE_COUNT = 1
LATCHED_TARGET_TAI = 3433
ACTUAL_TAI = 3433
ACTUAL_CYCLES = 62500000
```

Reset signatures and Step6A health must remain stable.

## Second trigger

After de-arm verification, obtain two additional common labels and choose:

```text
NEW_TARGET_TAI = latest_common_snapshot_tai + 20
TARGET_CYCLES = 62500000
```

The target is written once per board while ARM is zero. ARM is permitted only
when both boards have at least 12 seconds remaining to the target. After the
two ARM=1 writes, both boards must be armed with the new target latched and at
least 10 seconds remaining.

After that point the observer is read-only through target+2 seconds.

## Formal PASS

```text
PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER_REARM_REPEATABILITY
```

requires:

- all six writes occur exactly once and in the approved order;
- pre-gate and post-de-arm gate pass with no coherence violation;
- both boards fire exactly once more, so `FIRE_COUNT=2`;
- both actual timestamps equal `(NEW_TARGET_TAI, 62500000)`;
- second-trigger delta is exactly 0 Global-Time ticks;
- at least three post-fire paired samples remain healthy with no reset or link
  change.

Physical PPS edge skew remains:

```text
STEP6_PHYSICAL_PPS_BASELINE = NOT_EVALUATED
STEP6B_PHYSICAL_SCHEDULED_TRIGGER_EDGE = NOT_EVALUATED
```

## Stop conditions

- Initial post-fire state mismatch: stop before any write,
  `INCONCLUSIVE_REARM_PRECONDITION_CHANGED`.
- ARM=0 readback/semantics failure: stop without further writes; classify as
  readback inconclusive or `FAIL_STEP6B_REARM_CLEAR_SEMANTICS`.
- Target or ARM readback/window failure: stop without retry.
- One-sided, early, missed, repeated, or timestamp-mismatched second trigger:
  stop and retain the complete raw capture.
- Any reset, link loss, invalid snapshot, transport error, or decode failure:
  stop as runtime inconclusive.
