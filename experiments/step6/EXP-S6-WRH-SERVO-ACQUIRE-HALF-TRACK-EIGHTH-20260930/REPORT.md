# EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-EIGHTH-20260930 — Report

## Verdict

```text
LAPTOP_OFFLINE_TESTS                    = PASS (2/2)
FROZEN_SOURCE_MANIFEST                  = PASS (3219/3219 before and after)
FROZEN_MILESTONE_ARTIFACT_MANIFEST      = PASS (4/4 before and after)
MASTER_AND_SLAVE_FIRMWARE_BUILDS        = PASS
MASTER_AND_SLAVE_QUARTUS_BUILDS         = PASS (Full Compilation successful)
MASTER_AND_SLAVE_PROGRAMMING            = PASS (one device each; zero errors/warnings)
SLAVE_STEP1_AND_FIVE_LOCKS               = PASS (all 48 smoke rows)
SLAVE_GLOBAL_TIME_VALID_AND_STABLE       = PASS (all 48 smoke rows)
TRACK_PHASE_PATH_EXERCISED                = YES
15S_SMOKE_TELEMETRY                       = PASS (42 coherent accepted rows; median 295.464 ms)
15S_STRICT_OFFSET_GATE                    = FAIL (17/42 accepted rows; 40.5%)
300S_OFFSET_CAPTURE                       = NOT RUN (smoke gate failed)
STABLE_OFFSET_300S                        = NOT ESTABLISHED
```

The candidate restored Global Time and reached `TRACK_PHASE`, unlike the
immediately preceding run. However, the 15-second gate smoke did not keep
every accepted phase sample strictly inside `(-60 ps, +60 ps)`. The required
300-second capture was therefore not started. This is not a 300-second
stability failure measurement; the acceptance-duration test was not run.

## Candidate and provenance

- Laptop/Pain branch: `feat/file_cleanup`.
- Exact repository commit built on Pain: `f8ecf96a8cad3aa7061db1e14a40d50435beb072`.
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Relative to the previously programmed `/4` acquisition + `/8` tracking
  candidate, this candidate changes only the acquisition correction from
  `offset_ps / 4` to `offset_ps / 2`; tracking remains `offset_ps / 8`.
  Applied to the untouched frozen source, the recorded temporary diff shows
  both final values: `WRH_SYNC_PHASE = /2` and `WRH_TRACK_PHASE = /8`.
- The patch was applied only to the temporary Pain build copy of the frozen
  Step 6 source. It was reverse-applied after the build; the frozen package
  and milestone artifacts were verified unchanged.
- Quartus Prime Standard Edition: 17.0.0 Build 595. Both firmware and full
  Quartus builds succeeded. `TIMING_CLOSED=NO` for both; timing closure is
  not a functional Step 6 gate.
- Candidate Master SOF SHA-256:
  `c92f9a41ff602e239ddaa2612b2dcdc69e13a81ea36426bf569c33975c32c4a7`.
- Candidate Slave SOF SHA-256:
  `9ff84c93cc94ef6ac485be28b260574328ee4c9053cecfbd5a57025cf75b4c4c`.
- Programming completed at 2026-09-30 10:40:53 +08:00. The Slave
  `DE5 [1-11.2]` was programmed first, then Master `DE5 [1-11.1]`; each log
  reports one configured device and zero errors or warnings.

## Startup and dashboard observations

The post-program dashboard at 10:42:16 showed the Slave at
`WAIT_OFFSET_STABLE`, `+5089 ps`, with invalid Global Time. The read-only
dashboard then observed:

| Time (+08:00) | Servo state | Offset | Global Time / Step 6 |
|---|---|---:|---|
| 10:42:25 | `WAIT_OFFSET_STABLE` | +5048 ps | invalid / waiting |
| 10:42:35 | `SYNC_PHASE` | −186 ps | invalid / waiting |
| 10:42:45 | `TRACK_PHASE` | −16 ps | valid |
| 10:42:55 | `TRACK_PHASE` | −30 ps | valid |
| 10:43:05 | `TRACK_PHASE` | −73 ps | valid, offset not qualified |
| 10:43:15 | `TRACK_PHASE` | +10 ps | valid |
| 10:43:25 | `WAIT_OFFSET_STABLE` | +145 ps | valid, offset not qualified |

This proves that half-step acquisition can reach valid Global Time and enter
tracking promptly, but the 10-second dashboard samples already show that the
strict phase band is not continuously maintained. The later point-in-time
dashboard at 10:48:49 showed valid Global Time and `−52 ps`; a single sample
does not satisfy the stability requirement.

## High-rate smoke results

The read-only offset/update correlation smoke accepted 20/20 samples with zero
retries in 1.589 seconds. Its final coherent samples showed `WAIT_OFFSET_STABLE`
and offsets between `−92` and `−94 ps`; this is diagnostic data, not a Step 6
pass.

The dashboard-equivalent 15-second interleaved smoke completed without
transport errors, timeout, reset stop, or invalid-read count:

| Measurement | Result |
|---|---:|
| Samples / elapsed | 48 / 15.128 s |
| Coherent accepted UCNT-paired rows | 42/48 (87.5%) |
| Step 1, Global Time, and five lock gates | all high in 48/48 rows |
| Reset-change rows | 0/48 |
| Median row time | 295.464 ms (maximum 405.319 ms) |
| Accepted `CKO` range | −120 to +243 ps |
| Strict `abs(CKO) < 60 ps` | 17/42 accepted rows (40.5%) |
| Quartus Tcl / SignalTap errors and warnings | 0 / 0 |

The smoke met the row-count, coherent-context fraction, row-time, and
per-row health/lock prerequisites. It failed the decisive strict-offset
prerequisite, so the predeclared 300-second capture was correctly not run.

## Integrity and restoration

- Candidate patch contract/model tests:
  `scripts/tests/test_step6_servo_acquire_half_track_eighth.py` — **2/2 PASS**.
- The transferred evidence archive SHA-256 matched Pain's recorded value:
  `2a3c13e75cd9bf3a119c3b9aeaf4094a1c7d19c7efea853752ca91170778c3d5`.
- `raw/SHA256SUMS` covers all 29 raw evidence files, including the original
  archive; all checksums verified locally.
- After reverse-applying the temporary patch, the frozen source manifest
  passed **3219/3219** entries and the frozen milestone-artifact manifest
  passed **4/4** entries. The repository tracked worktree was restored at
  the experiment commit before its report was added.
- No physical power cycle was performed. The frozen archive
  `/home/b10504072/04_WR_archive_step6_pass/` was not accessed.
- Build, programming, preflight, restoration, and observation evidence is
  retained under [`raw/`](raw/).

## Conclusion and next experiment direction

The acquisition change improved the startup boundary: the Slave reached
`TRACK_PHASE`, valid Global Time, and an in-band offset during dashboard
observation. But the high-rate smoke shows substantial excursions while all
other gates remain valid (`−120` to `+243 ps` in accepted rows). The
`/8 TRACK_PHASE` path was exercised, so the next controlled candidate should
keep acquisition at `/2` and test one smaller tracking correction, `/16`,
against the same strict smoke gate. Treat this only as a damping hypothesis;
do not claim it will pass until measured. Run the short smoke first and start
the 300-second capture only if every accepted smoke row meets the existing
strict `<60 ps` and health/lock requirements.
