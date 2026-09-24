# EXP-S6-DASHBOARD-GLOBAL-TIME-VALIDITY-GATE-20260922

## Objective

Make the operator dashboard reliably show `TIME_VALID`, `PPS_VALID`, `TAI`,
and `CYCLES` after a fresh compile/program or recovered QSFP-A link, without
mistaking the short WR-extension startup interval for a source failure.

## Source basis

Use the current fitted Step6 source on
`exp/step6-Global-Time-Testing`, which is the source used by the prior
successful same-PPS Global-Time milestone. Do not replace the fitted Global-
Time snapshot, WR core wiring, PPS logic, or Step5 control code.

## One allowed change

Modify only `scripts/monitor/step1_6_dashboard.sh` to add an optional,
read-only bounded wait:

```text
WAIT_FOR_GLOBAL_TIME_SECONDS > 0
```

The wait succeeds only when every visible board has:

```text
TIME_VALID=1
PPS_VALID=1
SNAPSHOT_VALID=1
SNAPSHOT_STABLE=1
TAI != INVALID
CYCLES != INVALID
```

No FPGA/Wishbone/ARM/VUART write is added. The default remains unchanged when
the variable is zero.

## Hardware procedure

1. Laptop pushes this dashboard-only change.
2. Pain pulls the exact commit, compiles the existing fitted Master/Slave
   JTAG images, and programs Slave then Master.
3. Without power-cycle or reset, run the dashboard once with a bounded
   read-only wait (maximum 120 seconds).
4. Preserve the complete raw dashboard output and the wait/exit status.
5. Write the report under this experiment directory and push it.

## PASS / stop conditions

PASS requires one bounded-wait run in which both boards display valid
`TIME_VALID/PPS_VALID/SNAPSHOT_VALID/SNAPSHOT_STABLE` and numeric `TAI/CYCLES`.
The report must retain the actual displayed values and source/SOF provenance.

If the timeout expires, stop without another program or power-cycle and record
which board/field stayed invalid. If the link is absent, classify the run as
upstream/source recovery failure and preserve the raw evidence; do not hide it
by printing a fabricated time.
