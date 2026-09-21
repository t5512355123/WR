# EXP-S6-SLAVE-PTP-RESTART-WR-EXTENSION-RECOVERY-20260922

## Verdict

```text
RESULT=FAIL_TRANSIENT_GLOBAL_TIME_RECOVERY
FAILURE_CLASS=GLOBAL_TIME_RECOVERY_STREAK_OR_COUNTER_INSUFFICIENT
STEP6A_1=NOT_PASS
STEP6A_GLOBAL_TIME=NOT_PASS
STEP6B=NOT_RUN
```

This is not a Step6A pass. The single Slave PTP restart re-entered the WR
extension path and the pre-existing SoftPLL-ready state remained intact, but
Global Time became valid only in the final sample and never formed the
required stable five-sample window.

## Provenance and protocol

```text
BRANCH=exp/step6-Global-Time-Testing
SOURCE_COMMIT=ef3abbca98c1be97fa0be268d99101fd2b637359
PAIN_WORKTREE=/home/b10504072/04_WR/pain-worktrees/step6-global-time
MASTER_COMPILE=NO
SLAVE_COMPILE=NO
MASTER_PROGRAM=NO
SLAVE_PROGRAM=NO
POWER_CYCLE=NO
CPU_RESET=NO
WR_CORE_RESET=NO
PHY_RESET=NO
MASTER_PTP_RESTART=NO
SLAVE_PTP_RESTART=EXACTLY_ONCE
MODE_COMMAND=NO
FIBER_QSFP_CHANGE=NO
AUTONEG_SI5340_MDIO_CHANGE=NO
```

The observer sent exactly one `ptp stop\n` and one `ptp start\n` to Slave.
All bytes returned `WB_RESULT=1`; Master received no command:

```text
SLAVE_PTP_STOP_COUNT=1
SLAVE_PTP_START_COUNT=1
MASTER_COMMAND_COUNT=0
```

## Pre-restart gate

The five paired pre-restart samples all passed. Master stayed link-ready with
`PTP_STATE=6` and `TIME_VALID=1`. Slave stayed in the validated pre-restart
state with `PTP_STATE=9`, `PD_STATE=4`, `EXT_STATE=2`, `WRC_MODE=3`,
`TIME_VALID=0`, `SPLL_SEQ_STATE=8`, `PSTAT_LOCKED=1`, and `MAIN_LOCKED=1`.
Boot generation, CPU reset, WR-core reset, and SI-config-drop counters did not
change during the experiment.

```text
GATE_RESULT=PASS
GATE_PAIRS=5
```

## Recovery observation

The post-start window contained 25 paired samples over approximately 30.7 s.
Every captured row was read-valid and capture-healthy; no reset change was
observed. The first sample was obtained at 0 ms after the final start newline.

WR-extension progress was observed:

```text
SLAVE_REARM_EVIDENCE=1 at 6191 ms
  Slave EXT_STATE=1 (active)
  Slave WR_STATE_VALUE=2 (WRS_S_LOCK)

MASTER_REENGAGEMENT_EVIDENCE=1 at 6191 ms
  Master EXT_STATE=1 (active)
```

The Slave SoftPLL was not disturbed: the post-start capture remained at
`SPLL_SEQ_STATE=8`, `PSTAT_LOCKED=1`, and `MAIN_LOCKED=1` without the required
three-sample bad streak.

Global-Time evidence did not satisfy the formal gate:

```text
Slave samples 0..23: STATUS_TIME_VALID=0,
                     SNAPSHOT_VALID=0,
                     SNAPSHOT_COUNT=0
Slave sample 24 at 29772 ms:
  STATUS_TIME_VALID=1
  SNAPSHOT_VALID=1
  SNAPSHOT_TIME_VALID=1
  SNAPSHOT_PPS_VALID=1
  SNAPSHOT_COUNT=1
```

Therefore:

```text
BEST_TIME_STREAK=1
FORMAL_CANDIDATE_WINDOW_COUNT_ADVANCES=0
FORMAL_GLOBAL_TIME_RECOVERY=FAIL
```

The raw snapshot count moved from its invalid-window value of 0 to 1 once,
but there was no five-sample candidate window in which the counter could
advance twice. The late single valid snapshot is evidence of a transient/late
recovery event, not evidence that the two boards have a usable stable
Global-Time source.

## Stored evidence

```text
raw/observe/ptp_restart_recovery.log
  SHA256=170D11ADB85C9F6FD93906D1B2BF3AFC8FB5D0F7E683D316B54FC8BEC91B58F4

analysis/summary.json
  SHA256=65E84C4CA71B832F65CC1109B6EE009FDDC233431553E0247DAF0CCB4F2C8304
```

## Boundary and next action

This experiment establishes that one Slave-only PTP restart can re-arm the WR
extension far enough to show Slave and Master engagement while preserving the
existing Step5 SoftPLL locks. It does not establish stable Global Time.

Do not run Step6B and do not claim Step6A pass. Stop here and obtain the
adviser’s next experiment contract before any further hardware action.
