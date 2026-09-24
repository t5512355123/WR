# EXP-S5-RX2SYS-PROTOCOLLED-MULTIBIT-HOLD-CONSTRAINT-FIX-20260920

## Objective

Close only the source-proven RX-to-SYS bundled-data hold paths that remain
after the first-stage synchronizer boundary was closed. The candidate keeps
setup analysis active and excludes hold analysis only for the reviewed data
registers and their reviewed SYS-side consumers.

The two reviewed protocol families are:

```text
LCR / autonegotiation:
ep_rx_pcs_8bit.lcr_final_val[*]
    -> ep_autonegotiation.rx_config_reg[*], mdio_lpa_* and state*

Packet-filter result:
ep_packet_filter.pclass_int[*] / drop_int
    -> ep_packet_filter.pclass_o[*] / drop_o
```

## Allowed production change

Only these two SDC files may change:

```text
quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc
quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc
```

Each reviewed family uses only:

```tcl
set_false_path -hold -from <reviewed data registers> -to <reviewed consumers>
```

Setup analysis must remain present as a datapath guard.

## Forbidden changes

Do not modify RTL, QSF, firmware, SoftPLL, PI/Kp/Ki, thresholds, timeout,
bootstrap, detector, anti-windup, arbiter, mailbox, PHY, reset, control
branch, fitter options, generated-clock definitions, or any FPGA image.

Do not add a full false path, clock-group exception, multicycle path,
minimum/maximum delay, sync1 exception, or wildcard to the whole SYS domain.

## Required workflow

1. Laptop source gate and offline test.
2. Push the candidate to `exp/step5-softpll-lock`.
3. Pain pulls the exact commit.
4. Pain runs existing-fitted-DB preflight before clean compilation.
5. If preflight passes, Pain clean-compiles Master and Slave.
6. Pain runs fresh Fast 900 mV / 100 C RX-to-SYS audit and all four PVT
   setup/hold/recovery/removal summaries.
7. Save raw logs, reports, and checksums in this experiment directory.
8. Laptop records the report and pushes the evidence.

This is a timing-only experiment. FPGA programming, reset, power-cycle,
and hardware observation are forbidden in this round.

## Existing-DB preflight acceptance

The candidate must resolve all reviewed collections without empty or ignored
SDC commands. On the existing fitted database:

```text
MASTER_RX2SYS_HOLD_NEGATIVE = 0
SLAVE_RX2SYS_HOLD_NEGATIVE  = 0
```

The following setup paths must still be found:

```text
LCR -> rx_config_reg
LCR -> representative mdio_lpa_*
pclass_int -> pclass_o
drop_int -> drop_o
```

The `gc_sync_ffs` synchronizer downstream paths and the
`U_Sync_Done` pulse-synchronizer downstream paths must remain timed.

If any preflight gate fails, do not compile and stop the experiment as
`PROTOCOLLED_HOLD_EXCEPTION_PREFLIGHT=FAIL`.

## Fresh compile acceptance

After both clean compiles, classify the fresh Fast 900 mV / 100 C RX-to-SYS
hold report. The required boundary results are:

```text
MASTER_RX2SYS_FIRST_STAGE_NEGATIVE       = 0
SLAVE_RX2SYS_FIRST_STAGE_NEGATIVE        = 0
MASTER_RX2SYS_PROTOCOLLED_HOLD_NEGATIVE  = 0
SLAVE_RX2SYS_PROTOCOLLED_HOLD_NEGATIVE   = 0
MASTER_UNSAFE_OR_UNRESOLVED              = 0
SLAVE_UNSAFE_OR_UNRESOLVED               = 0
MASTER_UNCLASSIFIED                      = 0
SLAVE_UNCLASSIFIED                       = 0
LCR_SETUP_STILL_TIMED                    = PASS
PCLASS_SETUP_STILL_TIMED                 = PASS
DROP_SETUP_STILL_TIMED                   = PASS
EVENT_SYNC_DOWNSTREAM_TIMED              = PASS
```

If a new unrelated Fast100C global hold family appears, record its exact
worst path and stop; do not fix it in this experiment.

## Stop condition

Stop after Master/Slave clean compile, fresh RX-to-SYS classification,
scope guards, all-corner reports, unconstrained-clock summary, and DMTD
generated-clock target status are saved. This experiment does not by itself
change the functional Step5 verdict and does not require timing closure to
be declared.
