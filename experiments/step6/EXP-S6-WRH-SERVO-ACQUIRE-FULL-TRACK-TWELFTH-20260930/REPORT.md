# EXP-S6-WRH-SERVO-ACQUIRE-FULL-TRACK-TWELFTH-20260930 — Report

## Verdict

```text
LAPTOP_OFFLINE_TESTS                  = PASS (4/4)
CANDIDATE_FIRMWARE_AND_QUARTUS_BUILDS = PASS (Master and Slave)
CANDIDATE_PROGRAMMING                 = PASS (Slave then Master; 0 errors/warnings)
FROZEN_SOURCE_MANIFEST                = PASS (3219/3219 before and after)
MILESTONE_ARTIFACT_MANIFEST            = PASS (4/4 before and after)
SLAVE_STEP1_AND_STEP5_LOCK_GATES       = PASS (all accepted smoke/diagnostic rows)
SLAVE_GLOBAL_TIME_READINESS            = TRANSIENT (one +39 ps dashboard frame)
15S_SMOKE_STRICT_CKO_GATE              = FAIL (10/41 accepted rows)
300S_DIAGNOSTIC                        = COMPLETE (300.226 s; not acceptance)
300S_DIAGNOSTIC_STRICT_CKO              = FAIL (70/851 accepted rows; 8.23%)
STABLE_OFFSET_300S                    = NOT_ESTABLISHED
```

The candidate reached the Step 6 gate briefly, then left it before the smoke completed. Smoke health, context, timing, and transport gates passed, but the strict offset gate did not. A 300-second diagnostic was therefore run and is explicitly not acceptance evidence. No `STABLE_OFFSET_300S=PASS` claim is made.

## Candidate and provenance

- Branch: `feat/file_cleanup`.
- Exact repository commit built/programmed on Pain: `694357028bd12c72aa26547e9f66ce53c214d97b`.
- Frozen Step 6 source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Relative to the preceding `/2 acquisition + /12 tracking`, original-2×-guard baseline, the only control change was restoring `SYNC_PHASE` correction from `/2` to the frozen source's default full `offset_ps` correction. `TRACK_PHASE` stayed `/12`; the original 2× fallback guard, strict `<60 ps` threshold, ten-miss retry, and all unrelated controls stayed unchanged.
- The patch changed only the TRACK `/4 → /12` line relative to the frozen milestone source; acquisition remained its original full correction. The patch was temporary on Pain, reverse-applied after build/program, and both manifests passed again.
- Master SOF SHA-256: `9c7dab772a721e7ab4801d37ffb8316256f25db49a49c9757e978740c1095a1a`.
- Slave SOF SHA-256: `7e3a87038367ea357d8fa61e5bd4015166ed85369a078e0f70779a4aeb2bd86d`.
- Both full Quartus compilations succeeded. Each programmer configured one DE5a (`0x02E660DD`) with zero errors/warnings. Timing closure was not achieved and is outside this functional offset verdict.

## Dashboard and 15-second smoke

The read-only dashboard started after programming. At `16:37:49 +08:00`, Slave briefly showed `TRACK_PHASE`, offset `+39 ps`, `TIME_VALID=PPS_VALID=1`, Step 1 PASS, and all five Step 5 lock indicators high. The next 10-second frame showed offset `−1083 ps` and `NOT QUALIFIED`; this was transient readiness, not stable lock. The dashboard was stopped before the interleaved reader; no competing JTAG reader was used.

The 15-second smoke completed in `15.059 s`:

| Measurement | Result |
|---|---:|
| Rows / coherent accepted | 47 / 41 |
| UCNT-paired phase context | 41/41 accepted rows (100%) |
| Step 1, Global Time, five locks, reset | all required gates high; no reset change |
| Transport timeout / invalid count | 0 / 0 |
| Median row time | 294.975 ms |
| Accepted CKO min / max | `−4244 ps` / `+260 ps` |
| Strict `abs(CKO) < 60 ps` | 10/41 (24.39%) |

Telemetry and context quality passed; the strict CKO criterion failed, so this smoke did not qualify for 300-second acceptance.

## 300-second read-only diagnostic

The diagnostic completed normally in `300.226 s`: 957 rows, 851 coherent accepted rows (88.92%), with matched UCNT phase context on all 851 accepted rows. Every accepted row retained Step 1, valid Global Time, and all five Step 5 lock gates; there were zero reset changes, timeouts, or invalid-count errors.

| Measurement | Result |
|---|---:|
| Accepted CKO min / median / mean / max | `−2211 / −535 / −291.17 / +4216 ps` |
| Strict `abs(CKO) < 60 ps` | 70/851 (8.23%) |
| Median / maximum row time | 294.973 ms / 408.457 ms |
| Accepted rows by servo state | `SYNC_PHASE` 113; `TRACK_PHASE` 75; `WAIT_OFFSET_STABLE` 663 |
| In-band by state | `SYNC_PHASE` 0/113; `TRACK_PHASE` 55/75; `WAIT_OFFSET_STABLE` 15/663 |
| Accepted-row state transitions | 94 total, including 17 `TRACK_PHASE → SYNC_PHASE` |

The servo often reached the in-band region while in `TRACK_PHASE` (55/75 accepted TRACK rows), but the accepted stream spent most of its time in `WAIT_OFFSET_STABLE`. The full-acquisition candidate restored readiness quickly, yet did not improve sustained strict-offset coverage. This remains diagnostic evidence; state/phase fields are sampled in distinct frames and are not treated as same-cycle causal proof.

## Interpretation and next experiment

The source-default full acquisition correction can reach the Step 6 gate in this run, but the smoke and 300-second diagnostic show poor strict-offset occupancy. Compared with the measured `/2 + /12` reference, the full-acquisition variant is not a stability improvement. The diagnostic also confirms that TRACK can be in-band, while WAIT dominates the accepted rows.

Next, keep the source-default full acquisition correction and `/12` tracking, and change only the TRACK fallback guard from 2× to 4× the existing 60 ps threshold. This tests whether avoiding some TRACK-to-SYNC exits reduces the WAIT/SYNC churn now that the TRACK path is demonstrably reached. This is a hypothesis; the prior 4× trial used `/2` acquisition and never reached TRACK, so it did not test this condition. Keep the strict `<60 ps` entry threshold and the same smoke/300-second verdict gates.

## Integrity and restoration

- Focused offline test `scripts/tests/test_step6_servo_acquire_full_track_twelfth.py`: **4/4 PASS**; candidate patch apply check and runner Bash syntax passed before push.
- Frozen source manifest passed 3219/3219 before and after temporary patching; milestone artifact manifest passed 4/4 before and after.
- All 28 Pain raw files were copied to Laptop and individually compared with the remote SHA-256 values; all 28 matched. The local manifest is [raw/SHA256SUMS](raw/SHA256SUMS).
- No physical power cycle was performed. The protected `/home/b10504072/04_WR_archive_step6_pass/` path was not accessed.
