# EXP-S5-TIMING-ROOT-CAUSE-AUDIT-20260920

## Verdict

```text
FUNCTIONAL_MAIN_PHASE_LOCK_120S = PASS
FUNCTIONAL_STEP5_LOCK           = PASS
TIMING_CLOSED                   = NO
TIMING_ROOT_CAUSE               = MIXED_PROVISIONAL
EXACT_TOP20_PATH_OWNERSHIP      = INCONCLUSIVE
```

The functional Step5 lock result remains PASS according to the latest advisor
review: Main phase lock was retained for 120 seconds and the Ki1 integrator
was active. The overall milestone remains `STEP5 = NO` because timing closure
is still open.

## What was verified

The exact Pain TimeQuest artifacts were copied without changing the design:

- Pain HEAD: `5d7d1a46784581dd1396daeb5a24624b62b1c440`
- Master report timestamp: 2026-09-20 03:02:28 (Pain local time)
- Slave report timestamp: 2026-09-20 04:23:39 (Pain local time)
- Quartus Prime 17.0.0 Build 595
- Arria 10 `10AX115N2F45E1SG`

At the 100C slow setup corner:

```text
Master: WNS = -0.289 ns, TNS = -0.289 ns, clock = clk_50m
Slave : WNS = -0.361 ns, TNS = -0.361 ns, clock = clk_50m
```

This independently confirms the advisor's timing values and confirms that the
timing failure is not a missing functional PLL-lock observation. The 0C corner
is worse (`Master -0.701 ns`, `Slave -0.771 ns`) and also has negative
`qsfp_ref_125m` setup slack; those values are retained in
`analysis/sta_metrics.md` but are not substituted for the advisor's 100C
comparison.

## Root-cause classification

The static evidence points toward a mixed clock domain containing both
production logic and a large diagnostic/JTAG observation surface:

1. The only failing 100C clock summary is `clk_50m`.
2. The Master and Slave top-level diagnostic images instantiate 90 and 122
   `altsource_probe` source assignments respectively.
3. The top-level source snapshots contain 45 and 61 occurrences of
   `source_clk => CLK_50_B2J`, plus observer processes on that clock.
4. The map report contains the JTAG mailbox and WR diagnostics memory.

This is enough to classify the current hypothesis as:

```text
TIMING_ROOT_CAUSE = MIXED_PROVISIONAL
```

It is **not** enough to claim `DIAGNOSTIC_OBSERVABILITY` as proven, because the
exported timing report does not identify the failing endpoint or path cone.
Production `clk_50m` logic and diagnostic/JTAG logic share the same constrained
clock, so removing or relaxing a diagnostic path based on this evidence alone
would be premature.

## Top-20 path audit result

The requested Top-20 path fields are not present in the archived report
exports. The standard `.sta.rpt` contains summary tables and the `.sta.qmsg`
contains the same clock-level summaries and warnings; neither contains
`From Node`, `To Node`, `Data Required`, `Data Arrival`, or logic-level/cell
count records for the current failing paths. The `.sta.rdb` files are binary
database payloads, but Pain has no `quartus_sta` executable available to replay
them, and no path-level report was generated during the build.

Consequently, the audit deliberately records:

```text
MASTER_TOP20 = NOT_AVAILABLE
SLAVE_TOP20  = NOT_AVAILABLE
PATH_OWNERSHIP = UNRESOLVED
```

No historical August DMTD report was used as a substitute; it queried a
different path set and had positive slack.

## Additional timing-quality findings

Both builds report six unconstrained clocks. The STA log also records that the
SDC `create_generated_clock` for `wr_core_dmtd_62m496` matched an empty
collection, and that several clock-like nodes lack clock assignments. These
must be corrected or explicitly justified in a future timing-closure pass, but
this experiment made no constraint changes.

## Stop condition and next safe action

This read-only audit is complete and stops here. Do not recompile, reprogram,
power-cycle, tune PLL parameters, or edit RTL/SDC/QSF from this result.

The next safe action is another offline-only artifact generation step: use the
same TimeQuest database and exact build identity to export, for each image,
`report_timing -setup -npaths 20 -detail full` for the failing `clk_50m`
corner, including from/to nodes and data required/arrival times. Only after
that report exists should the classification be refined to
`DIAGNOSTIC_OBSERVABILITY` or `PRODUCTION_PATH` and a timing fix considered.
