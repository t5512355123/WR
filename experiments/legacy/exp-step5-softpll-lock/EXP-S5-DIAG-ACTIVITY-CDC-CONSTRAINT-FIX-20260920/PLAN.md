# EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920

## Purpose

Test only the timing constraint for the already identified diagnostic
activity-toggle CDC.  The experiment must determine whether the two known
100 C slow `clk_50m` violations are correctly excluded without excluding the
second and third synchronizer stages.

## Laptop change

Modify only:

- `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc`
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc`

Each SDC adds exactly three point-to-point exceptions:

```text
ref_activity_toggle  -> ref_activity_meta
dmtd_activity_toggle -> dmtd_activity_meta
rx_activity_toggle   -> rx_activity_meta
```

Each source and destination must resolve to exactly one register at SDC
evaluation time.  The `meta -> sync -> prev` stages remain timed.

Forbidden in this experiment:

- `set_clock_groups`;
- wildcard `*meta*` or any broad wildcard exception;
- whole-clock or whole-domain false paths;
- production endpoint exceptions;
- RTL, QSF, firmware, PI, gain, threshold, timeout, detector, anti-windup,
  bootstrap, arbiter, mailbox, PHY, reset, or control-branch changes.

## Pain execution

After the laptop commit is pushed, Pain pulls it and performs clean Master and
Slave compiles followed by a static timing audit.  Do not program either FPGA
and do not power-cycle.

Audit all available corners and analyses:

```text
Slow 900mV 100C: setup, hold, recovery, removal
Slow 900mV 0C:   setup, hold, recovery, removal
Fast 900mV 100C: setup, hold, recovery, removal
Fast 900mV 0C:   setup, hold, recovery, removal
```

Also record unconstrained clocks/input/output paths and the
`wr_core_dmtd_62m496` generated-clock target match result.

## Acceptance and stop rules

The laptop source/diff test must report three expected pairs per SDC and no
forbidden broad exception.  If it fails, stop without pushing or compiling.

The clean STA must show:

1. the `rx_activity_toggle -> rx_activity_meta` path is no longer a timed
   setup violation in Master or Slave;
2. Master and Slave `clk_50m` setup WNS at slow 900mV, 100C are non-negative;
3. `meta -> sync` and `sync -> prev` remain timed for all three activity
   observers.

If the original violation remains, or if the synchronizer tail is falsely
excluded, stop and classify the constraint test as failed.  Do not add a
second exception in this experiment.

After both clean builds and the all-corner summary are recorded, stop.  The
experiment is not expected to make the overall Step5 timing closure pass.
