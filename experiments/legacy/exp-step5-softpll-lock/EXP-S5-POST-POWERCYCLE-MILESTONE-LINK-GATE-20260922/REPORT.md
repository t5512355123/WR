# EXP-S5-POST-POWERCYCLE-MILESTONE-LINK-GATE-20260922

## Verdict

```text
PAIN_POWER_CYCLE                  = PASS
PAIN_SSH_RECOVERY                 = PASS
STEP5_MILESTONE_MASTER_PROGRAM   = PASS
STEP5_MILESTONE_SLAVE_PROGRAM    = PASS
CORE_TM_LINK_UP                   = 0 / 0
CORE_LINK_OK                      = 0 / 0
STEP1_LINK_GATE                   = FAIL
STEP4B                           = NOT_REACHED
MAIN_PHASE_LOCK                   = NOT_EVALUATED
PSTAT_LOCK                        = NOT_EVALUATED
FORMAL_STEP5_PASS                = NO
RESULT                            = REMOTE_BLOCKED_BY_WR_LINK_STARTUP
```

This was a clean post-power-cycle reprogram attempt using the same documented
Step5 milestone image.  Both programming operations succeeded, but the WR
endpoint link did not reacquire within the final observation window.  Because
Step1 was false, the Slave SoftPLL and Main phase loop were not validly
entered; the dashboard's zero lock fields must not be interpreted as a phase
algorithm failure.

## Image and programming provenance

```text
SOURCE_COMMIT       = 26e138fdc0bfc8426704b397141d563cf4d580a2
MASTER_SOF_SHA256   = c786658275082366a42505271ad4ef2786b23d2e8b2e1f99ad2fd6058da0de84
SLAVE_SOF_SHA256    = b048098c52b99670126f57c00616e9ca46e92f92f888ee95527b0d70d5dcbe69
PROGRAM_ORDER       = MASTER_THEN_SLAVE
MASTER_PROGRAM      = successful, 2026-09-22 12:28:49 +08:00 to 12:29:15
SLAVE_PROGRAM       = successful, 2026-09-22 12:30:01 +08:00 to 12:30:20
COMPILE             = NO (existing verified milestone SOFs)
PI/GAIN/THRESHOLD   = unchanged
TIMEOUT             = unchanged
RTL/PHY/SDC         = unchanged
```

The Pain power-cycle itself was completed through the approved UI workflow:
the off click, the on click after the required 10-second interval, blue on-state
re-identification, Edge restoration to GPT, 120-second wait, and SSH recovery
all succeeded.  The live dashboard monitor was stopped before programming so
it could not hold the SLD HUB target.

## Post-program link observation

After programming, the dashboard was sampled after the prescribed settling
windows.  The final read at approximately `2026-09-22 12:32:38 +08:00` showed:

```text
Master:
  WR_READY=0  CORE_TM_LINK_UP=0  CORE_LINK_OK=0
  WR_RX_READY=1  WR_TX_READY=0  WR_RX_ENC_ERR=1
  WDIAGS_PTP=MASTER (state 6)

Slave:
  WR_READY=0  CORE_TM_LINK_UP=0  CORE_LINK_OK=0
  WR_RX_READY=1  WR_TX_READY=0  WR_RX_ENC_ERR=1
  WDIAGS_PTP=LISTENING (state 4; expected Slave state 9)
  Helper=0  MainFreq=0  MainPhase=0  MainLock=0  PSTAT=0
```

The same failure had already appeared in the first smoke after programming:
both boards reported `CORE_TM_LINK_UP=0` and `CORE_LINK_OK=0`.  Waiting an
additional recovery window did not change the gate.

## Interpretation and stop boundary

The exact milestone SOFs were successfully loaded, but this session never
reached the Step4B/Step5 entry gate.  Therefore:

```text
MainPhase=0        = NOT_REACHED, not a phase-loop verdict
PSTAT=0            = NOT_REACHED, not a phase-loop verdict
300-second proof   = NOT_RUN
```

The current remote evidence reproduces an upstream QSFP-A/WR link-startup
blocker after power-cycle.  No further remote programming or power-cycle is
authorized for this experiment.  The next valid action is physical A-path
handling or a separately approved alternate-port diagnostic; Step5 phase
testing resumes only after both boards show:

```text
CORE_TM_LINK_UP = 1
CORE_LINK_OK    = 1
PSTAT_LINK      = 1
```
