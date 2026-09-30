# EXP-S6-WRH-SERVO-FULL-ACQUIRE-TRACK-TWELFTH-GUARD-FOURX-20260930 — Report

## Verdict

```text
LAPTOP_CANDIDATE_TESTS                 = PASS (4/4)
DASHBOARD_CAPTURE_ANALYZER_TESTS       = PASS (6/6)
PAIN_FROZEN_SOURCE_MANIFEST             = PASS (3219/3219 before and after)
PAIN_MILESTONE_ARTIFACT_MANIFEST        = PASS (4/4 before and after)
MASTER_AND_SLAVE_FIRMWARE_BUILDS        = PASS
MASTER_AND_SLAVE_QUARTUS_BUILDS         = PASS
SLAVE_THEN_MASTER_PROGRAMMING           = PASS (one device each; zero errors/warnings)
15S_SMOKE_TELEMETRY_AND_HEALTH          = PASS (40 coherent accepted; all gates high)
15S_SMOKE_STRICT_ABS_CKO_LT_60_PS       = FAIL (0/40 accepted)
300S_READ_ONLY_DIAGNOSTIC               = COMPLETE (300023 ms; 953 rows)
300S_DIAGNOSTIC_STRICT_ABS_CKO_LT_60_PS = FAIL (0/857 accepted)
STABLE_OFFSET_300S                       = NOT_ESTABLISHED
STEP6                                  = NOT_PASS
```

The candidate compiled and programmed successfully, but did not produce even one accepted CKO sample strictly inside `(-60 ps, +60 ps)` in either the smoke or the 300-second diagnostic. The diagnostic is not an acceptance capture, and this run is not a Step 6 pass.

## Candidate and provenance

- Branch: `feat/file_cleanup`.
- Exact Laptop/Pain commit: `059c7c9eb707251054a442b236edab25c8296c1b`.
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- The candidate preserved source-default full `SYNC_PHASE` acquisition and `WRH_TRACK_PHASE = offset_ps / 12`. Its only change relative to the preceding full-acquisition + /12-tracking candidate was widening the TRACK fallback guard from 2× to 4× the existing 60 ps threshold. The patch was applied only to the temporary Pain build copy of the frozen Step 6 source, then reversed.
- Both Quartus 17.0 Build 595 compilations succeeded. Timing was not closed (Master setup slack +0.262 ns; Slave −0.659 ns); timing closure is not the functional acceptance criterion.
- Master SOF SHA-256: `5191ce79d58cd091fde2157adc93a729ecd65e7921a13ec6c640396e828a1d2c`.
- Slave SOF SHA-256: `f307429491930e5cf7e5e38c0e04fd610f0fbe887e94e5732a7a55cb99e99432`.
- Programming logs show Slave `DE5 [1-11.2]` and then Master `DE5 [1-11.1]`, each with one configured device and zero programming errors or warnings.
- Source and artifact manifests were restored and passed after the temporary source patch.

## Readiness, smoke, and diagnostic results

The read-only 10-second dashboard ran 44 frames from 17:22:28 through 17:29:38 (+08:00). Both boards' link gates remained available, and the Slave showed all five Step 5 lock indicators high in the smoke and diagnostic. Stable, valid Global-Time snapshots were available when captures began. The dashboard did not qualify the Slave's Step 6 phase offset as <60 ps.

| Measurement | 15-second smoke | 300-second diagnostic |
|---|---:|---:|
| Capture duration | 15054 ms | 300023 ms |
| Sample rows | 48 | 953 |
| Coherent accepted rows | 40 | 857 |
| Accepted UCNT-matched phase context | 40/40 | 857/857 |
| Read / diagnostic / global-time / stable snapshot rows | 48/48 | 953/953 |
| Step 1 and all five Step 5 lock rows | 48/48 | 953/953 |
| Reset changes; timeout / invalid / read errors | 0; 0 / 0 / 0 | 0; 0 / 0 / 0 |
| Accepted CKO min / median / mean / max | −2238 / −438 / +96.82 / +3520 ps | −2502 / −958 / −172.97 / +4055 ps |
| Strict `abs(CKO) < 60 ps` | 0/40 | 0/857 |
| Median row time | 296.668 ms | 295.024 ms |

The 300-second accepted rows were sampled in servo states 3 (75 rows) and 5 (782 rows); state 4 (`TRACK_PHASE`) was not observed. The servo therefore did not establish a sustained tracking state under this wider fallback guard. This is an observed state distribution, not proof that the guard alone caused the failure.

## Evidence integrity

- All 28 files copied from Pain matched Pain's SHA-256 values: **28/28**.
- `raw/SHA256SUMS` covers those 28 transferred raw files; local manifest verification passed with **0 mismatches**.
- The saved smoke and diagnostic captures independently analyze as complete, read-only captures with consistent observer summaries and no reset, timeout, invalid-read, or qualification-marker mismatch.
- No physical power cycle was performed. The protected Pain archive `/home/b10504072/04_WR_archive_step6_pass/` was not accessed.
- Build, programming, dashboard, smoke, diagnostic, restoration, and checksums are retained under [`raw/`](raw/).

## Next experiment direction

This 4× guard trial failed to observe `TRACK_PHASE` and yielded 0/857 accepted in-band samples. The next controlled candidate should return to a tested 2× guard and use the previously measured quarter-step acquisition baseline, changing only the tracking correction from `offset_ps / 4` to `offset_ps / 8`. That isolates the gentler tracking hypothesis from the quarter-step acquisition candidate, which previously narrowed the 300-second CKO range but did not achieve stability. Retain the strict <60 ps rule and the same health/context gates; only a 300-second capture with every accepted sample inside the strict band can establish the goal.
