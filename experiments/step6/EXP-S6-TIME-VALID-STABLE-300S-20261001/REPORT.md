# EXP-S6-TIME-VALID-STABLE-300S-20261001 — build attempt 1

## Verdict

```text
BUILD = PASS
CANONICAL_ARTIFACT_CHECK = NOT_RUN_IN_THIS_ATTEMPT
PROGRAMMING = NOT_RUN
TIME_VALID_300S = NOT_RUN
RESULT = STOPPED_BEFORE_PROGRAM
```

This is not a hardware failure or a failed 300-second time-valid run. The
runner stopped before programming because the freshly rebuilt SOF hashes did
not equal the stored milestone SOF hashes.

## Build evidence

- Pain source commit: `2cb6efe1b342f385c172dd25b313c4e32da2546f`.
- Run tag: `20261001T051718Z`.
- Frozen source checksum verification: passed.
- Master and Slave firmware and Quartus builds: completed successfully.
- Quartus Prime Standard: 17.0.0 Build 595.
- Rebuilt Master SOF SHA-256: `802ee118791faf39b3de61317daa13464d6a4814ae55e81ee3f3e9c48c59e9cd`.
- Rebuilt Slave SOF SHA-256: `9663eed981058f06edace72f60eaf14ab5cd6cca1a647b63eeeed2b2a8e49a3`.
- Expected stored milestone hashes:
  - Master: `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`
  - Slave: `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`
- The runner logged `frozen_sof_hash_mismatch` and exited before cable
  programming. No JTAG programming or observer capture occurred.

## Diagnosis and controlled next action

The frozen source manifest remained valid. The generated firmware build logs
show the embedded version string changed with the outer repository revision:
`master-diagnostic-baseline-20260817-1499-g2cb6efe1`. The historical validated
build used a different `git describe` value. Thus rebuilding this old frozen
source at a new outer commit produces different artifacts. This explains why
the hash comparison is not reproducible; it does not establish that the SOF
binary differences are only metadata, so no equivalence claim is made.

For the next attempt, still compile both boards and retain the rebuilt hashes,
but use the checked-in milestone SOFs as the programming inputs after verifying
the milestone `SHA256SUMS` and both exact expected hashes. This keeps the
hardware test on the exact previously validated image while testing the revised
300-second `TIME_VALID` criterion.

A subsequent local integrity review found that the milestone README had been
revised in the acceptance-update commit without refreshing its entry in
`SHA256SUMS`. The Master SOF, Slave SOF, and frozen source manifest entries
already matched. The README digest entry has now been corrected to the exact
committed file bytes; the complete manifest will be rechecked before the next
programming attempt.

## Raw files

All logs for run `20261001T051718Z` are retained under
`raw/build/20261001T051718Z/`. Their SHA-256 values are listed in that folder's
`SHA256SUMS`. These are build/pre-program records only; no hardware runtime
result is present.
