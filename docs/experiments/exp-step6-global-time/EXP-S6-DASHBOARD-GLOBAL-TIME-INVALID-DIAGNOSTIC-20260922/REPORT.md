# EXP-S6-DASHBOARD-GLOBAL-TIME-INVALID-DIAGNOSTIC-20260922

## Result

The dashboard reader was corrected and verified on Pain.

```text
DASHBOARD_READABILITY = PASS
STEP_LINES_ARE_SEPARATE = PASS
GLOBAL_TIME_REASON_DISPLAY = PASS
BOTTOM_TAI_CYCLES_SUMMARY = PASS
```

## Why TAI/CYCLES were shown as INVALID

The earlier compact dashboard was not failing to decode a valid number. The
hardware state reported:

```text
Link=1
TM=1
STATUS_TIME_VALID=0
STATUS_PPS_VALID=0
SNAPSHOT_VALID=0
SNAPSHOT_STABLE=0
SNAPSHOT_COUNT=0
```

`Link=1` and `TM=1` only establish the WR timing link. They do not establish a
valid synchronized Global-Time epoch. In the diagnostic RTL, the PPS-boundary
snapshot is deliberately cleared whenever `core_tm_time_valid=0`; therefore
there is no trustworthy TAI/cycle tuple to print in this state.

The corrected dashboard now reports this as:

```text
Step 6  Global Time          WAITING
Global-Time reason           TIME_VALID=0, PPS_VALID=0
TAI=--                       CYCLES=--  WAITING
```

This prevents a zero or stale counter from being misreported as the current
global time. The PPS control/status raw values are also displayed for the next
diagnostic step.

## Pain verification

Branch commit tested:

```text
fcfa6bcd
```

Command:

```bash
ONCE=1 CLEAR_SCREEN=0 OBS_GAP_MS=2000 \
  ./scripts/monitor/step1_6_dashboard.sh
```

Both `DE5 [1-11.1]` and `DE5 [1-11.2]` were displayed. Every Step1--Step6
status was printed on its own line, followed by link health, SoftPLL lock
signals, PPS status, and a bottom Global-Time summary containing each board's
TAI/cycle fields.

Observed runtime state in this read-only session:

```text
Master: Link=1 TM=1, TIME_VALID=0, PPS_VALID=0, Step6=WAITING
Slave:  Link=1 TM=1, TIME_VALID=0, PPS_VALID=0, Step6=WAITING
Slave:  HelperLock=1, MainFreq=1, MainPhase=0, MainLock=0, PSTAT=0
```

The dashboard correctly leaves Step6 waiting and does not claim Step5 or
Global-Time functional PASS.

## Scope

Only the read-only Tcl dashboard output and its shell presentation were
modified. No FPGA source, control parameter, PPS/WR behavior, reset, or
programming operation was changed in this round.
