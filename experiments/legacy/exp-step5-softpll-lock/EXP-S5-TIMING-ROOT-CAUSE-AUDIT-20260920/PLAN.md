# EXP-S5-TIMING-ROOT-CAUSE-AUDIT-20260920

## Purpose

Perform a read-only static timing root-cause audit for the existing Master and
Slave JTAG diagnostic builds after functional Main phase-lock evidence passed.

## Frozen scope

- No RTL, C, SDC, QSF, gain, threshold, timeout, PI, detector, anti-windup,
  bootstrap, arbiter, mailbox, PHY, reset, or control-branch changes.
- No Quartus compile, FPGA programming, power cycle, reset, or hardware
  observation.
- Inspect only the existing TimeQuest reports/databases, fitter/map reports,
  constraints, and the exact top-level source snapshots used by the build.

## Required outputs

For both images, record:

1. WNS, TNS, and the available failing-setup indication.
2. Unconstrained-clock/port counts.
3. Top-20 setup path details and ownership, if those details are present in the
   archived artifacts.
4. Whether the failing paths can be attributed to production logic,
   JTAG/observer/F4L diagnostics, or a mixture.

## Stop rule

Stop after the artifact audit. If the archived report export does not contain
path-level data, classify the path-ownership result as unresolved and request a
new offline `report_timing -npaths 20 -detail full` export from the exact
TimeQuest database before any timing fix is attempted.
