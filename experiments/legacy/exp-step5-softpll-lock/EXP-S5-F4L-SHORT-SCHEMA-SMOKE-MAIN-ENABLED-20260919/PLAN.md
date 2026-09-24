# EXP-S5-F4L-SHORT-SCHEMA-SMOKE-MAIN-ENABLED-20260919

## Purpose

After direct confirmation of `HELPER_LOCKED=1` and `MAIN_ENABLED=1`, perform
the advisor-approved short passive F4L schema smoke on the same QSFP-A lane-0
session. The smoke is a schema/entry check, not a formal Step5 lock proof.

## Frozen controls

- No reprogramming and no power cycle.
- No PI/gain/threshold/timeout/bootstrap/PHY/RTL/control change.
- Use the existing single-reader F4L observer.
- No control writes, Helper PI snapshot, debug FIFO drain, or second reader.
- Target smoke duration: 10 seconds; stop immediately on terminal/session end,
  invalid schema timeout, generation/reset change, or transport failure.

## Required result

At least three coherent valid frames covering page 0, page 1, and page 2 are
required for `F4L_SMOKE=PASS`. A terminal/session end before that point is a
hard stop and is not a phase-lock result.
