# EXP-S6-WRH-SERVO-TRACK-ENTRY-FIXED-SETP-20261001 — Report

## Initial status

```text
SOURCE_TESTS                         = NOT_RUN
GITHUB_PUSH                         = NOT_RUN
PAIN_BUILD_PROGRAM                  = NOT_RUN
TRACK_ENTRY                         = NOT_OBSERVED
FIXED_SETP_SMOKE                    = NOT_RUN
STEP6_STRICT_OFFSET_300S_STABILITY  = NOT_ESTABLISHED
```

This is a diagnostic candidate. No Step 6 pass is claimed until a fully
qualified 300-second capture meets every gate in `PLAN.md`.

## Candidate

The candidate adds a boot-lifetime one-shot SETP latch at the first successful
`WAIT_OFFSET_STABLE → TRACK_PHASE` transition. After latching, servo init,
`SYNC_PHASE`, and `TRACK_PHASE` cannot alter the phase setpoint or call
`adjust_phase()`. Coarse time correction and unrelated controls remain
unchanged. The latch is independent of the existing IPC tracking-enable flag.

The parent candidate did reach `TRACK_PHASE`, but its two short captures had
coherent CKO samples outside ±60 ps; therefore this trial directly tests
whether those excursions continue with SETP fixed. The earlier fixed-SETP run
did not reach TRACK and is inconclusive, not a result about the latch.

## Results

Hardware evidence pending.
