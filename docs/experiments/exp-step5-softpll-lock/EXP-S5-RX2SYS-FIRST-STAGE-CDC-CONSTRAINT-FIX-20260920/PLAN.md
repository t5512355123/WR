# EXP-S5-RX2SYS-FIRST-STAGE-CDC-CONSTRAINT-FIX-20260920

## Objective

Apply one narrowly scoped timing exception to the source-proven first-stage
WR synchronizer crossings:

```text
rx_clkout / rx_pma_clk
    -> gc_sync|sync0 or gc_sync_register|sync0
```

The purpose is to determine whether these intentional asynchronous crossings
can leave the negative timing set while preserving timing on `sync0 -> sync1`
and preserving all protocolled multibit paths.

## Frozen scope

The only production files allowed to change are:

```text
quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc
quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc
```

The previous RX calibration status RTL fix is retained unchanged:

```text
mdio_wr_spec_rx_cal_stat_rx
    -> U_sync_rx_cal_stat|sync0
    -> U_sync_rx_cal_stat|sync1
    -> mdio_wr_spec_rx_cal_stat_o
```

Do not change RTL, QSF, firmware, PI/Kp/Ki, thresholds, timeouts, detector,
anti-windup, bootstrap, arbiter, mailbox, PHY, reset, or FPGA programming.

The new SDC block must:

```text
resolve exactly one rx_clkout clock
resolve exactly one rx_pma_clk clock
resolve a non-empty gc_sync/gc_sync_register sync0 collection
set false paths only from those two launch-clock collections to sync0
```

It must not use `set_clock_groups`, a whole RX-to-SYS exception, a `sync1`
destination, or any protocolled multibit destination.

## Laptop gate

Run `scripts/first_stage_cdc_sdc_source_test.ps1`.  The test must prove that
both SDC files contain exactly one first-stage block, that the block has two
false paths with the intended destination patterns, and that the RTL/QSF
production files are unchanged.

## Pain flow

After pull, run the SDC collection preflight before any clean compile.  The
preflight must report:

```text
rx_clkout collection = 1
rx_pma_clk collection = 1
sync0 collection > 0
empty collection = 0
ignored exception = 0
```

Only after that gate passes:

```text
clean compile Master
clean compile Slave
Fast100C RX->SYS audit
representative sync0->sync1 timing checks
protocolled multibit timing checks
all-corner setup/hold/recovery/removal summary
```

Do not program either FPGA.

## Acceptance

```text
CDC_FIRST_STAGE_TIMED_NEGATIVE = 0 for Master and Slave
UNSAFE_OR_UNRESOLVED_CDC       = 0
UNCLASSIFIED                   = 0
sync0->sync1 setup path found  = yes
sync0->sync1 hold path found   = yes
protocolled multibit paths     = still timed
```

The overall Fast100C WNS may remain negative and `STEP5` may remain `NO`.
Do not add a second wildcard exception if the first-stage result is not as
expected.

## Stop condition

After source gate, SDC preflight, both clean compiles, fresh Fast100C audit,
representative scope checks, all-corner summary, and checksums are recorded,
stop.  No FPGA programming, reset, power-cycle, or hardware observation is
part of this experiment.
