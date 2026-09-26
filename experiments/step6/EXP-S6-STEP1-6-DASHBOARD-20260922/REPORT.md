# EXP-S6-STEP1-6-DASHBOARD-20260922

## Purpose

Validate a read-only Pain dashboard that presents the important Step1--Step6
signals for both DE5a boards and shows the current Global-Time `TAI` and
`CYCLES` values.

This is a dashboard/display validation only. It is not a new Step5 or Step6
functional-pass claim.

## Source and artifacts

- Branch: `exp/step6-Global-Time-Testing`
- Dashboard commit: `1f638813`
- Tcl reader: `scripts/jtag/read_step1_6_dashboard.tcl`
- Watch script: `scripts/monitor/step1_6_dashboard.sh`
- Reference clock: `125000000 Hz`
- Default watch interval: `10 s`
- Per-board read-only comparison window: `2000 ms`
- Wishbone/target writes: none

The dashboard reuses the existing runtime reader for Step1--Step5 semantics
and reads the fitted Global-Time probes 62--64 for `TIME_VALID`, `PPS_VALID`,
`TAI`, and `CYCLES`.

## Programming performed on Pain

Quartus Prime Programmer 17.0 was run directly (without `sudo`) after cable
visibility was confirmed. The validated order was Slave first, then Master:

```text
DE5 [1-11.2]  Slave
DE5 [1-11.1]  Master
```

SOF SHA-256 values:

```text
Slave  a39f315806251fe39b0d8ba62ac7a2b9aa908d9bae5593e771086f8978f02a49
Master b163ca1b084550e34335403fb168d68a3799799b14cfe527c25e9775be56cea1
```

Both programming operations reported `Configuration succeeded`,
`Successfully performed operation(s)`, and `0 errors, 0 warnings`.

## Dashboard observations

### Read-only smoke before programming

Command:

```bash
ONCE=1 CLEAR_SCREEN=0 OBS_GAP_MS=2000 INTERVAL_SECONDS=10 \
  ./scripts/monitor/step1_6_dashboard.sh
```

Both boards produced `DASHBOARD_BOARD` records and `DASHBOARD_DONE`.
The records included Step1--Step6 fields, link/TM/RX/TX fields,
`TIME_VALID`, `PPS_VALID`, `TAI`, and `CYCLES`.

Observed state:

```text
Master: Step1=PASS Step2=PASS Step6=PASS Link=1 TM=1 TIME_VALID=1 PPS_VALID=1
Slave:  Step1=PASS Step2=PASS Step6=PASS Link=1 TM=1 TIME_VALID=1 PPS_VALID=1
Slave:  HelperLock=1 MainFreq=1 MainPhase=1 MainLock=1 PSTAT=1
```

The two TAI values are read through separate JTAG transactions; their raw
values must not be treated as a same-cycle skew measurement. A later Step6
experiment should use the PPS-boundary snapshots for an explicit cross-board
time-delta test.

### Read-only smoke after programming

An immediate read showed the dashboard correctly reporting the startup state:

```text
Master: Link=0 TM=0 TIME_VALID=0 PPS_VALID=0 TAI=INVALID CYCLES=INVALID
Slave:  Link=0 TM=0 TIME_VALID=0 PPS_VALID=0 TAI=INVALID CYCLES=INVALID
```

After a fixed 30-second wait, the dashboard still showed the same upstream
WR-link-not-ready state. This is recorded as the current board state, not as a
dashboard failure:

```text
Master: Step1=FAIL Step2=INVALID Step4=PASS Step6=INFO Link=0 TM=0 RX=1 TX=1
Slave:  Step1=FAIL Step2=INVALID Step4=INFO Step6=INFO Link=0 TM=0 RX=1 TX=1
```

No additional programming or power-cycle was performed in this dashboard
validation run.

## Verdict

```text
DASHBOARD_DISPLAY = PASS
BOTH_BOARD_RECORDS = PASS
TAI_CYCLES_FIELDS = PASS
READ_ONLY_BEHAVIOR = PASS
POST_PROGRAM_WR_LINK = NOT_READY_WITHIN_30S
STEP5_FUNCTIONAL_RESULT = NOT_EVALUATED_IN_THIS_RUN
```

The dashboard is ready for operator use. The recommended default is one
sample every 10 seconds. A 5-second interval is supported, but shorter
activity windows can legitimately produce `INVALID` or `NA` for activity-based
diagnostics; those values are not converted into a hardware failure.
