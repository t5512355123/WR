# EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-TWELFTH-20260930 — Report

## Verdict

```text
LAPTOP_OFFLINE_TESTS                    = PASS (3/3)
FROZEN_SOURCE_MANIFEST                  = PASS (3219/3219 before and after)
FROZEN_MILESTONE_ARTIFACT_MANIFEST      = PASS (4/4 before and after)
MASTER_AND_SLAVE_FIRMWARE_BUILDS        = PASS
MASTER_AND_SLAVE_QUARTUS_BUILDS         = PASS (Full Compilation successful)
MASTER_AND_SLAVE_PROGRAMMING            = PASS (one device each; 0 errors/warnings)
SLAVE_STARTUP_AND_GLOBAL_TIME           = PASS (dashboard reached valid/stable readiness)
15S_SMOKE_HEALTH_AND_TELEMETRY          = PASS (45/48 coherent accepted rows)
15S_STRICT_OFFSET_GATE                  = FAIL (20/45 accepted rows; 44.4%)
300S_DIAGNOSTIC_CAPTURE                 = COMPLETE (300.403 s; not an acceptance run)
300S_DIAGNOSTIC_STRICT_OFFSET           = FAIL (310/857 accepted rows; 36.2%)
STABLE_OFFSET_300S                      = NOT_ESTABLISHED
```

The candidate did not meet the predeclared smoke offset gate, so it was not eligible for the 300-second acceptance run. A separate 300-second read-only diagnostic was run to characterize the excursions; it is explicitly not acceptance evidence.

## Candidate and provenance

- Branch: `feat/file_cleanup`.
- Exact repository commit built on Pain: `4c1adf73ab762506939163d467fb8c6b35bca9b4`.
- Frozen Step 6 source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Relative to the preceding `/2 acquisition + /16 tracking` candidate, the only functional change was `WRH_TRACK_PHASE` correction `/16 → /12`. `WRH_SYNC_PHASE` remained `/2`; all thresholds, state transitions, timeout/retry behavior, PPS/TAI logic, lock controls, RTL, SDB, reset, and timing constraints remained unchanged.
- The candidate patch was applied only to the temporary frozen-source copy for firmware/Quartus builds, then reverse-applied. The frozen package and milestone artifacts were verified restored.
- Master SOF SHA-256: `2beddef2b481c96d6b94bf195fc3ea3cd87513bc776b6884cc775ee8d08f763b`.
- Slave SOF SHA-256: `dd5d2e72d6fcde92ace62cf51cfd7fc333c5af1d8d8dd4ebfdc8437b3bba701b`.
- Both boards were programmed successfully, Slave first then Master. Each log reports one configured device, JTAG ID `0x02E660DD`, and zero errors or warnings.
- Both full Quartus compilations succeeded. Timing closure was not achieved (Master WNS `+0.262 ns`; Slave WNS `−0.659 ns`); timing closure is not the functional offset criterion.

## Startup and 15-second smoke

The read-only dashboard began at `2026-09-30 12:54:22 +08:00`. Its first sample showed the Slave uninitialized and Global Time waiting. At `12:57:11`, it showed `TRACK_PHASE`, `−37 ps`, valid Global Time, and all five Slave Step 5 lock indicators asserted. The dashboard was stopped before starting the interleaved reader; no concurrent JTAG reader was used.

| Measurement | Result |
|---|---:|
| Rows / elapsed | 48 / 15.115 s |
| Coherent accepted rows | 45/48 (93.75%) |
| UCNT-paired phase context | 45/45 accepted rows |
| Step 1, Global Time, and five lock gates | all high in 45/45 accepted rows |
| Reset changes / timeouts / invalid-count | 0 / 0 / 0 |
| Median / maximum row time | 294.869 ms / 404.788 ms |
| Accepted CKO range | `−66 ps` to `+187 ps` |
| Strict `abs(CKO) < 60 ps` | 20/45 (44.4%) |

The telemetry/context/transport gates passed, but offset did not; the smoke therefore failed the predeclared acceptance entry condition.

## 300-second read-only diagnostic

The diagnostic completed normally in `300.403 s`: 959 rows, 857 coherent accepted rows (89.36%), and matched UCNT phase context on all 857 accepted rows. On every accepted row, Step 1, valid/stable Global Time, and all five Step 5 lock bits were high. There were zero reset changes, timeouts, or invalid-count errors.

| Measurement | Result |
|---|---:|
| Accepted CKO min / median / mean / max | `−322 / +5 / +1.322 / +296 ps` |
| Strict `abs(CKO) < 60 ps` | 310/857 (36.17%) |
| Median / maximum row time | 294.780 ms / 408.340 ms |
| Servo states among accepted rows | `SYNC_PHASE` 154; `TRACK_PHASE` 398; `WAIT_OFFSET_STABLE` 305 |
| In-band rows by state | `SYNC_PHASE` 0/154; `TRACK_PHASE` 262/398; `WAIT_OFFSET_STABLE` 48/305 |
| Observed accepted-row state transitions | 146 total, including 44 `TRACK_PHASE → SYNC_PHASE` |

The average and median are near zero, but the excursions are far outside the strict band; central tendency does not establish stability. The recurring state transitions are consistent with repeated reacquisition, but this capture does not prove that the tracking exit guard alone causes the offset excursions. The phase-context measurement and servo decision value are captured in separate read intervals, so they cannot be treated as same-cycle causal evidence.

## Integrity and restoration

- Focused offline test `scripts/tests/test_step6_servo_acquire_half_track_twelfth.py`: **3/3 PASS**; `git diff --check` clean.
- Frozen source manifest passed **3219/3219** both before and after the temporary patch. Milestone artifact manifest passed **4/4** both before and after.
- All 28 raw files were copied from Pain and individually SHA-256 compared against the remote originals; all matched. The local manifest is `raw/SHA256SUMS`.
- No physical power cycle was performed. The protected `/home/b10504072/04_WR_archive_step6_pass/` path was not accessed.

## Next controlled experiment

Keep acquisition at `/2` and tracking correction at `/12`. Change only the `TRACK_PHASE` fallback guard from `abs(offset_ps) > 2 × WRH_SERVO_OFFSET_STABILITY_THRESHOLD` to `> 4 × ...`. The strict stability threshold and `WAIT_OFFSET_STABLE` entry condition stay unchanged. This tests whether allowing the existing tracking correction to continue through moderate excursions reduces the observed state churn; it is a hypothesis, not a presumed fix. Keep the same health/telemetry gates and strict `<60 ps` acceptance rule. Run the 15-second smoke first; only a smoke with every accepted row inside the strict band may proceed to 300-second acceptance. If smoke health passes but offset does not, any longer capture must be labeled diagnostic only.
