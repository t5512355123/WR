# EXP-S6-CURRENT-DASHBOARD-GATE-20260930 — Report

## Verdict

```text
DASHBOARD_READ_ONLY       = PASS
MASTER_GLOBAL_TIME       = VALID_STABLE
SLAVE_GLOBAL_TIME        = VALID_STABLE
SLAVE_FIVE_LOCK_BITS     = HIGH
SLAVE_WR_SERVO_STATE     = WAIT_OFFSET_STABLE
SLAVE_WR_SERVO_OFFSET_PS = -3779
STEP6_OFFSET_GATE        = NOT_QUALIFIED
```

The dashboard opened and completed a one-shot read successfully, but the
Slave offset did not meet the strict `abs(offset) < 60 ps` condition. Step 6
therefore remains incomplete. The global-time and lock observations are
positive; they do not override the failed offset gate.

## Provenance and procedure

- Pain active checkout: `/home/b10504072/04_WR`.
- Branch and source commit: `feat/file_cleanup`,
  `8df3dfcc97a6524b0e4c369fc91a03f2f7bd8f48`.
- The process list showed no competing JTAG/dashboard reader immediately
  before this run.
- Command settings: one-shot read, 2000 ms per-board comparison window,
  zero host-side Global-Time wait, no screen clearing.
- No build, programming, reset, PPS write, or controller change was made.
- Raw console output:
  [`dashboard_once_20260929T203348Z.log`](raw/observe/dashboard_once_20260929T203348Z.log).

## Observed signals

- Master: Step 1, Step 2, Step 4 PASS; Global Time VALID; `TIME_VALID=1`,
  `PPS_VALID=1`, snapshot valid/stable; TAI 29189. Master Step 5 is not
  applicable to its role.
- Slave: Step 1–4 PASS; Global Time/PPS valid; snapshot valid/stable; all five
  Step 5 lock bits high (`Helper=1`, `MainFreq=1`, `MainPhase=1`,
  `MainLock=1`, `PSTAT=1`).
- Slave servo state was `WAIT_OFFSET_STABLE`; offset was −3779 ps. The dashboard
  correctly displayed Step 6 `NOT QUALIFIED` and `PTP servo offset not yet
  <60 ps`. The sampled Slave TAI was 29194.

Dashboard board observations are read sequentially, not atomically. The TAI
values are not a same-cycle Master/Slave comparison. This capture is a single
point-in-time gate check, not stability evidence, causal diagnosis, or a
physical output-skew measurement.
