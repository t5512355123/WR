# EXP-S6-WRH-SERVO-EIGHTH-ACQUIRE-EIGHTH-TRACK-20260930 — Report

## Verdict

```text
FROZEN_SOURCE_MANIFEST_RESTORED       = PASS (3,219/3,219)
MILESTONE_ARTIFACT_MANIFEST_RESTORED   = PASS (4/4)
MASTER_AND_SLAVE_BUILDS                 = PASS
SLAVE_THEN_MASTER_PROGRAMMING           = PASS
30-MINUTE_READ_ONLY_DASHBOARD           = COMPLETE (179 paired frames)
SLAVE_STEP5_LOCKS                       = PASS (179/179 frames)
STRICT_DASHBOARD_OFFSET_ABS_LT_60_PS    = FAIL (0/179)
SERVO_TRACK_PHASE                       = NOT_REACHED (0 frames)
15S_INTERLEAVED_SMOKE                   = STOPPED (5 untrusted rows)
300S_DIAGNOSTIC                         = NOT RUN (smoke gate not met)
STABLE_OFFSET_300S                      = NOT ESTABLISHED
STEP6                                   = NOT PASS
```

The acquisition-damping hypothesis did not reach the strict offset band or
enter `TRACK_PHASE` during the observation. No evidence from this run
supports a Step 6 stable-offset pass.

## Provenance and scope

- Branch: `feat/file_cleanup`.
- Laptop, GitHub, and Pain source revision used for the candidate: `e30b7221c07adcf720dff85e2336d781aec7b502`.
- Relative to the preceding quarter-acquire/eighth-track candidate, the only
  servo-control change was `WRH_SYNC_PHASE` acquisition correction `/4` to
  `/8`; tracking remained `/8`, and the strict threshold remained `< 60 ps`.
- The candidate patch was applied temporarily only to the frozen Step 6
  source copy for build, then restored. The 3,219-entry source manifest and
  four-entry milestone artifact manifest matched after restore.
- No reset or power cycle was requested. The dashboard and interleaved
  observer used read-only probes; no concurrent JTAG reader was run.
- The protected Pain archive
  `/home/b10504072/04_WR_archive_step6_pass/` was not accessed.
- Raw build, program, preflight, dashboard, and smoke files are under
  [`raw/`](raw/) and listed in [`raw/SHA256SUMS`](raw/SHA256SUMS). All 27
  copied files' SHA-256 values match Pain.

## Build and programming

Both Master and Slave firmware/Quartus builds completed successfully. The
Slave image was programmed to `DE5 [1-11.2]`, followed by the Master image
to `DE5 [1-11.1]`; Quartus reported successful configuration for both.
Timing closure was not used as a functional gate.

```text
Slave SOF  SHA-256  1e158051be4ce090ae93d18ab9f15174b0f1a634412ea42ec167ad27476e33cd
Master SOF SHA-256  ca4674c0e8c7446ef6b093536357f12c1cf7015f6cffc5b9551f1f31ae60dea1
```

## Dashboard observation

The read-only 10-second dashboard produced 179 paired frames from
`2026-09-30 19:39:13` through `20:08:55` (+08:00). In all 179 frames both
boards' Step 1/link gates remained PASS, and the Slave showed Helper lock,
Main frequency lock, Main phase lock, Main lock, and PSTAT lock all high.
Master Step 6 was VALID in 179/179 frames. Slave Step 6 was WAITING in
179/179 frames because its Global-Time/PPS validity remained low.

The dashboard-reported Slave phase offset ranged from `−3838 ps` to
`+5268 ps`; `0/179` samples satisfied strict `abs(offset) < 60 ps`. Servo
states were `WAIT_OFFSET_STABLE` 162 times and `SYNC_PHASE` 17 times;
`TRACK_PHASE` was never observed. Thus the tracking `/8` branch was not
exercised, and the changed acquisition step did not produce an in-band
sample during this window.

## Interleaved-reader smoke

A 15-second configured Slave smoke used the existing wrapper, whose Tcl
invocation defaulted to `phase_context=0` (context disabled). It produced
five rows in 2.974 seconds and stopped at the five-consecutive-untrusted-row
guard. In all five rows, the low-level reads, Step 1 gate, five Step 5 lock
bits, and primary WDIAGS diagnostic-frame guard were valid. Global Time was
invalid in `5/5` rows, so `COHERENT=0/5` and no rows were accepted. The
smoke had no timeout, invalid-read, or reset-stop count.

Because this run did not request phase-context data and did not meet the
minimum 20-row smoke gate, it cannot establish context coverage or authorize
a 300-second diagnostic. No 300-second capture was run.

## Interpretation and next experiment

The hardware remained link- and Step5-lock-ready, but the Slave never
established valid Global Time and its observed offset stayed thousands of
picoseconds from zero. The `/8` acquisition change did not enter the strict
band; the tracking branch remained unreachable. This does not identify the
servo root cause, and it is not a reason by itself to make another gain or
threshold change.

The next bounded experiment should be reader-only. It should explicitly
request the existing separate-frame phase-context mode (`phase_context=2`),
and distinguish a structurally trusted diagnostic row (valid reads, stable
WDIAGS frame, and context frame joined by matching UCNT) from a Step 6
qualifying row. A diagnostic-only capture may continue when Global Time is
invalid, while `QUALIFYING_SAMPLE` must remain false unless Global Time, all
health/lock gates, and strict `abs(CKO) < 60 ps` are simultaneously true.
Add an explicit smoke gate for at least 20 rows, at least 75% trusted
UCNT-paired rows, and no read/transport/reset/lock failures. Only a passing
smoke may precede a 300-second diagnostic. This provides phase-context data
without weakening the Step 6 acceptance threshold or changing production
controls.

Step 6 remains `NOT ESTABLISHED`; the only pass criterion remains a
continuous 300-second accepted capture with every sample strictly inside
`(−60 ps, +60 ps)` and all required gates valid.
