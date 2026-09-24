# EXP-S5-RX-CAL-STAT-CDC-FIX-20260920

## Verdict

```text
LAPTOP_SOURCE_GATE                         = PASS
PAIN_PULL                                  = PASS
MASTER_CLEAN_COMPILE                      = PASS (0 errors)
SLAVE_CLEAN_COMPILE                       = PASS (0 errors)
MASTER_FAST100C_RX2SYS_STA                = PASS (tool completed)
SLAVE_FAST100C_RX2SYS_STA                 = PASS (tool completed)
MASTER_TARGETED_SYNC_STA                  = PASS
SLAVE_TARGETED_SYNC_STA                   = PASS
MASTER_UNSAFE_OR_UNRESOLVED_CDC           = 0
SLAVE_UNSAFE_OR_UNRESOLVED_CDC            = 0
MASTER_UNCLASSIFIED_PATH_COUNT            = 0
SLAVE_UNCLASSIFIED_PATH_COUNT             = 0
RX_CAL_STAT_CDC_FIX                       = PASS
FAST100C_SYSCLK625_HOLD_BOUNDARY          = OPEN
OVERALL_STEP5                             = NO (timing closure pending)
FPGA_PROGRAMMING                          = NOT_PERFORMED
RESET                                     = NOT_PERFORMED
POWER_CYCLE                               = NOT_PERFORMED
HARDWARE_OBSERVATION                      = NOT_PERFORMED
```

The experiment successfully removed the one source-proven unsafe RX-to-SYS
status crossing and replaced it with a standard two-flop level synchronizer.
It did not prove overall Step5, because the full fitted images still have
negative Fast100C hold slack.

## Scope

Only this production RTL file changed:

```text
vendor/wr-cores/modules/wr_endpoint/ep_rx_pcs_8bit.vhd
```

The functional calibration detector, reset behavior, MDIO protocol, SoftPLL,
PI/gain, threshold, timeout, bootstrap, arbiter, mailbox, PHY, SDC, QSF, and
control flow were left unchanged.  The implementation was:

```text
phy_rx_clk_i p_detect_cal
    -> mdio_wr_spec_rx_cal_stat_rx
    -> gc_sync(U_sync_rx_cal_stat) clocked by clk_sys_i
    -> mdio_wr_spec_rx_cal_stat_o
    -> existing MDIO/Wishbone read path
```

The laptop source gate and the complete output are in
[`analysis/intent_classification.md`](analysis/intent_classification.md).

## Build and STA evidence

The RTL build used Pain source commit:

```text
e4c788bdc5e85964857d0504e91545b8cc15fd30
```

The audit scripts were subsequently committed and pushed as:

```text
e4c788bdc5e85964857d0504e91545b8cc15fd30
4baa7116b93b2920936611f47143d721bf37382f
```

Both DE5a revisions were clean-compiled with Quartus Prime 17.0 Build 595.
The compile logs report 0 errors for both images.  The Fast 900 mV/100 C
RX-to-SYS audit found:

| Image | Negative paths | Worst slack | First-stage CDC | Protocolled multibit | Unsafe | Unclassified |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Master | 114 | -0.483 ns | 80 | 34 | 0 | 0 |
| Slave | 114 | -0.487 ns | 81 | 33 | 0 | 0 |

The targeted synchronizer audit found one raw register, one `sync0`, and one
`sync1` in each image.  Its timing was:

| Image | raw -> sync0 hold | sync0 -> sync1 setup | sync0 -> sync1 hold |
| --- | ---: | ---: | ---: |
| Master | +0.322 ns | +15.692 ns | +0.027 ns |
| Slave | -0.138 ns | +15.339 ns | +0.317 ns |

The Slave negative path is now the legitimate first synchronizer stage.  The
previous direct `mdio_wr_spec_rx_cal_stat_o -> ep_mdio_regs:wb_o.dat[1]`
crossing is absent from the corrected source and negative-path classification.

## Required stop

This experiment is complete and stops here.  No FPGA was programmed, and no
reset, power cycle, or hardware observation was performed.  No timing
exception was added.  The next action requires a new adviser-directed
experiment for the remaining RX-to-SYS timing boundary; this report does not
authorize treating the CDC fix as Step5 PASS.

## Evidence files

```text
PLAN.md
scripts/rx_cal_stat_cdc_source_test.ps1
scripts/rx2sys_cdc_intent_audit.tcl
scripts/rx_cal_stat_sync_sta.tcl
analysis/intent_classification.md
raw/master/master_clean.log
raw/master/master_compile.log
raw/master/sta/*
raw/slave/slave_clean.log
raw/slave/slave_compile.log
raw/slave/sta/*
raw/source_test.txt
raw/pain-context.txt
raw/source_commit.txt
raw/sta_sha256.txt
```
