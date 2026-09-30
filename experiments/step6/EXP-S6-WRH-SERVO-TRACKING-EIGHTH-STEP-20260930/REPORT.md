# EXP-S6-WRH-SERVO-TRACKING-EIGHTH-STEP-20260930 — Report

## Verdict

```text
LAPTOP_OFFLINE_TESTS                    = PASS (2/2)
FROZEN_SOURCE_MANIFEST                  = PASS (3219/3219 before and after)
FROZEN_MILESTONE_ARTIFACT_MANIFEST      = PASS (4/4 after)
MASTER_AND_SLAVE_FIRMWARE_BUILDS        = PASS
MASTER_AND_SLAVE_QUARTUS_BUILDS         = PASS (Full Compilation successful)
MASTER_AND_SLAVE_PROGRAMMING            = PASS (one device each; zero errors/warnings)
BOUNDED_STARTUP_READINESS               = NOT REACHED (29m56s after programming)
SETTLING_DASHBOARD                      = 168 frames (27m50s logged)
SLAVE_STEP1_AND_FIVE_LOCKS               = PASS (168/168 frames)
SLAVE_GLOBAL_TIME_VALID                 = NO (TIME_VALID/PPS_VALID=0 in 168/168)
SLAVE_STRICT_ABS_OFFSET_LT_60_PS        = 0/168
TRACK_PHASE_PATH_EXERCISED              = NO (0 dashboard samples)
15S_SMOKES                              = NOT RUN (readiness gate not met)
300S_OFFSET_CAPTURE                     = NOT RUN
STABLE_OFFSET_300S                      = NOT ESTABLISHED
```

Both board images built and programmed successfully, but the bounded
post-program settling window never established the capture-entry gate. The
Slave remained outside the strict phase-offset band in every logged sample,
so the planned smokes and 300-second capture were correctly not started.
This is not a 300-second stability failure measurement; the stability target
was not reached or tested. It is also not evidence that the one-eighth
`TRACK_PHASE` correction helped or harmed, because the observed state never
entered that branch.

## Candidate and provenance

- Laptop/Pain branch: `feat/file_cleanup`.
- Exact repository commit built on Pain:
  `577b8716c21de262e98617556367e91ce810ffb0`.
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- The composite temporary candidate retained the acquisition correction at
  `offset_ps / 4` and changed only the tracking correction from
  `offset_ps / 4` to `offset_ps / 8` relative to the prior quarter-step
  candidate. The patch was applied only to the Pain build copy of the frozen
  Step 6 source; the tracked frozen source and milestone images were not
  edited.
- Quartus Prime Standard Edition: 17.0.0 Build 595. Master and Slave firmware
  and full Quartus compilation completed successfully. `TIMING_CLOSED=NO` for
  both builds; timing closure is not a Step 6 functional gate.
- Candidate Master SOF SHA-256:
  `66dfa98e1c3d24e6bebd3f65f31fdbd94efdcc0872279311e63cb6d80b4f2a30`.
- Candidate Slave SOF SHA-256:
  `bbeb62f18577d9b4a9c47427fecd1ac6edfc343550b653d399f7f158d805bbe2`.
- Programmer logs show Slave `DE5 [1-11.2]` programmed first and Master
  `DE5 [1-11.1]` second. Each configured one device with zero programming
  errors and warnings. Programming completed at 2026-09-30 09:04:42 +08:00.

## Bounded settling observation

The post-program dashboard at 09:05:20 showed the expected Slave startup
transient (`SYNC_TAI`, Step 5 locks low, Global Time invalid). The subsequent
read-only settling dashboard logged 168 frames from 09:06:48 through 09:34:38
+08:00 at a requested 10-second interval. The final sample was 29m56s after
programming completed, meeting the predeclared 30-minute settling bound; the
dashboard log itself spans 27m50s because it started after the initial
post-program sample.

| Slave observation | Result |
|---|---:|
| Dashboard frames | 168 |
| Step 1/link gate | PASS, 168/168 |
| Helper, MainFreq, MainPhase, MainLock, PSTAT | all 1, 168/168 |
| `TIME_VALID=1` and `PPS_VALID=1` | 0/168 |
| Servo state `WAIT_OFFSET_STABLE` | 153 frames |
| Servo state `SYNC_PHASE` | 15 frames |
| Servo state `TRACK_PHASE` | 0 frames |
| Numeric phase-offset samples | 168 |
| Offset range | −1243 to +3633 ps |
| Strict `abs(offset) < 60 ps` | 0/168 |

At the post-settling one-shot dashboard, Step 1 and all five Slave lock bits
were still high, but the offset was `+3644 ps`, Global Time was invalid, and
Step 6 remained `WAITING`. No reset/generation counter series was captured in
this settling run, so reset-generation stability is not adjudicated here.

The acquisition state machine only enters `TRACK_PHASE` after a qualified
offset falls below the 60 ps stability threshold. Since no logged sample met
that gate and the observer recorded no `TRACK_PHASE` frame, this run did not
exercise the candidate's one-eighth tracking line. Dashboard samples are
10-second observations and do not prove that no brief sub-60 ps excursion
occurred between samples; the unavailable stable Global-Time snapshots and
the absence of a TRACK sample are the decisive missing entry evidence.

## Integrity and offline validation

- Candidate patch unit tests:
  `scripts/tests/test_step6_servo_track_eighth_step.py` — **2/2 PASS**.
- The transferred archive SHA-256 matched Pain's recorded value:
  `c40742cca199732e69c1ddbe0d96d305460f1d45967563de0c7c5e6e28324d06`.
- `raw/SHA256SUMS` covers all 25 transferred raw evidence files, including
  the original evidence archive.
- After reverse-applying the temporary patch, the frozen source manifest
  passed **3219/3219** entries and the frozen milestone artifact manifest
  passed **4/4** entries. The Pain repository was restored to clean tracked
  state at the recorded commit.
- No physical power cycle was performed. The archive
  `/home/b10504072/04_WR_archive_step6_pass/` was not accessed.
- Build, programming, preflight, restoration, and complete dashboard logs are
  retained under [`raw/`](raw/).

## Conclusion and next experiment direction

The `/8` tracking hypothesis remains **untested on hardware** because the
state machine did not reach `TRACK_PHASE`. The useful new boundary is the
acquisition/re-entry path: while all Step 5 lock bits and Step 1/link stayed
high, the servo was observed in `WAIT_OFFSET_STABLE` or `SYNC_PHASE`, with no
valid Global-Time snapshot and no logged in-band phase sample.

The next experiment should first capture the acquisition transition at the
existing high-rate servo-observer cadence, pairing `SSTAT`, signed `CKO`,
`UCNT`, `SETP`, and `DMS` around the `SYNC_PHASE` → `WAIT_OFFSET_STABLE`
retries. That will distinguish an in-band crossing missed by the 10-second
dashboard from a correction that is not converging. Do not change the
tracking step again until this candidate actually enters `TRACK_PHASE`; keep
the acceptance requirement unchanged: every accepted row in the complete
300-second capture must satisfy strict `abs(CKO) < 60 ps` with the required
health and lock gates valid.
