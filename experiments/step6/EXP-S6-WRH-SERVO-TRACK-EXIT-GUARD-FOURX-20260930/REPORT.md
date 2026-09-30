# EXP-S6-WRH-SERVO-TRACK-EXIT-GUARD-FOURX-20260930 — Report

## Verdict

```text
LAPTOP_OFFLINE_TESTS                  = PASS (3/3)
CANDIDATE_FIRMWARE_AND_QUARTUS_BUILDS = PASS (Master and Slave)
CANDIDATE_PROGRAMMING                 = PASS (Slave then Master; 0 errors/warnings)
FROZEN_SOURCE_MANIFEST                = PASS (3219/3219 before and after)
MILESTONE_ARTIFACT_MANIFEST            = PASS (4/4 before and after)
MASTER_GLOBAL_TIME                    = VALID (180/180 dashboard frames)
SLAVE_LINK_AND_STEP5_LOCK_GATES        = PASS (180/180 dashboard frames)
SLAVE_GLOBAL_TIME                     = NOT_VALID (0/180 dashboard frames)
SLAVE_SERVO_TRACK_PHASE               = NOT_REACHED (0 dashboard frames)
TRACK_EXIT_GUARD_EXERCISED             = NO
TMVALID_ATTRIBUTION_CLASSIFICATION     = PASS: FAIL_PTP_SERVO_NOT_COMPLETE
STEP6A_GLOBAL_TIME                    = NOT_PASS
STRICT_OFFSET_300S_CAPTURE             = NOT_RUN
STABLE_OFFSET_300S                    = NOT_ESTABLISHED
```

The run did not meet the Slave Global-Time/readiness gate. Therefore no offset smoke or 300-second acceptance capture was started. The 4× tracking-exit guard was never reached, so this run makes no claim about whether that guard improves offset stability.

## Candidate and provenance

- Branch: `feat/file_cleanup`.
- Exact repository commit built on Pain: `7c2c34d250147086b5a700ae4debccedf66e47d8`.
- Frozen Step 6 source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Relative to the preceding `/2 acquisition + /12 tracking` candidate, the only functional change was widening the `TRACK_PHASE` fallback guard from `2 × 60 ps` to `4 × 60 ps` (120 ps → 240 ps). Acquisition remained `offset_ps / 2`, tracking remained `offset_ps / 12`, and the strict `<60 ps` entry threshold and other control behavior were unchanged.
- The candidate patch was applied only temporarily to the frozen source package for the build, then reverse-applied. Both frozen manifests passed before and after.
- Master SOF SHA-256: `60562a9da59a3dddadec41057f21a53c49332d3632e8ccdc7a145b1ff71b4bbe`.
- Slave SOF SHA-256: `607b3fbf3cfa6bf1eb00a6fd65f15466c1d2a5bdc71d8401b6d78fa6bfa69a1a`.
- Both programmers reported one configured device (JTAG ID `0x02E660DD`) and zero errors/warnings. Both full Quartus compilations succeeded. Timing closure was not achieved; it is not part of the functional offset verdict.

## Dashboard readiness observation

The read-only dashboard ran from `2026-09-30T13:56:36+08:00` through `2026-09-30T14:26:25+08:00`: 180 frames at the 10-second interval, over 29 minutes 49 seconds. No other JTAG reader ran concurrently.

| Signal | Master | Slave |
|---|---:|---:|
| Step 1/link gate | PASS in 180/180 | PASS in 180/180 |
| Five Step 5 lock indicators | not applicable | all high in 180/180 |
| Global Time valid/stable | 180/180 | 0/180 |
| Servo `WAIT_OFFSET_STABLE` | N/A | 166 frames |
| Servo `SYNC_PHASE` | N/A | 14 frames |
| Servo `TRACK_PHASE` | N/A | 0 frames |
| Displayed WR phase offset | N/A | min −6456 ps; median +1208 ps; max +3921 ps |
| Strict `abs(offset) < 60 ps` | N/A | 0/180 |

The Slave remained at `TIME_VALID=0 / PPS_VALID=0` with the reason “PTP servo offset not yet <60 ps.” These dashboard offsets are readiness observations, not the interleaved CKO acceptance capture.

## Read-only TM-valid source attribution

The existing attribution observer was requested for 180 seconds at 1 Hz and stopped itself after 10 samples (10.791 seconds) when its declared early-stop rule detected 10 consecutive incomplete PTP-servo samples:

```text
classification                 = FAIL_PTP_SERVO_NOT_COMPLETE
PTP_STATE                      = 9 (SLAVE)
last SERVO_STATE               = 5 (WAIT_OFFSET_STABLE)
STATUS_TIME_VALID              = 0 (first and last)
PPS_ESCR.TM_VALID               = 0 (first and last)
mapping_streak_max             = 0
recovery_streak_max            = 0
reset_seen                     = false
snapshot_delta_first_to_last   = 0
timeout / invalid / stale /
  unstable transport errors    = 0 / 0 / 0 / 0
Step6A Slave Global Time       = NOT_PASS
```

The attribution analyzer returned `tmvalid_attribution=PASS` because it consistently classified the failure boundary; that diagnostic PASS does **not** mean Global Time or Step 6 passed. The source evidence points to the WR PTP servo not completing phase acquisition, rather than a mismatch between the exported time-valid signal and `PPS_ESCR.TM_VALID`.

## Interpretation and next experiment

The run confirms a startup/readiness failure, not a steady-state offset result. Because no dashboard sample entered `TRACK_PHASE`, widening its exit guard could not have affected any observed sample; its effect remains untested.

A source audit also found that `missed_iters` is cleared when it reaches 10 but is not cleared when `WAIT_OFFSET_STABLE` successfully enters `TRACK_PHASE`. A follow-up should test this state-counter behavior as a separate, one-line candidate, using the known `/2 acquisition + /12 tracking` baseline and the original 2× exit guard. The 60 ps acceptance threshold remains unchanged. This is a source-derived hypothesis, not a proven cause; the next candidate still must pass the same readiness, smoke, and 300-second strict-offset gates.

## Integrity

- Focused offline test: `scripts/tests/test_step6_servo_track_exit_guard_fourx.py`, 3/3 passed; `git diff --check` clean.
- Remote frozen-source manifest: 3219 entries, all OK before and after build; milestone-artifact manifest: 4 entries, all OK before and after.
- All 27 raw build/program/preflight/dashboard/attribution files were copied from Pain and individually SHA-256 verified against the remote originals. See [raw/SHA256SUMS](raw/SHA256SUMS).
- No physical power cycle was performed. The protected `/home/b10504072/04_WR_archive_step6_pass/` path was not accessed.
