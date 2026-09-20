# EXP-S5-RX-CAL-STAT-CDC-FIX-20260920

## Objective

Correct the one source-proven unsafe RX-to-SYS crossing found by the
`EXP-S5-FAST100C-RX2SYS-CDC-INTENT-AUDIT-20260920` audit:

```text
ep_rx_pcs_8bit:mdio_wr_spec_rx_cal_stat_o
    -> ep_mdio_regs:wb_o.dat[1]
```

This status is a level generated in `phy_rx_clk_i` and read by the
system-clock MDIO/Wishbone logic.  The only production change allowed in this
experiment is a standard two-flop `gc_sync` level synchronizer.

## Frozen scope

Only this RTL file may change:

```text
vendor/wr-cores/modules/wr_endpoint/ep_rx_pcs_8bit.vhd
```

The allowed diff is:

```text
p_detect_cal writes an internal RX-domain raw status signal
one gc_sync instance clocks it with clk_sys_i
the existing output is driven by the synchronizer result
```

Do not change calibration detection, counter width/threshold, reset logic,
MDIO protocol, other endpoint RTL, SDC, QSF, firmware, PI/gain, threshold,
timeout, PLL, or control behavior.

## Laptop gate

Run `scripts/rx_cal_stat_cdc_source_test.ps1` from the repository root.  It
must prove:

```text
RX_CAL_STAT_SOURCE_DOMAIN             = phy_rx_clk_i
RX_CAL_STAT_RAW_SIGNAL                = mdio_wr_spec_rx_cal_stat_rx
RX_CAL_STAT_DESTINATION_SYNCHRONIZER  = one gc_sync at clk_sys_i
MDIO_OUTPUT_DRIVER_COUNT              = one q_o driver
DIRECT_RAW_RX_TO_MDIO_OUTPUT          = removed
```

Any forbidden timing or unrelated production change stops the experiment
before push.

## Pain action

After pull, clean-compile both `DE5a_wr_master_jtag` and
`DE5a_wr_slave_jtag`, then run the Fast 900 mV/100 C RX-to-SYS timing audit.
Do not program either FPGA, reset, power-cycle, or perform hardware
observation in this experiment.

The acceptance is source-backed, not an overall-WNS requirement:

```text
direct phy_rx_clk_i status -> Wishbone read-data path = absent
raw status -> gc_sync|sync0 -> gc_sync|sync1 -> output = present
gc_sync|sync0 -> gc_sync|sync1 = still timed
MASTER_UNSAFE_OR_UNRESOLVED_CDC = 0
SLAVE_UNSAFE_OR_UNRESOLVED_CDC  = 0
UNCLASSIFIED_PATH_COUNT          = 0
```

The overall Fast100C hold boundary may remain open and WNS may remain
negative; that does not by itself fail this CDC-correctness experiment.

## Stop condition

After both clean compiles, the timing audit, source-backed classification,
and report/checksum capture complete, stop.  Do not add timing exceptions or
start a new timing boundary in this experiment.
