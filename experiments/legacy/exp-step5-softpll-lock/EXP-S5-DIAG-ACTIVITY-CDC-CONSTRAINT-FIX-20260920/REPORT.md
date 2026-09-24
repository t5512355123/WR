# EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920

## Verdict

```text
LAPTOP_SDC_SOURCE_DIFF_TEST                    = PASS
DIAG_CDC_PAIR_COUNT_MASTER                    = 3
DIAG_CDC_PAIR_COUNT_SLAVE                     = 3
DIAG_ACTIVITY_CDC_CONSTRAINT_IMPLEMENTATION   = PASS
MASTER_CLEAN_COMPILE                          = PASS
SLAVE_CLEAN_COMPILE                           = PASS
DIAG_ACTIVITY_CDC_FALSE_PATH_EFFECT           = PASS
DIAG_ACTIVITY_CDC_SCOPE                       = PASS
CLK50_100C_DIAGNOSTIC_VIOLATION               = CLOSED
FULL_TIMING_CLOSED                            = NO
FUNCTIONAL_MAIN_PHASE_LOCK_120S               = PASS (prior validated experiment)
FUNCTIONAL_STEP5_LOCK                         = PASS (prior validated experiment)
STEP5                                         = NO
FPGA_PROGRAMMING                              = NOT_PERFORMED
POWER_CYCLE                                    = NOT_PERFORMED
```

The false-path candidate was accepted only for the already identified
diagnostic observer CDC. It did not close the complete design timing
requirement, so this experiment stops without programming either FPGA.

## Laptop change and source test

The only production-file changes were:

- `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc`
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc`

Both SDCs contain the same three exact source/destination pairs:

```text
ref_activity_toggle  -> ref_activity_meta
dmtd_activity_toggle -> dmtd_activity_meta
rx_activity_toggle   -> rx_activity_meta
```

Each pair is resolved with `get_registers -nowarn`, checked with
`get_collection_size`, and passed to one point-to-point
`set_false_path -from $src_regs -to $dst_regs`. There is no
`set_clock_groups`, no `*meta*` wildcard, no whole-clock exception, and no
production endpoint exception.

The laptop validator reported three pairs for each SDC and passed all
forbidden-pattern checks. The laptop commit was `54919aa7` and was pushed
before Pain pull.

## Pain build

Pain pulled commit `54919aa7` and ran the repository clean-build scripts:

```text
quartus_sh --clean DE5a_wr_master_jtag.qpf
quartus_sh --flow compile DE5a_wr_master_jtag.qpf
quartus_sh --clean DE5a_wr_slave_jtag.qpf
quartus_sh --flow compile DE5a_wr_slave_jtag.qpf
```

Both fitters reported successful completion and both wrapper scripts returned
exit code 0. The build used Quartus Prime 17.0.0 Build 595 and generated fresh
Master/Slave `.sof`, `.fit.summary`, and `.sta.rpt` artifacts. No programming
or power cycle was performed.

The SDC assertion did not emit
`DIAG_ACTIVITY_CDC_CONSTRAINT_TARGET_MISMATCH`; the independent TimeQuest
scope audit below also recorded every source, meta, sync, and prev collection
as `count=1` for both images.

## Constraint effect and scope audit

The new read-only TimeQuest audit used the fresh fitted databases at Slow
900mV 100C.

For Master and Slave, each of the following source-to-first-meta pairs
returned `No setup paths were found`:

```text
ref_activity_toggle  -> ref_activity_meta
dmtd_activity_toggle -> dmtd_activity_meta
rx_activity_toggle   -> rx_activity_meta
```

The resulting `clk_50m` Top-20 setup reports contained 20 paths with zero
violations:

```text
Master clk_50m WNS = +0.146 ns
Slave  clk_50m WNS = +0.220 ns
```

Most importantly, the synchronizer tails were still timed. All six paths per
image were found with zero violations:

```text
ref_activity_meta  -> ref_activity_sync
ref_activity_sync  -> ref_activity_prev
dmtd_activity_meta -> dmtd_activity_sync
dmtd_activity_sync -> dmtd_activity_prev
rx_activity_meta   -> rx_activity_sync
rx_activity_sync   -> rx_activity_prev
```

This proves the exception scope is point-to-point and stops at the first
metastability-capture register; it did not cut the synchronizer tail.

The complete evidence is retained in:

- `raw/scope/master_scope.log`
- `raw/scope/slave_scope.log`
- `raw/scope/*_clk50_setup_after_constraint_top20.rpt`
- `raw/scope/*_TO_*_setup.rpt`
- `raw/sta/DE5a_wr_master_jtag.sta.rpt`
- `raw/sta/DE5a_wr_slave_jtag.sta.rpt`
- `raw/build/master_quartus_compile.log`
- `raw/build/slave_quartus_compile.log`

## All-corner timing result

The fresh build reports all requested setup, hold, recovery, and removal
categories:

| Image | Corner | Setup | Hold | Recovery | Removal |
| --- | --- | ---: | ---: | ---: | ---: |
| Master | Slow 900mV 100C | +0.146 | +0.036 | +1.295 | +0.227 |
| Master | Slow 900mV 0C | -0.246 | +0.034 | +2.299 | -0.204 |
| Master | Fast 900mV 100C | +0.534 | -0.502 | +1.248 | +0.203 |
| Master | Fast 900mV 0C | +1.659 | +0.010 | +3.033 | +0.170 |
| Slave | Slow 900mV 100C | +0.188 | +0.034 | +0.751 | +0.248 |
| Slave | Slow 900mV 0C | -0.279 | +0.036 | +1.254 | -0.216 |
| Slave | Fast 900mV 100C | +0.437 | -0.486 | +1.581 | +0.206 |
| Slave | Fast 900mV 0C | +1.766 | +0.010 | +3.270 | +0.169 |

Therefore the overall design is not timing closed. The first remaining
boundary by worst slack is Fast 900mV 100C hold on the system PLL clock:

```text
NEXT_TIMING_BOUNDARY = FAST_900mV_100C_HOLD_u_sys_clk_625
```

Slow 900mV 0C also has a `qsfp_ref_125m` setup violation, and both images
still have six unconstrained clocks. The generated-clock target for
`wr_core_dmtd_62m496` remains an empty collection. None of those boundaries
was modified in this experiment.

## Final stop

This experiment answered exactly one question: whether the proven diagnostic
activity CDC can be excluded narrowly and safely. The answer is yes. The
functional lock result remains the previously established PASS, but overall
Step5 remains NO until every timing corner, exception, and constraint-coverage
boundary is closed. Stop here; do not add another exception, edit the
`wr_core_dmtd_62m496` clock, fix `qsfp_ref_125m`, program, or power-cycle in
this experiment.

## Supplemental pre-pull archive

During the 2026-09-24 Pain home-directory archive audit, five supplemental
pre-pull files were recovered into `raw/pre-pull-raw-20260920/`: Master and
Slave STA summaries, Master and Slave fit summaries, and
`file-sha256.txt`. These are preserved as a separate historical capture;
they are not substituted for the fresh-build evidence listed above and do
not change this experiment's verdict or timing interpretation.
