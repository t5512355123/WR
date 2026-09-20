# RX calibration status CDC fix: intent classification

## Input and method

The input is the complete Fast 900 mV/100 C TimeQuest hold export terminating
at:

```text
u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk
```

Each negative row in the Master and Slave summary report was counted once.
Rows terminating at a destination `sync0[*]` were classified as
`CDC_FIRST_STAGE` only after the source RTL was checked for the corresponding
two-flop synchronizer.  Stable-data/event-qualified buses were classified as
`CDC_PROTOCOLLED_MULTIBIT`.  No timing exception was used to make a row pass.

## Classification totals

| CDC intent | Master | Slave | Worst slack observed |
| --- | ---: | ---: | ---: |
| `CDC_FIRST_STAGE` | 80 | 81 | Master -0.483 ns; Slave -0.487 ns |
| `CDC_PROTOCOLLED_MULTIBIT` | 34 | 33 | covered by the existing source protocols |
| `TRUE_SYNCHRONOUS` | 0 | 0 | n/a |
| `UNSAFE_OR_UNRESOLVED_CDC` | 0 | 0 | n/a |
| `UNCLASSIFIED` | 0 | 0 | n/a |
| **Total negative paths** | **114** | **114** | — |

The counts differ slightly from the previous fitted database because the
design was freshly placed and routed.  The old 113/114 counts are not used as
a fixed acceptance target for this corrected build.

## Corrected status crossing

The only production RTL change was in
`vendor/wr-cores/modules/wr_endpoint/ep_rx_pcs_8bit.vhd`:

```text
p_detect_cal : process(phy_rx_clk_i)
    writes mdio_wr_spec_rx_cal_stat_rx

U_sync_rx_cal_stat : entity work.gc_sync
    clk_i => clk_sys_i
    d_i   => mdio_wr_spec_rx_cal_stat_rx
    q_o   => mdio_wr_spec_rx_cal_stat_o
```

The source test passed with:

```text
RX_CAL_STAT_SOURCE_DOMAIN=1
RX_CAL_STAT_RAW_SIGNAL=1
RX_CAL_STAT_RAW_WRITES=1
RX_CAL_STAT_DESTINATION_SYNCHRONIZER=1
RX_CAL_STAT_SYNC_CLOCK=1
RX_CAL_STAT_SYNC_INPUT=1
RX_CAL_STAT_SYNC_OUTPUT=1
DIRECT_RAW_RX_TO_MDIO_OUTPUT_REMOVED=1
FORBIDDEN_TIMING_EDIT_ABSENT=1
RX_CAL_STAT_CDC_IMPLEMENTATION=PASS
```

The `gc_sync` source is the standard two-flop level synchronizer: `sync0`
captures the RX-domain level, `sync1` captures `sync0`, and `q_o` is driven by
`sync1`.  There is one driver for the MDIO output and no direct raw RX-domain
assignment to that output.

## Targeted TimeQuest evidence

The targeted STA found exactly one raw register, one `sync0`, and one `sync1`
in each image:

```text
RX_CAL_STAT_RAW_REGISTER_COUNT=1
RX_CAL_STAT_SYNC0_REGISTER_COUNT=1
RX_CAL_STAT_SYNC1_REGISTER_COUNT=1
```

The relevant Fast 900 mV/100 C paths were:

| Image | raw -> sync0 hold | sync0 -> sync1 setup | sync0 -> sync1 hold |
| --- | ---: | ---: | ---: |
| Master | +0.322 ns | +15.692 ns | +0.027 ns |
| Slave | -0.138 ns | +15.339 ns | +0.317 ns |

The Slave `-0.138 ns` path is now the expected first synchronizer stage,
not a direct RX-domain-to-Wishbone data path.  The `sync0 -> sync1` path is
present and positively timed in both images.

The corrected Slave negative-path export contains:

```text
mdio_wr_spec_rx_cal_stat_rx
    -> gc_sync:U_sync_rx_cal_stat|sync0
```

It no longer contains the previous unsafe path:

```text
mdio_wr_spec_rx_cal_stat_o -> ep_mdio_regs:wb_o.dat[1]
```

## Conclusion

```text
RX_CAL_STAT_CDC_FIX                 = PASS
MASTER_UNSAFE_OR_UNRESOLVED_CDC     = 0
SLAVE_UNSAFE_OR_UNRESOLVED_CDC      = 0
MASTER_UNCLASSIFIED                 = 0
SLAVE_UNCLASSIFIED                  = 0
SYNC0_TO_SYNC1_TIMED                = PASS
FAST100C_SYSCLK625_HOLD_BOUNDARY    = OPEN
```

This is a CDC-correctness milestone, not overall timing closure.  The overall
Step5 timing gate remains open because the fitted images still contain
negative Fast100C hold slack.
