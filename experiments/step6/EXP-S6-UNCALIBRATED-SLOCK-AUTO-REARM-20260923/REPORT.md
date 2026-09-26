# Report — EXP-S6-UNCALIBRATED-SLOCK-AUTO-REARM-20260923

## Verdict

```text
STEP1_PHY_LINK                         = PASS (120/120 board frames)
STEP2_ENDPOINT_PTP                     = PARTIAL (60 Master PASS, 60 Slave INFO)
STEP3_WR_HANDSHAKE                     = ROLE-EXPECTED (60 Slave PASS, 60 Master INFO)
STEP4_SOFTPLL_STARTUP                 = PARTIAL (60 Master PASS, 60 Slave INFO)
STEP5_FIVE_DIRECT_LOCKS_300S           = NOT_PROVEN (no 300-second continuous window)
STEP6_MASTER_GLOBAL_TIME               = PASS (60/60 frames)
STEP6_SLAVE_GLOBAL_TIME                = NOT_PASS (60/60 WAITING)
SLOCK_AUTO_REARM                       = INSUFFICIENT
```

The dashboard capture contains 60 paired samples from
`2026-09-23T23:11:58+08:00` through `2026-09-23T23:21:49+08:00` (nominal
10-second sampling; 591 seconds between first and last sample). Both boards
reported Step 1 PASS throughout. The role-specific Step 2/3/4 results were
stable across the capture: Master Step 2 and Step 4 PASS while Step 3 is INFO;
Slave Step 3 PASS while Step 2 and Step 4 remain INFO. Master Global Time was
VALID in all 60 samples, but Slave remained WAITING with `TIME_VALID=0` and
`PPS_VALID=0` in all 60 samples.

The Slave's direct lock bits were intermittent: in the 60-frame window,
`Helper=1` occurred 22 times, `MainFreq=1` 21 times, and each of `MainPhase`,
`MainLock`, and `PSTAT` was `1` 20 times. All five were jointly asserted in
20 frames, with a longest uninterrupted run of 20 samples spanning 190
seconds. Step 5 stability therefore cannot pass the 300-second criterion.
The per-sample dashboard verdict was `UPSTREAM_NOT_READY` for the Slave in all
60 samples; it is not itself a Step 5 stability measurement.

## Diagnosis supported by the capture

The preceding re-arm change handled an S_LOCK timeout in
`PPS_UNCALIBRATED` by returning the WR sub-state to `WRS_IDLE`. That was not
enough when the PTP state was already uncalibrated: no PTP state transition
occurred to invoke the existing hook that advances `WRS_IDLE` to
`WRS_PRESENT`. The later ten-sample attribution remained at `PTP_STATE=8`,
`SERVO_STATE=0`, and `UCNT=239`; `UCNT_INCREASED=0`, `SERVO_COMPLETE=0`, and the
final sample reported `STOP_CANDIDATE=FAIL_PTP_SERVO_NOT_COMPLETE`. The displayed
lock flags therefore did not prove an active time-servo update or Step 5
stability.

This result led to the next source change: for the already-uncalibrated case,
restart directly at `WRS_PRESENT`; retain `WRS_IDLE` for the `PPS_SLAVE` case.
That later change and its separate successful runtime evidence are documented
in [`EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/REPORT.md`](../EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/REPORT.md).

## Raw evidence

- `raw/build/` — Master/Slave build logs and build metadata
- `raw/program/` — programming logs
- `raw/observe/stability-600s.log`
- `raw/observe/step5-stability-330s.log`
- `raw/observe/step5-stability-360s.log`
- `raw/observe/rearm-state-attribution.log`
- `raw/observe/rearm-wr-state-after-360s.log`
- `raw/observe/tmvalid-attribution-after-rearm-20260923.log`
- Remaining read-only captures under `raw/observe/`
