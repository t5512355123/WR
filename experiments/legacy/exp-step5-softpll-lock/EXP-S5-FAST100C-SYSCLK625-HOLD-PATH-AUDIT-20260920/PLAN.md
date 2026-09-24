# EXP-S5-FAST100C-SYSCLK625-HOLD-PATH-AUDIT-20260920

## Purpose

Resolve the ownership of the first remaining timing boundary from the prior
fresh fitted build:

```text
Fast 900mV 100C hold
u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk
Master WNS = -0.502 ns, TNS = -30.718 ns
Slave  WNS = -0.486 ns, TNS = -36.233 ns
```

This is a read-only TimeQuest path audit. It must identify the actual
full-path data/clock-skew ownership before any hold constraint or RTL change
is considered.

## Frozen baseline

- Quartus Prime 17.0.0 Build 595.
- Existing fitted databases from source/build commit `54919aa7`.
- Master revision: `DE5a_wr_master_jtag`.
- Slave revision: `DE5a_wr_slave_jtag`.
- Device: `10AX115N2F45E1SG`.
- Fast 900mV 100C timing model.

## Laptop action

Add only the read-only audit Tcl and this plan. No RTL, C, SDC, QSF,
firmware, PI, gain, threshold, timeout, detector, anti-windup, bootstrap,
arbiter, mailbox, PHY, reset, control branch, or fitter setting changes.

## Pain action

After pull, run the audit against the existing fitted project/revision
database. Do not clean-compile, program, reset, power-cycle, or run hardware
observation.

For each image the audit must:

1. Reconstruct the Fast 900mV 100C timing netlist.
2. Assert the `u_sys_clk_625` clock collection resolves exactly once.
3. Export the 20 worst full hold paths with routing.
4. Export all negative hold paths using the summary report.
5. Preserve TimeQuest stdout/stderr, tool identity, and raw report checksums.

Before ownership classification, the reported WNS must reproduce exactly to
report precision:

```text
Master = -0.502 ns
Slave  = -0.486 ns
```

If either value does not reproduce, classify the database reproduction as
FAIL and stop; do not infer ownership from the mismatched report.

## Forbidden actions

Do not fix or classify any other timing boundary in this experiment:

- `qsfp_ref_125m` hold or Slow 0C setup;
- Slow 0C removal;
- `wr_core_dmtd_62m496` generated-clock target;
- unconstrained clocks or I/O;
- any RTL timing fix, false path, min-delay, multicycle, or fitter change;
- FPGA programming or hardware observation.

## Stop condition

Stop after Master and Slave each have:

- exact WNS reproduction status;
- Top-20 full-path report;
- all-negative hold summary;
- extracted slack, From/To, launch/latch clocks, data delay, clock skew,
  uncertainty, and path-cone ownership classification.

The experiment must end with the hold boundary still open and overall Step5
still `NO`; the next fix is not selected in this experiment.
