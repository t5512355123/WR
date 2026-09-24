# EXP-S5-TIMING-TOP20-PATH-EXPORT-20260920

## Purpose

Export the actual Top-20 failing setup paths for the existing fitted Master
and Slave JTAG diagnostic images so that the provisional timing root-cause
classification can be resolved.

## Frozen scope

- Quartus Prime 17.0.0 Build 595 only.
- Source/build identity: `5d7d1a46784581dd1396daeb5a24624b62b1c440`.
- Revisions: `DE5a_wr_master_jtag` and `DE5a_wr_slave_jtag`.
- Device: `10AX115N2F45E1SG`.
- Reuse each revision's existing fitted database, QSF, and SDC.
- No RTL, C, SDC, QSF, gain, threshold, timeout, PI, detector, anti-windup,
  bootstrap, arbiter, mailbox, PHY, reset, control-branch, compile, program,
  power-cycle, or hardware observation changes.

## Required preflight

Run the read-only TimeQuest netlist reconstruction at slow 900 mV, 100 C and
require the generated `clk_50m` setup WNS to reproduce:

```text
Master = -0.289 ns
Slave  = -0.361 ns
```

If either value does not reproduce, stop and classify Top-20 ownership as
`NOT_EVALUATED`; do not use a mismatched path report for root cause.

## Required outputs

For each revision, export:

- the 20 worst `clk_50m` setup paths with `-detail full_path` and routing;
- the negative `clk_50m` setup paths with `-detail full_path` and routing;
- raw Quartus stdout/stderr and the exact tool/version identity.

For every negative path, record slack, From, To, launch/latch clocks, data
arrival/required, data delay, clock skew/uncertainty, and the full cell/routing
path. Classify ownership only from the actual path cone as
`DIAGNOSTIC_OBSERVABILITY`, `PRODUCTION_PATH`, or `MIXED`.

## Stop rule

After both Master and Slave Top-20 reports are captured and classified, stop.
Do not propose or apply a timing fix in this experiment.
