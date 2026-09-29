# EXP-S6-WRH-SERVO-PHASE-HALF-GAIN-20260929

## Status

`GLOBAL_TIME_RESTORED; SAME_PPS_PASS; STEP5_300S_STABLE_CANDIDATE_NOT_ESTABLISHED; STEP6B_NOT_RUN`

## Finding and change

The baseline coherent captures showed that the WR servo's phase-setpoint
actuation had approximately -2:1 response: applying the full measured phase
offset reversed the next residual and nearly doubled its magnitude. The
existing 60 ps acquisition gate therefore oscillated instead of settling.

Only the `WRH_SYNC_PHASE` acquisition correction changed, from the full offset
to half the offset (`offset_ps / 2`). The 60 ps gate, `TRACK_PHASE` fine
tracking, SoftPLL PI/gains, PPS/TAI logic, RTL, SDB, and timing constraints are
unchanged. Offline model tests passed 2/2.

Pain pulled source commit `edd525a2104a7bc68c6db13fcaa1a1368c117095`, built
both boards successfully, and programmed those fresh images (not the frozen
milestone SOFs). Programmer reported one device configured and zero errors or
warnings on each board. Master/Slave SOF SHA-256 values are recorded in
`raw/post-program-capture-summary.md`.

This was an experimental source variant, not the frozen Step6 milestone. The
candidate change is preserved by source commit
`edd525a2104a7bc68c6db13fcaa1a1368c117095`; the frozen milestone source tree
has since been restored to the baseline that matches its checked-in SOFs and
manifests. Do not use the frozen milestone SOFs as substitutes for the
half-gain candidate build.

## Hardware result

The first 180-second post-program wait ended before Slave reacquired the phase
branch; that was an intermediate startup observation, not the final result.
Later read-only observation showed the Slave recovered without a reset,
reprogram, or PTP command. The coherent servo trace exercised the changed
half-step path; one observed correction was `CKO=-184 ps`, `SETP delta=-92 ps`,
followed by residuals of `-74 ps` and then `-1 ps`.

The subsequent dashboard read at 2026-09-29 14:47 (+08:00) reported:

```text
Master: TIME_VALID=1, PPS_VALID=1, snapshot valid/stable
Slave:  TIME_VALID=1, PPS_VALID=1, snapshot valid/stable
Slave:  Helper=1, MainFreq=1, MainPhase=1, MainLock=1, PSTAT=1
Slave:  WR_SERVO_STATE=WAIT_OFFSET_STABLE, WR_SERVO_OFFSET=-539 ps
```

Thus the reported `TIME_VALID=0 / PPS_VALID=0 / TAI=INVALID` condition was
cleared on the newly built and programmed image. This is a successful
Global-Time validity observation, not evidence that the servo offset stayed
inside 60 ps continuously.

The read-only same-PPS comparison then passed:

```text
SAMPLES=7
COMMON_TAI_COUNT=5
EXACT_MATCH_COUNT=5
MAX_ABS_DELTA_TICKS=0
MISMATCH_LABELS=0
DELTAS=0,0,0,0,0
```

All five shared TAI labels matched exactly between Master and Slave, including
the 125 MHz cycle value. No reset or reprogram occurred during this capture.

## Stability boundary and verdict

The 301-sample, 1000 ms-per-sample Step5 series accepted every observation,
but returned:

```text
Master: NEVER_LOCKED                 (expected; Master is not the Step5 target)
Slave:  LOCK_ACQUIRED_NOT_STABLE
```

This classification means the series did not meet the requirement that every
sample in the full window be locked; the observer did not classify it as a
post-acquisition loss. The filtered capture did not preserve the exact initial
out-of-gate sample, so no narrower cause is claimed. A later dashboard and
same-PPS gate showed the Slave lock bits asserted, but they do not replace the
300-second continuous Step5 criterion.

Therefore:

- Global-Time validity on both boards: `PASS` at the observed dashboard point.
- Same-PPS Master/Slave Global-Time consistency: `PASS` (5 exact common labels).
- Step5 300-second stable lock candidate: `NOT_ESTABLISHED`.
- Step6B scheduled dual-board trigger: `NOT_RUN`; the Step5 stability gate was
  not established.
- Full Step6 milestone: `NOT_ESTABLISHED` until the 300-second lock gate and
  scheduled-trigger validation are completed.
- Timing closure: `NO`; not part of the functional acceptance criteria.

No production changes beyond the single acquisition correction were made.
