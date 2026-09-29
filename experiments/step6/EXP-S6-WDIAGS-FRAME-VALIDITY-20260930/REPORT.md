# EXP-S6-WDIAGS-FRAME-VALIDITY-20260930 — Progress Report

## Current verdict

```text
UNALIGNED_MINIMAL_READER_SMOKE  = FAIL (10/24 valid WDIAGS frames; 41.7%)
PREVIOUS_ROW_EPOCH_READER_SMOKE = FAIL (11/23 valid WDIAGS frames; 47.8%)
PER_ROW_EPOCH_BASELINE_READER   = IMPLEMENTED, NOT YET RUN
300S_CAPTURE                    = NOT RUN (smoke gate failed)
STEP6_EXPANDED_ACCEPTANCE       = NOT ESTABLISHED
```

The smoke gate requires at least 75% valid diagnostic frames, zero reader
timeouts/invalid counts, at least 20 rows, and median row duration below
250 ms. Neither prior smoke met that gate. The first epoch-aligned attempt
still compared with the previous row's epoch; because rows were about 645 ms
apart and the publication cadence is 100 ms, that did not ensure a fresh
transition within the current row. The latest code instead samples a per-row
baseline and waits for the next epoch transition. It must pass a fresh
15-second smoke before any long capture.

## Evidence and sequence

All three captures were read-only observations on Pain, branch
`feat/file_cleanup`, using source revisions `6173fa94c7e2578f3589abf515586ea98c9a94f2`
and `f5eb6df3`. There was no FPGA programming, build, reset, or power cycle.
No file under
`/home/b10504072/04_WR_archive_step6_pass/` was accessed.

### Smoke 1 — broad critical read group

Raw log: [`smoke_20260929T174908Z.log`](raw/observe/smoke_20260929T174908Z.log)

- 5 rows over 3.292 s; the observer stopped after five consecutive untrusted
  rows.
- Individual reads, Global Time, and all five Step 5 lock bits were valid in
  all five rows; no Wishbone timeouts/invalid counters or reset change.
- All 5 rows crossed a WDIAGS epoch; the broader critical group took roughly
  202–210 ms, exceeding the 100 ms publication period.
- `abs(CKO) < 60 ps`: 0/5 trusted offset rows.
- Analyzer verdict: `SMOKE_FAIL`.

### Smoke 2 — minimal unaligned CKO/SSTAT/UCNT group

Raw log: [`smoke_20260929T175921Z.log`](raw/observe/smoke_20260929T175921Z.log)

- 24 rows over 15.479 s; no early stop.
- Individual reads, Global Time, and all five Step 5 lock bits were valid in
  24/24 rows; no Wishbone timeouts/invalid counters or reset change.
- Only 10/24 rows had a valid unchanged WDIAGS epoch (41.7%); 14 rows crossed
  an epoch. The critical group took a median 93.010 ms (maximum 93.594 ms),
  close enough to the 100 ms refresh period that arbitrary-phase reads still
  frequently cross a publication boundary.
- Median row duration was 143.970 ms. The observed CKO range over the 10 valid
  framed rows was −3893 to +1975 ps; none met `abs(CKO) < 60 ps`.
- Analyzer verdict: `SMOKE_FAIL`; no 300-second capture was started.

### Smoke 3 — previous-row epoch baseline

Raw log: [`smoke_20260929T181651Z.log`](raw/observe/smoke_20260929T181651Z.log)

- 23 rows over 15.004 s; no early stop.
- Individual reads, Global Time, and all five Step 5 lock bits were valid in
  23/23 rows; no Wishbone timeouts/invalid counters or reset change.
- Only 11/23 rows had a valid unchanged WDIAGS epoch (47.8%); 12 rows crossed
  an epoch. Median framed payload duration was 57.761 ms (maximum 58.989 ms),
  and median row duration was 143.630 ms.
- The CKO range over 11 valid framed rows was +870 to +2160 ps; none met
  `abs(CKO) < 60 ps`. Analyzer verdict: `SMOKE_FAIL`; no long capture ran.
- Diagnosis: the reader compared each candidate epoch with the last accepted
  row. Since the sample interval was about 645 ms—several 100 ms publication
  periods—the candidate was usually already different before the current
  row's wait began. This was not evidence of a just-published frame.

## Next action

Run one 15-second smoke using the per-row-baseline reader in the current
source. Each row first reads its current epoch, then waits at most 350 ms for
the epoch to change, validates DATA_VALID and the inverse pair, reads only
CKO/servo state/update count, and checks the epoch/valid flag again. Require at
least 20 rows, at least 75% framed rows, zero transport timeouts/invalid
counts, and median row duration below 250 ms. If any gate fails, stop and
report it; do not launch the 300-second capture. If the smoke passes, run one
300-second read-only capture under the existing stop limits.

This epoch guard improves publication-frame association; it does not make the
sequential reads atomic or establish servo causality. Step 6 remains
`NOT_ESTABLISHED` until the full sustained acceptance criteria are met.
