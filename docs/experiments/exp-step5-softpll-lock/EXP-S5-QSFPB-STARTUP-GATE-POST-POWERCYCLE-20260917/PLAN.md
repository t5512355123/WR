# EXP-S5-QSFPB-STARTUP-GATE-POST-POWERCYCLE-20260917

## Purpose

Run the single next diagnostic specified by the latest external review:
program the already validated QSFP-B lane-0 topology and determine whether
the WR startup gate can be established after the physical power cycle.

This is an upstream isolation experiment, not a Step5 phase-lock run.  It
does not start F4S/F4L and does not evaluate Helper/Main SoftPLL behavior.

## Source and topology

- Branch: `exp/step5-softpll-lock`
- Source commit: the commit containing this plan
- Project: `quartus/jtag_runtime_diag_portb`
- Data path: QSFP-B lane 0 on both endpoints
- PHY reference clock: QSFP-B reference clock
- DMTD reference: the existing port-B project mapping; do not alter it
- Roles: Slave first on DE5 `[1-11.2]`, Master second on DE5 `[1-11.1]`

The existing QSFP-B diagnostic source is reused unchanged.  No production
Step5 control source is modified in this experiment.

## Frozen scope

No changes to:

- PI gains, thresholds, timeouts, bootstrap or preload
- detector, anti-windup, DAC behavior or ordering
- arbiter, mailbox, PHY RTL, reset tree or SDB
- F4S/F4L observer or any control path

The only hardware mutation is programming the two QSFP-B diagnostic images.
All runtime measurements are read-only.

## Procedure

### Laptop

Push this plan and the exact source commit to GitHub.  Do not stage unrelated
working-tree files.

### Pain

1. Pull the exact pushed commit.
2. Rebuild the current firmware MIFs, then compile both existing port-B
   Quartus projects from a cleanly identified source tree.
3. Record source, MIF, SOF hashes and compile status.
4. Program Slave first, then Master.
5. Run the existing read-only startup probes:
   - repeated `scripts/jtag/read_probe.tcl`
   - `scripts/jtag/read_clock_activity.tcl 2000`
6. Stop after the bounded probe window.  Do not run F4S/F4L.

## Gate and stop conditions

The QSFP-B startup gate is PASS only if both endpoints show, in repeated
read-only samples:

```text
SI_CONFIG_DONE = 1
CPU_RESET_N    = 1
WR_RX_READY    = 1
WR_TX_READY    = 1
CORE_TM_LINK_UP= 1
CORE_LINK_OK   = 1
PSTAT_LINK     = 1
PHY_LINK_USABLE= 1
```

If this gate passes, stop immediately and classify the original QSFP-A
failure as path-specific evidence.  Do not start F4S on the B path.

If QSFP-B also fails to establish the gate, stop immediately and classify a
common WR link-establishment blocker as suspected.  Do not sweep QSFP-C/D or
change Step5 control parameters in this experiment.

The result can never be `STEP5_PASS`; it is either a QSFP-B startup-gate
result or an upstream blocker.

