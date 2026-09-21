# EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-20260922

## Purpose

This is Step6B-1.  Step6A already established that Master and Slave expose
the same PPS-labelled Global-Time tuple.  This experiment tests the next
boundary: both boards are armed for one identical future `(TAI, cycles)`
tuple and fire their internal one-shot at that tuple.

The result is digital only.  It does not claim that the two physical SMA
edges have been measured.

## Fixed contract

* `TARGET_TAI` is the latest common pre-arm `SNAPSHOT_TAI` plus 20 seconds.
* `TARGET_CYCLES` is fixed at `62,500,000` (one 125 MHz tick is 8 ns).
* Both boards receive `ARM=0`, then the same target, and the target is held
  stable for at least 100 ms before either board is armed.
* Master and Slave are armed once.  The scheduler is one-shot: an ARM high
  level cannot fire twice; a new shot requires ARM=0 first.
* `xwr_core pps_p_o -> SMA_CLKOUT` is unchanged.
* No scope or physical-edge measurement is part of this experiment.

## Allowed changes

Only the following are changed for this experiment:

* `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd`
* `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd`
* Step6B JTAG/analysis/test/experiment scripts and this report directory

The scheduler is entirely in `QSFPA_REFCLK_p`, the existing 125 MHz WR
reference-clock domain.  Its target and ARM inputs are synchronized through
two flip-flop stages before the target is latched.

## Forbidden changes

Do not modify vendor WR cores, wrpc-sw, SoftPLL/PTP/WR state machines,
SI5340 functional logic, PHY/transceiver logic, QSF, MIF, SMA routing, or
SDC.  Do not adjust PI/gain/threshold/timeout.  No power cycle, reset, PTP
restart, or mode command is part of the normal path.

## Build and timing gate

Firmware is not rebuilt.  Master and Slave full Quartus compilation are
required, using the existing MIF byte-for-byte.  The build records the Git
HEAD/status, source hashes, Quartus version, fitter/assembler result, SOF
hashes, and MIF hash.

Before programming either board, the Step6B-specific timing query must find
the scheduler registers and at least one matched path for target latch, ARM
synchronization, comparator-to-FIRED, and comparator-to-actual timestamp.
All reported setup and hold slacks for those paths must be non-negative.
If the query is empty, unconstrained, or negative, stop with
`RESULT=NOT_RUN_STEP6B_TIMING_NOT_PROVEN` and program count zero.  Global
unrelated WNS is not a Step6B go/no-go criterion.

## Programming and observation

Only after the timing gate passes: program Slave exactly once, then Master
exactly once.  Master is last.  A programming failure stops the run with no
retry.  No power cycle is allowed.

After programming, wait at most 120 seconds for both link gates and the
Slave SoftPLL/Step5 lock precondition.  Then obtain at least five paired
healthy samples and at least three distinct common snapshot TAI labels with
exactly equal cycles.  If this Step6A precondition is not recovered within
60 seconds, do not arm the trigger.

The observer then writes the common target, verifies readback, arms Master
and Slave once, and observes the scheduler until the target plus two seconds.

## Formal digital PASS

The experiment passes only when all of the following hold:

* both boards report `FIRED=1` and `FIRE_COUNT=1`;
* both captured `ACTUAL_TAI == TARGET_TAI`;
* both captured `ACTUAL_CYCLES == 62,500,000`;
* link, time-valid, reset, and Slave SoftPLL conditions remain healthy;
* digital trigger delta is exactly zero tick / zero ns.

The report must state:

```text
RESULT=PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER
STEP6A=PASS
STEP6B_1_DIGITAL_SCHEDULED_TRIGGER=PASS
TARGET_MATCH=PASS
MASTER_FIRE_COUNT=1
SLAVE_FIRE_COUNT=1
DIGITAL_TRIGGER_DELTA_TICKS=0
DIGITAL_TRIGGER_DELTA_NS=0
STEP6B_PHYSICAL_EDGE=NOT_EVALUATED
```

One-sided fire, timestamp mismatch, target miss, count greater than one,
runtime/reset loss, transport failure, or an unproven timing path is not a
Step6B PASS.
