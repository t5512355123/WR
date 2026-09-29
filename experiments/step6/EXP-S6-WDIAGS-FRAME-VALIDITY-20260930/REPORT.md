# EXP-S6-WDIAGS-FRAME-VALIDITY-20260930 — Progress Report

## Current verdict

```text
UNALIGNED_MINIMAL_READER_SMOKE  = FAIL (10/24 valid WDIAGS frames; 41.7%)
PREVIOUS_ROW_EPOCH_READER_SMOKE = FAIL (11/23 valid WDIAGS frames; 47.8%)
PER_ROW_EPOCH_READER_SMOKE      = PASS (22/22 valid WDIAGS frames; 100%)
300S_CAPTURE                    = COMPLETE (300277 ms; 429/429 framed rows)
STEP6_EXPANDED_ACCEPTANCE       = NOT ESTABLISHED (2/429 strict rows)
```

The smoke gate requires at least 75% valid diagnostic frames, zero reader
timeouts/invalid counts, at least 20 rows, and median row duration below
250 ms. The first three attempts failed this gate. The first epoch-aligned
attempt still compared with the previous row's epoch; because rows were about
645 ms apart and the publication cadence is 100 ms, that did not ensure a
fresh transition within the current row. The latest code samples a per-row
baseline, waits for the next epoch transition, and passed its 15-second smoke.
The ensuing 300-second run completed but failed the strict phase-offset gate.

## Evidence and sequence

All five runs were read-only observations on Pain, branch `feat/file_cleanup`.
The first two used `6173fa94c7e2578f3589abf515586ea98c9a94f2`, the third used
`f5eb6df3`, and the final two used `2268c76b`. There was no FPGA programming,
build, reset, or power cycle. No file under
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

### Smoke 4 — per-row epoch baseline

Raw log: [`smoke_20260929T182440Z.log`](raw/observe/smoke_20260929T182440Z.log)

- 22 rows over 15.360 s; all 22 had individually valid reads, Global Time,
  all five Slave Step 5 lock bits, and a valid unchanged WDIAGS frame.
- No transport timeouts/invalid counters, reset changes, or early stop.
- Median row duration was 195.366 ms. CKO ranged from +338 to +1271 ps; 0/22
  rows met the strict `abs(CKO) < 60 ps` criterion.
- Analyzer verdict: `SMOKE_PASS`. This validates the observer smoke gate only;
  it does not establish Step 6 phase-offset acceptance.

## 300-second read-only capture

Raw log: [`capture_20260929T182613Z.log`](raw/observe/capture_20260929T182613Z.log)

- Completed 300277 ms with 429 rows. Quartus/Tcl exit code was 0; there was no
  early stop, reset change, Wishbone timeout, or invalid counter.
- The WDIAGS frame guard was valid in 429/429 rows. Slave Global Time and all
  five Step 5 lock bits were valid in 429/429 rows.
- Median row duration was 195.112 ms; median sample spacing was 696 ms because
  the requested inter-sample delay was 500 ms.
- CKO ranged from −4023 to +2291 ps. Only 2/429 rows (0.47%) had
  `abs(CKO) < 60 ps`; therefore the full sampled Step 6 conjunction failed.
- Analyzer verdict: `STEP6_EXPANDED_GATE_NOT_ESTABLISHED`.

This was a Slave-only observation. It did not capture a dual-board Master
pre/post Global-Time dashboard, so it cannot establish cross-board Global-Time
agreement either. No Step 6 PASS or milestone is declared.

## Next action

The current reader successfully frames the WDIAGS payload, but its 500 ms
requested delay yielded only 429 rows over 300 seconds (median spacing 696 ms).
The next diagnostic-only iteration should use a 1 ms requested delay to let
the read cycle, rather than an added 500 ms sleep, set the sampling rate. First
run a 15-second smoke with the same frame/transport/row-duration gates; only if
that passes should a denser 300-second read-only capture be considered. Keep
the same per-row epoch guard and strict `<60 ps` acceptance. Do not alter
production servo controls based on this report alone.

This epoch guard improves publication-frame association; it does not make the
sequential reads atomic or establish servo causality. Step 6 remains
`NOT_ESTABLISHED` until the full sustained acceptance criteria are met.
