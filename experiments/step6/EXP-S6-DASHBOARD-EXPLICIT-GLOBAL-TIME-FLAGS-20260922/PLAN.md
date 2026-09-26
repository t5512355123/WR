# EXP-S6-DASHBOARD-EXPLICIT-GLOBAL-TIME-FLAGS-20260922

## Objective

Keep the successful bounded-wait behavior from the preceding experiment and
make each human-readable board panel print the exact validity bits explicitly:

```text
TIME_VALID=1 PPS_VALID=1
```

The panel must continue to show numeric `TAI` and `CYCLES` only after the
coherent snapshot gate passes.

## Allowed scope

Only `scripts/monitor/step1_6_dashboard.sh` presentation output is changed.
The fitted Step6 VHDL, WR core, PPS generator, firmware, MIF, QSF, SDC, PHY,
reset, SoftPLL, and all control parameters remain unchanged.

## Procedure

1. Laptop pushes the dashboard-only presentation change.
2. Pain pulls the exact commit, recompiles the existing fitted Master/Slave
   designs, and programs Slave then Master.
3. Without a physical power-cycle, run the bounded read-only dashboard.
4. Preserve the raw build/program/dashboard output, write the report, and push
   the experiment record.

## PASS criteria

Both board panels must visibly contain:

```text
Global-Time validity       TIME_VALID=1 PPS_VALID=1
TAI=<number> CYCLES=<number> VALID
```

The raw Tcl fields must also retain `SNAPSHOT_VALID=1`,
`SNAPSHOT_STABLE=1`, and numeric TAI/CYCLE values for both boards.

If either board remains invalid at the bounded-wait deadline, stop and record
the exact field that failed. Do not power-cycle or fabricate a fallback value.
