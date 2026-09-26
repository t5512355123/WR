# EXP-S6-MASTER-LAST-EC1F25E8-REBUILD-RECOVERY-ATTRIBUTION-20260921

## Question

The original `ec1f25e8` Master SOF is unavailable.  This separate experiment
asks whether a fresh Master implementation built from the exact source commit,
programmed last while the current Slave remains untouched, reproduces the
observed Slave link recovery.

This is **not** the lost exact-bitstream A/B experiment.  A positive result
supports startup-order sensitivity, but does not prove pure same-bitstream
causality because the rebuilt SOF is a new implementation artifact.

## Fixed contract

```text
MASTER SOURCE       = ec1f25e81e0eb8c2caee796d13a225eaae81e5f2
MASTER FIRMWARE BUILD = YES
MASTER FULL COMPILE   = YES
MASTER PROGRAM        = YES, exactly once

SLAVE FIRMWARE BUILD  = NO
SLAVE FULL COMPILE    = NO
SLAVE PROGRAM         = NO
POWER CYCLE           = NO
PHY/PTP RESET         = NO
MODE COMMAND          = NO
FIBER/QSFP CHANGE     = NO
POLARITY/BITSLIP      = NO
AUTONEG/SI5340/MDIO   = NO
```

The Master is built in a fresh detached worktree at `ec1f25e8`, including the
Master firmware MIF from that same source tree.  The current laptop branch and
its observer changes are never mixed into the build source.

## Procedure

1. Create a clean detached worktree at `ec1f25e8`; stop if the commit is wrong
   or the tree is dirty.
2. Build only Master firmware and the Master JTAG Quartus project.  Record all
   source/MIF/SOF hashes, compiler logs, fitter/assembler result, and timing
   summary.  Stop before programming on any build failure.
3. Collect five paired read-only baseline samples immediately before Master
   programming.  Master and Slave basic health must be valid; Slave must have
   `RX_LOCKED_TO_DATA=1` and changing recovered-RX activity.  The Slave may be
   linked or unlinked at baseline.
4. Program the rebuilt Master on `DE5 [1-11.1]` exactly once.  Do not program
   or reset the Slave.
5. Launch the paired observer immediately.  Require observer start within
   1000 ms of program completion and first valid data within 5000 ms.
6. Require rebuilt Master local-ready for three consecutive samples within
   10 seconds.  Observe Slave reacquisition for at most 120 seconds at about
   250 ms cadence.

## Recovery gate

If the baseline Slave is down, PASS requires five consecutive samples with:

```text
RX_LOCKED_TO_DATA=1
RX activity changed
RX_PATTERN_READY=1
CORE_LINK_OK=1
CORE_TM_LINK_UP=1
```

If the baseline Slave is already up, the observer must first see a fresh
increase in at least one sticky Slave counter (`SYNC_LOSS`, `LOCK_LOSS`,
`LINK_DROP`, `TM_LINK_DROP`, or the recorded RX error counters), and then the
same five-sample recovery streak.  A persistent `PATTERN_READY=1` alone is not
recovery evidence.

## Stop and verdict rules

```text
PASS_REBUILT_MASTER_LAST_RECOVERY
  Master local-ready passes; baseline contract passes; required recovery
  streak passes (and, for baseline-UP, a fresh sticky drop was observed).

FAIL_TRANSIENT_RECOVERY
  Eligible recovery evidence appears but the five-sample streak is lost.

FAIL_REBUILT_MASTER_LAST_RECOVERY_NOT_REPRODUCED
  Master local-ready passes, but no eligible five-sample recovery occurs in
  120 seconds.

INCONCLUSIVE_PREPROGRAM_SLAVE_HEALTH
  Baseline is invalid; Master is not programmed.

INCONCLUSIVE_BUILD_PREREQUISITE_FAIL
  Wrong/dirty source, firmware build failure, Quartus failure, missing SOF,
  or missing build evidence; Master is not programmed.

INCONCLUSIVE
  Programming/transport/observer timing/reset/counter evidence is invalid.
```

No same-session retry, second Master programming, Slave programming, reset, or
power cycle is allowed.

This experiment does not claim Step6A Global Time PASS or run Step6B scheduled
trigger.  Those remain `NOT_PASS` and `NOT_RUN`.

