# EXP-S6-WRH-SERVO-TRACK-INBAND-HOLD-DEADBAND-20261001 — Report

## Initial status

```text
LAPTOP_SOURCE_TESTS = NOT_RUN
GITHUB_PUSH = NOT_RUN
PAIN_BUILD_PROGRAM = NOT_RUN
TWO_SMOKE_GATE = NOT_RUN
STABLE_OFFSET_300S = NOT_ESTABLISHED
```

This report will record one controlled candidate. No Step 6 pass is claimed
unless the complete 300-second acceptance gate in `PLAN.md` passes.

## Candidate

The candidate restores the historical measured `/4` acquisition baseline and
adds an in-band TRACK hold: while `abs(offset_ps) < 60 ps`, it leaves SETP
unchanged and issues no `adjust_phase()` call. At or outside 60 ps, the
existing `/4` tracking correction remains active. The strict WAIT entry
threshold, `>120 ps` fallback, ten-miss retry, Step 5 controls, PTP/DMS, reset,
RTL, SDB, and timing constraints are unchanged.

## Results

Hardware evidence pending.
