# EXP-S6-WRH-SERVO-WAIT-COUNTER-RESET-ON-LOCK-20260930 — Report

## Verdict

```text
LAPTOP_OFFLINE_TESTS                  = PASS (4/4)
CANDIDATE_FIRMWARE_AND_QUARTUS_BUILDS = PASS (Master and Slave)
CANDIDATE_PROGRAMMING                 = PASS (Slave then Master; 0 errors/warnings)
FROZEN_SOURCE_MANIFEST                = PASS (3219/3219 before and after)
MILESTONE_ARTIFACT_MANIFEST            = PASS (4/4 before and after)
MASTER_GLOBAL_TIME                    = VALID (180/180 dashboard frames)
SLAVE_LINK_AND_STEP5_LOCK_GATES        = PASS (180/180 dashboard frames)
SLAVE_GLOBAL_TIME                     = NOT_VALID (0/180 dashboard frames)
SLAVE_SERVO_TRACK_PHASE               = NOT_REACHED (0/180 dashboard frames)
WAIT_COUNTER_RESET_BRANCH              = NOT_EXERCISED
TMVALID_ATTRIBUTION_CLASSIFICATION     = PASS: FAIL_PTP_SERVO_NOT_COMPLETE
STEP6A_GLOBAL_TIME                    = NOT_PASS
STRICT_CKO_300S_CAPTURE                = NOT_RUN
STABLE_OFFSET_300S                    = NOT_ESTABLISHED
```

The Slave never reached the Global-Time readiness gate, so the interleaved smoke and 300-second CKO capture were not started. The new reset line runs only on a successful `WAIT_OFFSET_STABLE → TRACK_PHASE` transition; no dashboard frame entered `TRACK_PHASE`. Consequently, this trial does not test whether clearing stale wait misses improves steady-state behavior and does not establish the cause of the incomplete servo.

## Candidate and provenance

- Branch: `feat/file_cleanup`.
- Exact repository commit built/programmed on Pain: `08b773792af6793967fbb9b61425006f0e9082fb`.
- Frozen Step 6 source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Compared with the previously measured `/2 acquisition + /12 tracking`, original-2×-guard baseline, the only functional edit was `s->missed_iters = 0` when `WAIT_OFFSET_STABLE` successfully transitions to `TRACK_PHASE`.
- The strict `<60 ps` entry threshold, ten-miss retry, `/2` acquisition correction, `/12` tracking correction, original 2× tracking fallback guard, and all other controls were held unchanged. The candidate patch was temporary on Pain and reverse-applied after build/program.
- Master SOF SHA-256: `a29431011e2333cbc0b4eaf90e09ac2cfa8ce301fe2f945d9eacc08567008b61`.
- Slave SOF SHA-256: `d750128b2e271cb0251a20c2a0679d452849586404c097610ed3b9adf2b894df`.
- Both full Quartus compilations succeeded; each programmer configured one DE5a (`0x02E660DD`) with zero errors/warnings. Timing closure was not achieved and is not a Step 6 offset verdict gate.

## Read-only dashboard observation

The dashboard ran at a 10-second cadence for its full 30-minute bound, producing 180 frames. No second JTAG reader ran concurrently.

| Signal | Master | Slave |
|---|---:|---:|
| Step 1/link and endpoint gates | PASS, 180/180 | PASS, 180/180 |
| Five Step 5 lock indicators | N/A | all high, 180/180 |
| Global Time valid/stable | 180/180 | 0/180 |
| `WAIT_OFFSET_STABLE` | N/A | 163 frames |
| `SYNC_PHASE` | N/A | 17 frames |
| `TRACK_PHASE` | N/A | 0 frames |
| Global-Time readiness reason | valid | offset not yet `<60 ps` |

The first Slave dashboard frame printed an extreme offset (`−1,998,914,745 ps`); it is retained in the raw log, and its cause is unclassified. The remaining 179 displayed phase-offset values ranged from `−2,494 ps` to `+4,764 ps`, with median `−1,619.5 ps`; none was within the strict `<60 ps` band. These are dashboard readiness values, **not** accepted interleaved CKO samples, and cannot substitute for the requested 300-second CKO capture.

## Read-only TM-valid source attribution

The observer was requested to run for 180 seconds at 1 Hz. It stopped itself after 10 consecutive incomplete-servo samples, at 10.793 seconds:

```text
classification                 = FAIL_PTP_SERVO_NOT_COMPLETE
PTP_STATE                      = 9 (SLAVE)
SERVO_STATE                    = 5 (WAIT_OFFSET_STABLE) on 9/10 samples;
                                 one sample was state 3 (SYNC_PHASE)
STATUS_TIME_VALID              = 0 (first and last)
PPS_VALID                      = 1; PPS_ESCR.TM_VALID = 0
link health                    = 1 on every sample
UCNT                           = 2015 → 2025
boot/reset change               = none
mapping/recovery streak         = 0 / 0
timeout/invalid/stale/unstable  = 0 / 0 / 0 / 0
stop reason                    = FAIL_PTP_SERVO_NOT_COMPLETE
```

The offline analyzer returned `tmvalid_attribution=PASS` because it consistently classified the observed failure boundary; it returned `step6a_slave_global_time=NOT_PASS`. This diagnostic PASS is not Global-Time or Step 6 success. The transport and link remained healthy while the servo failed to complete.

## Interpretation and next experiment

The reset-counter hypothesis was not exercised: the 30-minute dashboard showed no successful entry into `TRACK_PHASE`, and the observer ended while the servo was still incomplete. Therefore this line cannot explain the present `WAIT_OFFSET_STABLE` condition.

The next controlled candidate should compare against the previously measured `/2 acquisition + /12 tracking`, original-2×-guard baseline and change only the `SYNC_PHASE` correction from `offset_ps / 2` to the source-default full `offset_ps`. Keep tracking at `/12`, the original 2× fallback guard, strict `<60 ps` threshold, ten-miss retry, and all unrelated controls unchanged. This tests whether stronger acquisition correction can reach the entry band sooner; it is a hypothesis, not a proven cause. Repeat the same dashboard readiness gate, then the 15-second interleaved smoke, and only run 300-second acceptance if every accepted smoke row is strictly inside the band and all health/context gates pass. A long capture without readiness remains diagnostic-only and is not a pass.

## Integrity and restoration

- Focused offline test `scripts/tests/test_step6_servo_wait_counter_reset.py`: **4/4 PASS**; `git diff --check` clean.
- Frozen source manifest passed 3219/3219 before and after temporary patching; milestone artifact manifest passed 4/4 before and after.
- All 27 Pain raw files were copied to Laptop and individually compared with the remote SHA-256 values; all 27 matched. The local manifest is [raw/SHA256SUMS](raw/SHA256SUMS).
- No physical power cycle was performed. The protected `/home/b10504072/04_WR_archive_step6_pass/` path was not accessed.
