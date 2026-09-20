# EXP-S6-GLOBAL-TIME-OBSERVABILITY-20260920

## Objective

Validate Step6A Global Time observability on the existing Master and Slave
DE5a images before implementing any scheduled trigger:

```text
time_valid = 1
pps_valid  = 1
TAI/cycles are captured coherently at the PPS boundary
cycles advance and wrap at the 125 MHz reference-clock period
TAI increments once at the boundary
```

Step6B (global-time dual-board trigger) is deliberately out of scope for this
experiment.

## Source scope

The only production changes are observation paths in:

```text
quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd
quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd
```

The WR Core `tm_tai_o`, `tm_cycles_o`, and `pps_csync_o` outputs are connected
to diagnostic-only signals.  A process in the same 125 MHz reference-clock
domain freezes a coherent tuple on `pps_csync`.  No snapshot signal feeds the
WR core, reset tree, SoftPLL, PPS output, PHY, mailbox, or control logic.

## JTAG probe contract

Both images use the same unused probe indices:

| Probe | Meaning |
| ---: | --- |
| 62 | PPS snapshot word 0: `TAI[39:0]`, `cycles[23:0]` |
| 63 | PPS snapshot word 1: `cycles[27:24]`, validity flags, snapshot sequence |
| 64 | packed live sample: `TAI[35:0]`, `cycles[27:0]` |

The observer reads probe 63, then 62, then 63 again.  A row is accepted only
when both sequence words match.  Probe 64 is used only for short-interval
cycle monotonicity; the PPS snapshot remains the authoritative full-width
TAI/cycle record.

## Hardware procedure

1. Laptop offline contract tests and source audit pass.
2. Push the exact source commit to `exp/step6-Global-Time-Testing`.
3. Pain pulls that commit into a clean dedicated worktree.
4. Compile the existing Master and Slave diagnostic projects and program both
   boards.  Do not power-cycle unless the build/program procedure proves it is
   necessary.
5. Run `scripts/jtag/read_step6_global_time_observability.tcl` for each board
   in a single read-only session, preserving raw output and checksums.
6. Analyze each capture offline and compare Master/Slave only at shared TAI
   PPS boundaries.  Sequential host reads are not treated as same-PPS proof.
7. Write the report and raw evidence into this experiment directory and push
   the report commit.

## Diagnostic acceptance

The report may call the local counter diagnostic pass only when it has at least
two stable PPS snapshots with valid flags, strictly advancing sequence, TAI
increment equal to the PPS sequence delta, valid live-cycle monotonicity, and
at least one observed live cycle wrap.  Master/Slave same-boundary evidence is
reported separately; if the two captures have no shared TAI boundary, the
cross-board result is `INCONCLUSIVE`, not a pass.

No result from this experiment is Step6B trigger evidence.
