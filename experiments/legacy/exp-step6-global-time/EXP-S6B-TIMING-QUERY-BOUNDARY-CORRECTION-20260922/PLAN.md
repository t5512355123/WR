# EXP-S6B-TIMING-QUERY-BOUNDARY-CORRECTION-20260922

## Purpose

This is an offline post-fit STA correction for the previous Step6B run.  It
does not test hardware and does not recompile or reprogram anything.  The
question is only whether the already-fitted `c24568e3` scheduler has
provable synchronous setup/hold timing in the existing `qsfp_ref_125m`
domain.

## Fixed provenance

The checker must use the existing post-fit databases and artifacts from:

```text
SOURCE_COMMIT=c24568e383be3355ac8684b7d13f293115931586
SLAVE_SOF=66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151
MASTER_SOF=1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5
```

The VHDL, QSF, SDC, MIF, and SOF hashes must match the previous build
record.  Any mismatch stops with `NOT_RUN_POSTFIT_PROVENANCE_MISMATCH`.

## Allowed changes

Only the timing checker, offline analysis/tests, and this experiment's
documentation/raw output may change.  The checker correction uses
`get_path_info $path -slack` and preserves path provenance.  No RTL, SDC,
QSF, MIF, firmware, or hardware action is allowed.

## Required path set

The checker evaluates all nine groups on both Master and Slave:

```text
P1 target_meta_to_sync
P2 target_sync_to_latched
P3 arm_meta_to_sync
P4 arm_sync_to_prev
P5 refclk_to_armed
P6 refclk_to_fired
P7 refclk_to_fire_count
P8 refclk_to_actual_tai
P9 refclk_to_actual_cycles
```

P1–P4 are explicit register-to-register boundaries.  The asynchronous JTAG
source to the first `*_meta` register is not treated as an ordinary STA
path.  P5–P9 use `-from_clock qsfp_ref_125m -to_clock qsfp_ref_125m` and the
specific Step6B destination register group.

Every group must have matched endpoints, non-empty setup and hold path
collections, numeric slack, non-negative worst setup/hold slack, and
`from_clock`/`to_clock` provenance containing `qsfp_ref_125m`.

## Stop conditions

This experiment stops immediately after both offline STA queries finish.
There is no compile, firmware build, programming, reset, PTP restart, or
power cycle.  A corrected query that still has empty/invalid paths is
`NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED`; a real negative slack is
`FAIL_STEP6B_POSTFIT_TIMING`; all nine groups passing on both images is
`PASS_STEP6B_POSTFIT_TIMING_PROVEN`.

No result from this experiment by itself programs the boards.  A timing PASS
only authorizes adviser review before a separate Step6B-1 hardware run.
