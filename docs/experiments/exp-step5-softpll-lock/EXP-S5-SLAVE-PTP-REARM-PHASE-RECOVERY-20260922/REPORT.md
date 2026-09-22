# EXP-S5-SLAVE-PTP-REARM-PHASE-RECOVERY-20260922

## Verdict

```text
S5_PHASE_REARM_INJECTION          = PASS
SLAVE_PTP_STOP_COUNT               = 1
SLAVE_PTP_START_COUNT              = 1
MASTER_PTP_RESTART_COUNT           = 0
RECOVERY_LOCK_OBSERVED             = NO
MAIN_PHASE_LOCK                    = NOT_OBSERVED
PSTAT_LOCK                         = NOT_CONCURRENT_WITH_PHASE
FORMAL_STEP5_PASS                 = NO
RESULT                             = INCONCLUSIVE_INVALID_FRAMES
```

This experiment tested one controlled recovery action after the QSFP-A link
was restored.  It did not modify the Step5 image or any phase-loop parameter.
The Slave `ptp stop` and `ptp start` bytes were delivered successfully, but
the follow-up window did not bring Main phase lock back.  The result is not a
new PI/gain diagnosis and is not a Step5 pass.

## Provenance and scope

```text
BRANCH                  = exp/step6-Global-Time-Testing
OBSERVER_COMMIT         = c072c874
STEP5_SOURCE_COMMIT     = 26e138fdc0bfc8426704b397141d563cf4d580a2
COMPILE                 = NO
MASTER_PROGRAM          = NO
SLAVE_PROGRAM           = NO
CPU_RESET               = NO
WR_CORE_RESET           = NO
PHY_RESET               = NO
POWER_CYCLE             = NO
PI/GAIN/THRESHOLD_CHANGE= NO
TIMEOUT_CHANGE          = NO
MASTER_PTP_RESTART      = NO
SLAVE_PTP_STOP          = EXACTLY_ONCE
SLAVE_PTP_START         = EXACTLY_ONCE
```

The recovery observer was first run with three essential preflight pairs.  The
full shadow frame was occasionally marked `READ_VALID=0` because unrelated
shadow groups were not coherent, but the safety-critical preflight fields
were stable in all three pairs:

```text
Master: LINK_HEALTHY=1 CAPTURE_HEALTHY=1 RESET_CHANGED=0 PTP_STATE=6
Slave : LINK_HEALTHY=1 CAPTURE_HEALTHY=1 RESET_CHANGED=0
        RX_LOCKED_TO_DATA=1 RX_PATTERN_READY=1 PTP_STATE=9
        EXT_STATE=2 WRC_MODE=3
```

Only after this essential gate passed was the single VUART recovery action
performed.  Every byte returned `WB_RESULT=1`.

## Post-restart observation

The read-only follow-up observer ran for the configured 90-second window and
captured 18 paired samples.  The most representative states were:

```text
Slave PTP_STATE       = 8 during most of the recovery, later 9
Slave SPLL_SEQ_STATE  = 6
Slave HELPER_LOCKED   = 1 in most samples
Slave MAIN_FREQ_LOCKED= 1 in most samples
Slave MAIN_PHASE_LOCKED=0 in every usable lock row
Slave MAIN_LOCKED     = 0
Slave PSTAT_LOCKED    = 0 at the final row
Slave WR_FAILURE_REASON=3 at the terminal-looking final row
```

`PSTAT_LOCKED=1` appeared transiently in a partial row, but `MAIN_PHASE_LOCKED`
was 0 in that same row.  Therefore it cannot satisfy the Step5 four-signal
criterion and is not counted as a lock.

The observer ended with:

```text
S5_PHASE_REARM_OBSERVE_RESULT=INCONCLUSIVE_INVALID_FRAMES
S5_PHASE_REARM_OBSERVE_STEP5_PASS=NO
```

The raw reader also reported partial-frame inconsistency during the paired
capture.  This prevents a formal 300-second stability claim, independently of
the visible phase=0 result.

## Interpretation

The historical successful PTP-restart experiment began with an already valid
Step5 lock (`SPLL_SEQ_STATE=8`, `PSTAT=1`, `MAIN_LOCKED=1`).  This run began
from the current unlocked/session-timeout state.  Repeating the same Slave
restart from that state did not recreate phase lock; it left the system in a
WR/PTP recovery path with `MainPhase=0`.

The current evidence therefore points to the WR session/startup boundary as
the blocker that prevents the known-good phase controller from reaching its
lock state.  It does not justify changing PI, gain, threshold, timeout,
detector, anti-windup, DAC behavior, RTL, PHY, or timing closure.

## Next boundary

This run is complete and must not be called Step5 PASS.  The next clean
experiment should re-establish a fresh runtime session with the documented
Step5 milestone SOFs, then immediately perform a read-only short lock smoke.
If all four lock signals appear together, the unchanged image can proceed to
the formal 300-second observer.  If the fresh session again stops at WR
session/S-lock timeout, retain the phase code unchanged and classify the
failure as an upstream session-reacquisition problem.
