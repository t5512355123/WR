# EXP-S5-HPLL-DEMAND-MAIN-PROGRESS-CORRELATION-20260919

## Verdict

```text
CORRELATION_CAPTURE       = PASS
QSFP_A_LANE0_LINK         = PRESERVED_FROM_PRIOR_VALIDATED_SESSION
PROGRAMMING               = NOT_PERFORMED
HELPER_DCO_CORRELATION    = INCONCLUSIVE_DCO_TRANSACTION_BOUNDARY
STEP5                     = NOT_PASS
NEXT_CONTROL_TUNING       = PROHIBITED
```

This is a diagnostic boundary result, not a Step5 result. The requested
correlation capture completed successfully, but it did not provide enough
atomic evidence to distinguish a completed DCO transaction from a DCO status
that remains busy while the step value changes.

## Provenance and procedure

The latest diagnostic direction required keeping the recovered QSFP-A lane-0
session alive and running the existing passive observer without reprogramming.
The new source/build worktree was therefore not programmed. The hardware
continued running the previously programmed lane-0 validated image from the
F4L recovery session.

```text
observer source commit        c73116480a9f5c3fa2c5a77b3e8d8f0d3aa037eb
observer                      scripts/jtag/read_hpll_helper_correlation.tcl
command                       quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 60 500
configured samples            60 per detected hardware
configured interval           500 ms
captured samples              120 (60 per board)
quartus_stp result             0
terminal marker                HPLL_HELPER_CORRELATION_DONE
```

The shell did not have `quartus_stp` on `PATH`, so the same command was
invoked through the Pain-installed Quartus 17.0 executable path. This did not
change the Tcl script or its access pattern. The complete raw output is
stored in `raw/helper_dco_correlation.log`.

The full two-board capture took approximately 87 seconds because every sample
contains multiple Wishbone mailbox reads. No control write, WDIAGS setup write,
FINC/FDEC, or programming operation was issued during the capture.

## Raw results

The board mapping is the same as the preceding validated F4L run:

```text
DE5 [1-11.1] = Master
DE5 [1-11.2] = Slave
```

### Master: DE5 [1-11.1]

This board did not expose an active Helper/DCO service path in this observer,
which is expected for the Master-side correlation endpoint:

```text
samples                  = 60
PSTAT                    = 1 throughout
LOCK_ENABLE              = 0 throughout
HELPER_ERROR_SIGNED      = -150000 throughout (rail/clamped)
HELPER_OUTPUT            = 0x0000FFFB throughout
STEP_DELTA nonzero       = 0/60
HPLL_LOAD                = 0/60
BUSY                     = 0/60
ERROR                    = 0/60
HELPER_UPDATE_COUNT Δ    = 165785
```

These Master values are not evidence that the Slave DCO service failed; this
board is not the endpoint on which the active Helper transaction is expected.

### Slave: DE5 [1-11.2]

The Slave did show active Helper updates and DCO step movement:

```text
samples                  = 60
PSTAT                    = 1 throughout
LOCK_ENABLE              = 4 throughout
HELPER_UPDATE_COUNT Δ    = 163260
STEP_EVENT               = 59/60
STEP_DELTA nonzero       = 59/60
STEP_DELTA sum           = 83141
STEP_DELTA range         = 1329..1417 (nonzero samples)
BUSY                     = 60/60
ERROR                    = 0/60
HPLL_LOAD sampled high   = 0/60
```

The Helper error was not pinned at either rail in this Slave window:

```text
HELPER_ERROR_SIGNED      = -232..210
HELPER_OUTPUT            = 36411..37488
PRECLAMP_ERROR           = 16384 throughout
```

The diagnostic residual proxy, computed as signed
`TAG_DELTA - EXPECTED_DELTA`, was:

```text
range                    = -248..278
mean                     = +34.83
population std. dev.     = 101.09
sign transitions         = 31
```

Thus the Slave is not in the earlier obvious `+/-150000` Helper-rail state;
it is producing changing Helper output and changing DCO step values. However,
the sampled `BUSY` bit stayed asserted for the entire 60-sample window, while
the sampled `HPLL_LOAD` bit was never high. Since `HPLL_LOAD` may be a short
event relative to the 500 ms sampling interval, these observations do not
prove that a DCO transaction completed, nor do they prove that the feedback
measurement was applied after each step.

No sample showed the complete Step5 entry chain. In particular, this capture
does not establish `HELPER_LOCKED=1` followed by `MAIN_ENABLED=1`; the prior
lane-0 baseline remained at the Helper-not-locked boundary.

## Interpretation

The capture rules out the simplest claim that the active Slave Helper is
completely idle: update count and DCO step values advance. It also does not
support calling the earlier rail case on the active Slave, because the Helper
error leaves the rail and the residual proxy crosses zero repeatedly.

The strongest supported boundary is:

```text
HELPER_DCO_ACTIVITY             = OBSERVED
FEEDBACK_ERROR                  = CHANGING, NOT RAIL-CLAMPED
DCO_BUSY_STATUS                 = ASSERTED THROUGHOUT WINDOW
DCO_COMPLETION                  = NOT PROVEN
HELPER_LOCK                     = NOT OBSERVED
MAIN_LOCK                       = NOT REACHED
```

Therefore the conservative classification is
`INCONCLUSIVE_DCO_TRANSACTION_BOUNDARY`. It is not valid to jump to Main/F4L
or to change PI/gain/threshold/timeout based on this capture.

## Required stop and next boundary

This experiment stops here. The next investigation, if started, must stay
read-only and resolve the DCO transaction boundary: whether a step update is
completed and observed by the Helper feedback path, or whether the DCO remains
busy/handshake-blocked. It must not tune the controller until that boundary is
resolved. F4L is permitted only after a fresh capture proves
`HELPER_LOCKED=1`, `MAIN_ENABLED=1`, stable generation/reset state, and a
valid F4L schema.

Step5 is not pass.

## Artifacts

- `PLAN.md`
- `REPORT.md`
- `raw/helper_dco_correlation.log`
