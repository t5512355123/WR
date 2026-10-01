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

## Attempt 2 — programmed-image 300-second capture

Run tag: `20261001T060353Z` on Pain source commit
`547f90c5b8bad8c8ee9db05dc94ebed0b293b802`.

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
CANONICAL_MILESTONE_MANIFEST = PASS
SLAVE_PROGRAM = PASS (DE5 [1-11.2], exact milestone SHA-256)
MASTER_PROGRAM = PASS (DE5 [1-11.1], exact milestone SHA-256)
OBSERVER_EXIT = PASS (rc=0; normal completion)
TIME_VALID_300S = NOT_ESTABLISHED
```

The rebuilt SOFs differed from the canonical files because of the embedded
outer-checkout build identity; those hashes were recorded only. The exact
checked-in milestone SOFs were independently verified and programmed:

- Master programmed SHA-256:
  `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`.
- Slave programmed SHA-256:
  `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`.
- Rebuilt Master SHA-256:
  `26e30d02688d447d2dc6cec6aec0d6c2defb225c2accc0d5e9f7c3dc5022e0a3`.
- Rebuilt Slave SHA-256:
  `e932fc8e86d5e27487ec777beed5d3351cd1f81234e25b82f1b25ace5ac5039c`.

The read-only Slave observer completed `302115 ms` with 1,186 samples over a
`301860 ms` sample span and a maximum sample gap of 257 ms. It found:

```text
STATUS_TIME_VALID=1             0 / 1186
SNAPSHOT_TIME_VALID=1            0 / 1186
SNAPSHOT_VALID=1                 0 / 1186
status PPS-valid bit=1          1140 / 1186
snapshot PPS-valid=1              0 / 1186
Step1/link-ready                  1183 / 1186
```

The analyzer verdict is `TIME_VALID_300S_NOT_ESTABLISHED`. The live-time
monotonicity field was false, but this is diagnostic only under the revised
TIME_VALID-only acceptance and did not determine the verdict: both Slave
TIME_VALID fields were zero in every sample. (The raw JSON was produced by the
earlier analyzer revision, which included monotonicity in its completeness
flag; that JSON is preserved unchanged.) The one-shot dashboard after the
capture confirmed the Master was `TIME_VALID=1`, while the Slave remained
`TIME_VALID=0`, `PPS_VALID=0`, with snapshot count 0. The Slave still showed
Helper, Main frequency, Main phase, Main lock, and PSTAT all locked; its WR PTP
servo state was `WAIT_OFFSET_STABLE` and phase offset was `-1471 ps` (diagnostic
only).

The dashboard's PPS status registers provide a useful comparison point. At the
end of this run Master showed `ESCR=268`, `TM=1`, `PPS=1`; Slave showed
`ESCR=256`, `TM=0`, `PPS=0`. In the historical 2026-09-27 reproduction, the
same exact milestone SOF hashes showed `ESCR=1036`, `TM=1`, `PPS=1` on both
boards after a 120-second post-program wait. Thus the present failure is not
explained by a different programmed image; why the Slave PPS/TM validity bits
remain clear in this session is unresolved.

All build, programming, observation, analysis, and post-capture dashboard files
for this attempt are under their `raw/{build,program,observe,analysis}/` run
tag paths. The combined `raw/build/20261001T060353Z/SHA256SUMS` was verified on
Laptop after transfer. No timing-closure or phase-offset criterion was applied.

### Next diagnostic boundary

Do not tune the phase servo based on this result. The next useful experiment
should capture the Slave PPS ESCR validity bits, exported and snapshot
TIME_VALID/PPS_VALID, WR PTP servo state, link gates, and reset indicators in
one read-only time series, and compare them with Master over the same run. It
must determine whether the Slave's TM/PPS validity bits ever assert and whether
that transition tracks the PTP servo state. Step6 remains pending until a
continuous 300-second valid window is actually measured.
