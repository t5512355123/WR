# EXP-S6-WDIAGS-FRAME-VALIDITY-20260930 — Progress Report

## Current verdict

```text
UNALIGNED_MINIMAL_READER_SMOKE = FAIL (10/24 valid WDIAGS frames; 41.7%)
EPOCH_ALIGNED_READER            = IMPLEMENTED, NOT YET RUN
300S_CAPTURE                    = NOT RUN (smoke gate failed)
STEP6_EXPANDED_ACCEPTANCE       = NOT ESTABLISHED
```

The smoke gate requires at least 75% valid diagnostic frames, zero reader
timeouts/invalid counts, at least 20 rows, and median row duration below
250 ms. Neither prior smoke met that gate. The latest reader waits for a new
published diagnostics epoch before reading the minimal `CKO/SSTAT/UCNT`
payload; it must pass a fresh 15-second smoke before any long capture.

## Evidence and sequence

Both captures were read-only observations on Pain, branch `feat/file_cleanup`,
source revision `6173fa94c7e2578f3589abf515586ea98c9a94f2`. There was no FPGA
programming, build, reset, or power cycle. No file under
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

## Next action

Run one 15-second smoke using the epoch-aligned reader in the current source.
The reader waits at most 350 ms for a new valid publication epoch, then reads
only CKO, servo state, and update count and checks the epoch/valid flag again.
Require at least 20 rows, at least 75% framed rows, zero transport
timeouts/invalid counts, and median row duration below 250 ms. If any gate
fails, stop and report it; do not launch the 300-second capture. If the smoke
passes, run one 300-second read-only capture under the existing stop limits.

This epoch guard improves publication-frame association; it does not make the
sequential reads atomic or establish servo causality. Step 6 remains
`NOT_ESTABLISHED` until the full sustained acceptance criteria are met.
