# EXP-S5-PHASE-RESTORE-MILESTONE-20260922

## Verdict

```text
PHASE_FIX_IMAGE                 = DEMONSTRATED
INITIAL_VALID_SESSION           = PHASE_AND_PSTAT_LOCK_OBSERVED
POST_POWER_CYCLE_LINK_GATE      = FAIL
FORMAL_300S_REVALIDATION        = NOT_COMPLETED
CURRENT_STEP5_RESULT            = BLOCKED_UPSTREAM
```

This run separates the original phase-lock issue from the current hardware
state.  The old SOF images on Pain were stale.  After rebuilding and
programming the documented Step5 milestone source, the Slave immediately
showed `MainPhase=1`, `MainLock=1`, and `PSTAT=1` in a valid link session.
After a required Pain host power-cycle, however, the QSFP-A WR endpoint link
did not recover.  The later zero phase values are therefore not a phase-loop
failure: Step4B and Step5 were never re-entered because the upstream link gate
was false.

## Source and image provenance

```text
SOURCE_COMMIT = 26e138fdc0bfc8426704b397141d563cf4d580a2
ROLE          = Step5 functional milestone (threshold20, phase Ki1, F4L)
BUILD_RESULT  = Quartus full compile PASS, 0 errors
TIMING        = existing timing warnings retained; not a Step5 functional gate
```

The rebuilt SOF hashes were:

```text
SLAVE  = b048098c52b99670126f57c00616e9ca46e92f92f888ee95527b0d70d5dcbe69
MASTER = c786658275082366a42505271ad4ef2786b23d2e8b2e1f99ad2fd6058da0de84
```

The hashes differ from the historical report's fitter outputs because this
was a fresh Quartus fit.  The source commit, firmware MIF identity, and
functional compile markers were the milestone values.

## First programmed session: functional phase evidence

Master and Slave were programmed successfully on 2026-09-22, first using
Master then Slave.  The read-only dashboard at `11:30:01 +08:00` reported:

```text
Master: Link=1 TM=1 RX=1 TX=1
Slave : Link=1 TM=1 RX=1 TX=1

Slave Helper  = 1
Slave MainFreq= 1
Slave MainPhase=1
Slave MainLock = 1
Slave PSTAT    = 1
```

This is direct evidence that the rebuilt milestone image can enter the phase
lock state.  It was not yet a formal 300-second revalidation because the
observer command was initially invoked without Pain's Quartus binary path.
That command failed before any hardware write and was corrected later.

## Power-cycle and recovery attempt

Pain became unreachable after the first session.  The authorised
`pain-shutdown` workflow was completed: both power-control clicks were
visually verified, the blue on-state control was re-identified, Edge was
restored to the GPT window, and SSH recovered after the required wait.

The same milestone SOFs were then programmed again successfully.  A single
controlled retry also programmed Slave then Master, using the existing
startup procedure.  No PI, gain, threshold, timeout, detector, RTL, PHY, or
timing-closure change was made.

## Post-power-cycle read-only result

After the retry and more than one minute of settling, the dashboard reported
on both boards:

```text
CORE_TM_LINK_UP = 0
CORE_LINK_OK    = 0
```

The raw runtime reader remained trusted:

```text
WB_TRANSPORT_PROTOCOL       = PRELOAD_THEN_TOGGLE_COMMIT
PRELOAD_PROTOCOL_REVALIDATION = PASS
TIMEOUT_COUNT               = 0
INVALID_COUNT               = 0
```

The role/endpoint evidence was consistent:

```text
Master WDIAGS_MODE = 2 MASTER
Master WDIAGS_PTP  = 6 MASTER
Slave  WDIAGS_MODE = 3 SLAVE
Slave  PTP state    = SLAVE / fallback, no WR parent
```

Master continued to transmit and its Step4A event counters advanced, but
Slave had no received WR traffic.  Therefore the current boundary is:

```text
Step1 link gate  -> FAIL
Step2/3          -> not reached
Step4B           -> blocked by upstream prerequisite
Step5 phase      -> not evaluated in this session
```

## Conclusion

The stale-SOF explanation is confirmed: the milestone image produced the
expected phase/PSTAT lock before the host power-cycle.  The present failure
is an upstream QSFP-A/WR-link recovery blocker exposed by the power-cycle,
not evidence that Main phase control needs new gains.  The formal 300-second
Step5 pass must not be claimed from this run.

The next valid action is to restore a healthy QSFP-A WR link and verify
`CORE_TM_LINK_UP=1`, `CORE_LINK_OK=1` on both boards without changing the
phase controller.  Only then should the same milestone image be observed for
the formal 300-second Helper/Main-frequency/Main-phase/PSTAT stability gate.
