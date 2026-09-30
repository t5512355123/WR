# EXP-S6-WRH-SERVO-PHASE-QUARTER-STEP-20260930 — Report

## Verdict

```text
LAPTOP_MODEL_AND_PATCH_CHECKS          = PASS (3/3)
PAIN_DASHBOARD_ANALYZER_TESTS          = PASS (6/6)
MASTER_AND_SLAVE_FIRMWARE_BUILDS       = PASS
MASTER_AND_SLAVE_QUARTUS_BUILDS        = PASS (0 errors; 297 / 299 warnings)
MASTER_AND_SLAVE_PROGRAMMING           = PASS (1 device each; 0 errors/warnings)
STARTUP_READINESS                      = PASS (10 consecutive samples)
15S_SMOKE_1 / 15S_SMOKE_2              = PASS / PASS
300S_CAPTURE                           = PASS (300279 ms; 957 rows)
ALL_ROWS_STEP1 / GLOBAL_TIME / LOCKS   = PASS (957/957 each)
STRICT_ABS_CKO_LT_60_PS                = 351/957 rows (36.7%)
FULL_DASHBOARD_EQUIVALENT_QUALIFIED    = 315/957 rows (32.9%)
LONGEST_CONSECUTIVE_FULL_QUALIFIED_RUN = 11 rows (3099 ms span)
STEP6_STABLE_300S_OFFSET               = NOT ESTABLISHED
```

Both smokes and the 300-second capture repeatedly observed in-range readings;
the long-capture range was −275 to +306 ps. This is narrower than several
earlier diagnostic records, but those runs were not a same-session paired
A/B and did not independently read back the active FPGA image, so the entire
difference cannot be causally attributed to this patch. The 300-second
capture did not meet the requested stability requirement: most samples were
outside the strict ±60 ps band, and the longest consecutive fully-qualified
run was about 3.1 seconds. This candidate is **not** a stable-offset pass or a
Step 6 milestone.

## Candidate and provenance

- Git branch: `feat/file_cleanup`.
- Laptop and Pain source commit for this run:
  `c97d45f2f3ad028ded9ecf1e10060461a1edc432`.
- The candidate is the isolated patch
  [`candidate.patch`](candidate.patch), temporarily applied only to Pain's
  Step 6 build source. `WRH_SYNC_PHASE` changed from a full acquisition step
  to `offset_ps / 4`. The 60 ps threshold, `WRH_TRACK_PHASE` `/4` step, retry
  state machine, Step 5 controls, PPS/TAI behavior, RTL, SDB, and timing
  constraints were not changed.
- Frozen Step 6 source manifest passed before the experiment and again after
  reverse-applying the patch: **3219/3219** entries. Frozen milestone
  artifact manifest passed after the run: **4/4** entries. The tracked Pain
  worktree returned clean at `c97d45f2`.
- The candidate was built from source origin
  `74dc28862653d306e0450cf437ba6d3a230d979d` with Quartus Prime Standard
  Edition 17.0.0 Build 595.
- Candidate SOF SHA-256:
  - Master: `3682c148bf505e1f98e78adcdd257c31865fd57d53e7a11922f902ea016653b5`
  - Slave: `729ad82427470e631665318d6935ba94b354a584b98df0397e386700a113dd9e`
- Both full Quartus builds succeeded. Timing closure was not a functional gate
  for this experiment; reported `TIMING_CLOSED=NO` for both images.
- Programmer logs confirm Slave `DE5 [1-11.2]` then Master `DE5 [1-11.1]`,
  one configured device per board and zero programming errors or warnings.
- The Pain archive `/home/b10504072/04_WR_archive_step6_pass/` was not
  accessed. No consultant was contacted. No physical power cycle was done.

## Startup and smoke gates

The immediate post-program dashboard showed the expected startup state:
Slave PTP servo `UNINITIALIZED`, lock bits low, and Global Time waiting. A
read-only settling observer then obtained ten consecutive ready samples after
19 total samples over 208 seconds. At readiness, both boards had Step 1/link
and stable Global Time; all five Slave Step 5 lock fields and the signed
servo-offset/state fields were valid.

| Capture | Rows | Valid frames / reads | Step 1, Global Time, all locks | UCNT-paired rows | Strict CKO rows | Longest full-gate run | Result |
|---|---:|---:|---:|---:|---:|---:|---|
| Smoke 1, 15.227 s | 49 | 49/49 | 49/49 | 42/49 (85.7%) | 18/49 | 8 rows / 2201 ms | PASS |
| Smoke 2, 15.276 s | 50 | 50/50 | 50/50 | 48/50 (96.0%) | 18/50 | 8 rows / 2105 ms | PASS |

Both smokes had no reset change, invalid read, reader timeout, or early stop.
The strict offset rows and short consecutive runs justified starting the
predeclared long capture but did not by themselves establish stability.

## 300-second capture

Raw evidence: [`raw/observe/capture-300s.log`](raw/observe/capture-300s.log).
The run lasted **300279 ms** and completed normally with **957** sample rows.
Median per-row duration was **294.978 ms** (range 286.324–407.569 ms).

| Measure | Result |
|---|---:|
| Valid reads / diagnostic frames | 957/957 |
| Full Step 1 gate | 957/957 |
| Global Time and stable snapshots | 957/957 |
| All five Slave Step 5 lock fields | 957/957 |
| Reset/generation changes; reader timeouts/errors | 0; 0 |
| UCNT-matched phase-context rows | 859/957 |
| Strict `abs(CKO) < 60 ps` rows | 351/957 (36.7%) |
| Full dashboard-equivalent qualifying rows | 315/957 (32.9%) |
| Longest consecutive full-gate run | 11 rows; 3099 ms sample span |
| Valid CKO range | −275 to +306 ps |

Servo-state distribution from the sampled `SSTAT` field:

| State code | Rows | Strict CKO rows | Full-gate qualifying rows |
|---:|---:|---:|---:|
| 3 | 164 | 0 | 0 |
| 4 (`WAIT_OFFSET_STABLE`) | 418 | 270 | 240 |
| 5 (`TRACK_PHASE`) | 375 | 81 | 75 |

There were 136 sampled servo-state transitions. The raw adjacent-row analysis
found 123 CKO changes of at least 120 ps; UCNT changed in all 123, SETP in 27,
and DMS in 83. These are sequentially read diagnostic values, not atomic
same-cycle measurements, so they do not establish actuator causality. The
lower error range is evidence of progress under this candidate, but the
state/offset series still repeatedly left the strict band.

The post-capture dashboard showed both boards' link and Global Time valid and
all five Slave locks high, but the instantaneous Slave offset was **−72 ps**;
Step 6 correctly remained `NOT QUALIFIED`.

## Integrity and offline checks

- All **45/45** transferred raw files matched `raw/SHA256SUMS` on Laptop.
- Re-running `scripts/analysis/step6_dashboard_gate_capture.py` on Laptop
  matched Pain's saved analyzer result for the capture counts, range, and
  completeness fields.
- `scripts/tests/test_step6_servo_phase_quarter_step.py`: **3/3 PASS**.
- `scripts/tests/test_step6_dashboard_gate_capture.py`: **6/6 PASS**.
- Full build logs, build identities, candidate hashes, both programmer logs,
  startup observations, both smoke captures and analyses, postflight dashboard,
  and the raw checksum manifest are preserved under [`raw/`](raw/).

## Conclusion and next experiment

The acquisition quarter-step is a promising improvement but does not deliver
stable `<60 ps` offset. In this capture, only 81/375 sampled `TRACK_PHASE`
rows were strictly in range, versus 270/418 `WAIT_OFFSET_STABLE` rows. The
next single-variable candidate should retain the acquisition `/4` step and
change only the `WRH_TRACK_PHASE` correction from `offset_ps / 4` to
`offset_ps / 8`, testing whether gentler fine tracking reduces repeated
excursions while preserving the successful acquisition damping. Keep the
strict 60 ps gate and 300-second all-rows acceptance unchanged; build and
program it as a separate candidate, then measure again. Do not call this run a
stable-offset pass.
