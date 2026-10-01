# EXP-S6-TIME-VALID-300S-QUARTER-ACQUIRE-20261001 — Superseded before programming

## Current verdict

```text
STEP6_TIME_VALID_300S_BOTH_BOARDS = NOT_ESTABLISHED
QUARTER_CANDIDATE_BUILD           = INTERRUPTED_BEFORE_QUARTUS
FPGA_PROGRAMMING                  = NOT_RUN
NEXT_ACTION                       = repeat historical /2 acquisition + /12 tracking candidate
```

This candidate was superseded before Quartus compilation or any FPGA
programming. A partial Pain-side attempt began at source commit
`2a91e3684c2b8416b9ba98dac78a1a113031173c` and was interrupted while only the
Master firmware/build setup was in progress. Its partial logs are present as
untracked files in the Laptop and Pain worktrees and will be hash-checked and
synchronized separately before being treated as shared evidence. They show no
completed SOF, no programming, and no hardware observation. Its
source-manifest check was made while the
temporary /4 patch was applied and consequently reported one mismatch; the
subsequent post-revert verification on Pain passed the frozen source manifest
3219/3219. Do not interpret this interrupted attempt as a compile failure or a
programmed candidate.

The current experiment is
[EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001](../EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001/PLAN.md).
It reuses the exact previously built /2-acquire + /12-track image and corrects
the observed capture-window shortfall by requesting 303,000 ms, with no new
servo change.

## Historical evidence re-evaluated under the revised target

The earlier `/4 acquisition + /4 tracking` capture was a near-pass, but is no
longer the closest historical candidate. Re-analysis of its saved read-only
Slave records found:

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

The better historical /2-acquire + /12-track capture recorded
`STATUS_TIME_VALID=1` in all 959/959 rows, a 299,998-ms sample span, and a
411-ms maximum gap. It is still only a near-pass: it observed only Slave and
missed the span gate by 2 ms.

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
