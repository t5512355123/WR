# EXP-S5-RX2SYS-FIRST-STAGE-GC-SYNC-FFS-CONSTRAINT-FIX-20260920

## Objective

Close only the remaining first-stage RX/PMA-to-SYS CDC timing boundary found
in the previous experiment.  The previous narrow exception covered
`gc_sync` and `gc_sync_register`, but the fitted hierarchy also contains the
source-proven two-stage `gc_sync_ffs` primitive.  This experiment adds only
that missing elaborated hierarchy pattern:

```text
rx_clkout / rx_pma_clk -> gc_sync_ffs|sync0
```

The `sync0 -> sync1` paths and all protocolled multibit paths must remain
timed.

## Frozen scope

The only production files allowed to change are:

```text
quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc
quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc
```

The only production change is adding this destination pattern to the
existing first-stage collection in both files:

```tcl
{*|gc_sync_ffs:*|sync0*}
```

Do not change RTL, QSF, firmware, PI/Kp/Ki, thresholds, timeouts, detector,
anti-windup, bootstrap, arbiter, mailbox, PHY, reset, protocolled multibit
constraints, generated-clock constraints, or FPGA programming.

## Laptop source gate

The source test must prove, for both SDC files:

```text
one first-stage block only
rx_clkout and rx_pma_clk collections are unchanged
gc_sync, gc_sync_register, and gc_sync_ffs sync0 patterns are present
exactly two set_false_path commands remain
no sync1/protocolled destination/clock-group wildcard is present
RTL and QSF are unchanged
```

## Pain order

1. Pull this commit.
2. Apply the SDC to the existing fitted database and run collection/preflight.
3. Require the four previously remaining `gc_sync_ffs|sync0` negative paths to
   disappear before compiling.
4. Confirm the three representative `gc_sync_ffs` `sync0 -> sync1` chains
   remain timed, and the LCR-to-RX_CONFIG protocolled path remains timed.
5. Only then clean compile Master and Slave.
6. Run fresh Fast 900mV/100C RX-to-SYS classification and all four PVT corner
   summaries.
7. Save raw logs/checksums, write the report, push the evidence, and stop.

No FPGA programming, reset, power-cycle, or hardware observation is part of
this timing experiment.

## Acceptance

```text
MASTER_FIRST_STAGE_TIMED_NEGATIVE = 0
SLAVE_FIRST_STAGE_TIMED_NEGATIVE  = 0
MASTER_UNSAFE_OR_UNRESOLVED       = 0
SLAVE_UNSAFE_OR_UNRESOLVED        = 0
UNCLASSIFIED                       = 0
GC_SYNC_FFS_SYNC0_TO_SYNC1_TIMED  = PASS
PROTOCOLLED_MULTIBIT_STILL_TIMED  = PASS
```

The overall Fast100C WNS may remain negative.  If any first-stage negative
path remains after this candidate, stop without adding another wildcard.
