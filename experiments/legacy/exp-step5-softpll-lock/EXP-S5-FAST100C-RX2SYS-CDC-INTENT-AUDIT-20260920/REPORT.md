# EXP-S5-FAST100C-RX2SYS-CDC-INTENT-AUDIT-20260920

## Verdict

```text
LAPTOP_AUDIT_SOURCE_TEST                  = PASS
PAIN_PULL                                  = PASS
QUARTUS_VERSION                            = 17.0.0 Build 595
TIMING_CORNER                              = fast_900mV_100C
SYSCLK625_COLLECTION_MASTER               = 1
SYSCLK625_COLLECTION_SLAVE                = 1
CDC_INTENT_DB_REPRODUCTION                = PASS
MASTER_SYSCLK625_WNS                       = -0.502 ns
SLAVE_SYSCLK625_WNS                        = -0.486 ns
MASTER_NEGATIVE_PATHS                      = 113
SLAVE_NEGATIVE_PATHS                       = 114
MASTER_CDC_FIRST_STAGE                     = 78
SLAVE_CDC_FIRST_STAGE                      = 79
MASTER_CDC_PROTOCOLLED_MULTIBIT            = 35
SLAVE_CDC_PROTOCOLLED_MULTIBIT             = 34
MASTER_TRUE_SYNCHRONOUS                    = 0
SLAVE_TRUE_SYNCHRONOUS                     = 0
MASTER_UNSAFE_OR_UNRESOLVED_CDC            = 0
SLAVE_UNSAFE_OR_UNRESOLVED_CDC             = 1
MASTER_UNCLASSIFIED_PATH_COUNT             = 0
SLAVE_UNCLASSIFIED_PATH_COUNT              = 0
CDC_INTENT_AUDIT                           = COMPLETE_WITH_ONE_UNSAFE_SLAVE_CDC
FAST100C_SYSCLK625_HOLD_BOUNDARY           = OPEN
FULL_TIMING_CLOSED                         = NO
FUNCTIONAL_MAIN_PHASE_LOCK_120S            = PASS (prior validated experiment)
FUNCTIONAL_STEP5_LOCK                      = PASS (prior validated experiment)
STEP5                                      = NO (timing closure pending)
RECOMPILE                                  = NOT_PERFORMED
FPGA_PROGRAMMING                           = NOT_PERFORMED
POWER_CYCLE                                = NOT_PERFORMED
HARDWARE_OBSERVATION                       = NOT_PERFORMED
```

The adviser’s latest instruction was to classify every negative RX-to-SYS
hold path by CDC intent before selecting a timing fix.  That instruction is
satisfied: Master 113/113 and Slave 114/114 are classified, with zero
unclassified paths.  The detailed family table and source justification are
in [`analysis/intent_classification.md`](analysis/intent_classification.md).

## Scope and frozen baseline

This was a read-only TimeQuest audit of the existing fitted databases from
build commit:

```text
54919aa7b9a4048228d6f121a205898c804e1aee
```

The audit source/plan commit was `5dc6ff3a`.  Quartus reconstructed the Fast
900 mV/100 C timing netlist for Master revision `DE5a_wr_master_jtag` and
Slave revision `DE5a_wr_slave_jtag`, then queried the exact system clock:

```text
u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk
```

No RTL, C, firmware, SDC, QSF, PI/gain, threshold, timeout, detector,
anti-windup, bootstrap, arbiter, mailbox, PHY, reset, control branch, fitter,
FPGA image, or hardware state was changed.

## Reproduction gate

The raw TimeQuest reports reproduced the requested baseline exactly:

```text
Master: 113 violated hold paths, WNS = -0.502 ns
Slave:  114 violated hold paths, WNS = -0.486 ns
```

The local raw checksum verification passed:

```text
RAW_CHECKSUM_VERIFY = PASS
```

The complete full-path reports, summary reports, TimeQuest logs, context, and
checksums are under `raw/`.

## Classification result

The 227 negative paths break down as:

```text
CDC_FIRST_STAGE          = 157
CDC_PROTOCOLLED_MULTIBIT = 69
TRUE_SYNCHRONOUS         = 0
UNSAFE_OR_UNRESOLVED_CDC = 1
UNCLASSIFIED              = 0
```

The worst path in each image is the DMTD diagnostic Gray-counter bit entering
the first stage of `gc_sync_register`:

| Image | From | To | Slack | Launch clock | Latch clock |
| --- | --- | --- | ---: | --- | --- |
| Master | `dbg_native_edge_count_gray[7]` | `U_sync_dbg_native_edge_count|sync0[7]` | -0.502 ns | recovered `rx_clkout` | `u_sys_clk_625` |
| Slave | `dbg_native_edge_count_gray[55]` | `U_sync_dbg_native_edge_count|sync0[55]` | -0.486 ns | recovered `rx_clkout` | `u_sys_clk_625` |

The largest source-proven class is legitimate first-stage CDC.  The
protocolled multibit class includes the stable LCR configuration bus and the
packet-filter result bus, whose completion event is synchronized separately.
Those paths must not be merged into a wildcard exception for ordinary
synchronizers.

One Slave path is different and remains an RTL CDC concern:

```text
ep_rx_pcs_8bit:mdio_wr_spec_rx_cal_stat_o
    -> ep_mdio_regs:wb_o.dat[1]
slack = -0.081 ns
```

The source drives this bit in the recovered RX clock and wires it directly
into system-clock Wishbone read data.  The path is classified as
`UNSAFE_OR_UNRESOLVED_CDC`; it was not hidden with a timing exception and was
not modified in this experiment.

## Interpretation and stop

The previous `MIXED` ownership result can now be refined by CDC intent, but
this is not timing closure.  In particular, 157 first-stage synchronizer
paths are not ordinary synchronous hold paths, while the 69 protocolled
multibit paths still require protocol-aware treatment.  The single unsafe
Slave path requires a real CDC correctness decision before any closure claim.

This experiment stops here as instructed.  It does not authorize or perform
any false path, clock-group, min/max-delay, multicycle, RTL synchronizer,
delay-chain, fitter, compile, program, reset, power-cycle, or hardware
observation action.  Overall repository `STEP5` remains `NO` pending timing
closure and resolution of the remaining timing/CDC boundaries.

## Evidence

```text
PLAN.md
scripts/rx2sys_cdc_intent_audit.tcl
analysis/intent_classification.md
raw/master/master_rx2sys_hold_top20_full.rpt
raw/master/master_rx2sys_hold_all_negative_full.rpt
raw/master/master_rx2sys_hold_all_negative_summary.rpt
raw/slave/slave_rx2sys_hold_top20_full.rpt
raw/slave/slave_rx2sys_hold_all_negative_full.rpt
raw/slave/slave_rx2sys_hold_all_negative_summary.rpt
raw/master_quartus_sta.log
raw/slave_quartus_sta.log
raw/pain-context.txt
raw/artifact-sha256.txt
```

Final stop condition:

```text
Master WNS/count reproduced and 113/113 classified
Slave WNS/count reproduced and 114/114 classified
UNCLASSIFIED_PATH_COUNT = 0
```
