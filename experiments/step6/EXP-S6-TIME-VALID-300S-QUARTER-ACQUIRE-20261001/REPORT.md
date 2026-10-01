# EXP-S6-TIME-VALID-300S-QUARTER-ACQUIRE-20261001 — Not yet run

## Current verdict

```text
STEP6_TIME_VALID_300S_BOTH_BOARDS = NOT_ESTABLISHED
NEXT_ACTION                         = planned candidate /4 acquisition capture
```

This report is the planned follow-up to the user's revised Step 6 target.
No build, programming, or hardware capture for this experiment has occurred
yet. Follow `PLAN.md` in order.

## Historical evidence re-evaluated under the revised target

The earlier `/4 acquisition + /4 tracking` capture is the strongest candidate
so far. Re-analysis of its saved read-only Slave records found:

```text
Slave STATUS_TIME_VALID = 957 / 957 samples
first-to-last sample span = 299,984 ms
observer completion duration = 300,279 ms
largest adjacent sample gap = 409 ms
```

The sample-to-sample span is 16 ms short of a strict 300,000 ms window, so it
is a near-pass, not a 300-second pass. It also contains no corresponding
300-second Master capture. Thus it cannot establish the revised two-board
criterion. Its sampled phase-offset distribution is irrelevant to the new
acceptance gate.

The exact frozen-baseline attempt in
`EXP-S6-TIME-VALID-STABLE-300S-20261001` observed the Slave for 301,860 ms,
but `STATUS_TIME_VALID` was 0/1,186 samples. It therefore fails the revised
criterion. A post-capture one-shot showed Master TIME_VALID high, but that is
not a 300-second Master record.

The compact machine-readable re-evaluation is in
`raw/analysis/historical-reassessment.json`.

No Step 6 pass is declared. Timing closure, phase offset, lock fields, PPS
validity, snapshot flags, and live counter progression are not gates for the
revised target.
