# EXP-S6-WRH-SERVO-TRACK-INBAND-HOLD-DEADBAND-20261001 — Report

## Verdict

```text
SOURCE_TESTS                         = PASS (4/4)
PAIN_SOURCE_COMMIT                   = f357a56264afaddb6099d931f76d1466286ca264
MASTER_BUILD_PROGRAM                 = PASS
SLAVE_BUILD_PROGRAM                  = PASS
READINESS_GATE                       = REACHED
SMOKE_1_STRICT_ACCEPTANCE             = FAIL
SMOKE_2_STRICT_ACCEPTANCE             = FAIL
300S_CAPTURE                         = NOT_RUN (smoke gate failed)
STEP6_STRICT_OFFSET_300S_STABILITY    = NOT_ESTABLISHED
```

The candidate reached `TRACK_PHASE`, valid Global Time, and all five Slave
Step 5 lock signals. However, both short captures contained coherent,
UCNT-matched CKO samples outside the strict `abs(CKO) < 60 ps` band. The
candidate is therefore rejected as a 300-second stability candidate. The
analyzer's pointwise verdict means that at least one fully qualified sample
was observed; it is not a sustained-stability verdict.

## Candidate and source identity

Pain was fast-forwarded to the exact pushed source on `feat/file_cleanup`:

```text
f357a56264afaddb6099d931f76d1466286ca264
```

The single behavior change relative to the measured quarter-step baseline was
to hold SETP and skip `adjust_phase()` while `abs(offset_ps) < 60 ps`; the
existing `/4` correction remains at or outside 60 ps. The 60 ps entry
threshold, 120 ps fallback, retry behavior, Step 5 controls, PTP/DMS, reset,
RTL, SDB, and timing constraints were unchanged. The experiment is diagnostic
and makes no claim that the changed behavior caused or fixed the observed CKO
excursions.

## Build and programming

Both full firmware and Quartus builds completed on Pain using Quartus Prime
17.0.0 Build 595. The fitters succeeded and both programmer operations
configured one device with zero errors and zero warnings.

| Board | Cable | SOF SHA-256 | Programmer result | Timing metadata |
|---|---|---|---|---|
| Slave | `DE5 [1-11.2]` | `8c3d3dd861db73c5eee2644ed03e4a76fe62412e56bbc3753ce5a210ad57c435` | Success; device `10AX115N2F45@1`; checksum `0x30B1E229` | `TIMING_CLOSED=NO`, worst setup slack `−0.659 ns` |
| Master | `DE5 [1-11.1]` | `57a621499386afcb94b3cfad0283484ae5eaa9fead0380a7c448e48483658741` | Success; device `10AX115N2F45@1`; checksum `0x30B18F28` | `TIMING_CLOSED=NO`, worst setup slack `+0.262 ns` |

The build identity files and complete firmware/Quartus logs are in
[`raw/build/pain-artifacts/`](raw/build/pain-artifacts/); the original Pain
build-log bundle is also retained as
[`raw/build/build-evidence.tar.gz`](raw/build/build-evidence.tar.gz).
Timing closure is recorded but is not a functional acceptance gate for this
experiment.

## Readiness observation

The read-only dashboard ran from `2026-10-01T10:18:34+08:00` through
`10:28:13+08:00`, within the 30-minute limit. Master remained Step 1/Global
Time valid. Slave link remained up; its five Step 5 locks became `1`, and it
entered `TRACK_PHASE`. At `10:27:34`, the dashboard reported Slave CKO `+51
ps`, Global Time valid, and all five locks high; at `10:27:54`, CKO was `−5
ps`. This transient readiness allowed the planned smoke captures.

Later dashboard rows left the strict offset band. The monitor was intentionally
stopped after readiness and smoke gating; its final `quartus_stp_rc=130` is the
host-side Ctrl+C stop, not a board reset or an in-capture transport failure.
No power cycle, reset, or additional programming occurred between the two
smokes.

## Read-only smoke results

Both captures used
`read_step6_servo_interleaved_offset.tcl 15000 250 1-11.2 2` (15 seconds,
250 ms requested cadence, Slave only, `phase_context=2`). The observer's
read-only contract was true, each capture completed normally, all sampled
Step 1 fields, Global-Time validity, all five lock bits, diagnostic frames,
and stable snapshots were valid, and reset-change count was zero.

| Metric | Smoke 1 | Smoke 2 |
|---|---:|---:|
| Duration | 15.381 s | 15.128 s |
| Read-valid rows | 24 | 23 |
| Coherent accepted / UCNT-context-matched rows | 18 / 18 (75.0%) | 21 / 21 (91.3%) |
| Accepted rows with strict `abs(CKO) < 60 ps` | 13 / 18 | 8 / 21 |
| Coherent accepted rows outside strict band | 5 | 13 |
| All Step 1 / all five locks / Global-Time-valid rows | 24 / 24 / 24 | 23 / 23 / 23 |
| Valid-read CKO range | `−141..+151 ps` | `−93..+218 ps` |
| Independently fully qualified rows | 13 | 8 |
| Reset changes / timeout / invalid count | `0 / 0 / 0` | `0 / 0 / 0` |

Smoke 1 also missed the minimum 20 coherent accepted rows. Smoke 2 met the row
count and context-coverage minimums, but 13 accepted CKO rows were outside the
strict band. Therefore neither smoke meets the plan's requirement that every
accepted CKO be strictly in band. Per the plan, no 300-second capture was run.

These observations show that the in-band hold did not prevent out-of-band CKO
readings under this candidate. They do not by themselves distinguish
measurement-path variation from controller interaction; separately sampled
fields are not atomic, and no causal claim is made.

## Raw evidence and integrity

Pain-to-Laptop byte identity was verified for the transferred files. SHA-256:

```text
raw/observe/readiness-dashboard.log
  09db3697c7890864cb0e27bc3faa856fe466fb32f1a9e2e2687afb4cbe49307f
raw/observe/smoke-1.log
  d68e2e0ada2546beafcdbe0d29d37ee6493ee8ed3d17e28c51bc0866ed231aad
raw/observe/smoke-2.log
  a97b258ac386ad539c96acd99f416fede50bee1ab8fd95cb5d045006a0e49207
raw/build/build-evidence.tar.gz
  a161cbbb238da625b85fded84e0c90308c8b1e19194f26162fb4b7032c0b630a
```

The smoke logs were re-analyzed on Laptop using
`scripts/analysis/step6_dashboard_gate_capture.py`; summary counts matched the
Pain results. No protected archive path was accessed.

## Next diagnostic direction

Do not tune another gain or threshold based on these short samples. The next
single-variable diagnostic should use the proven `/4` acquisition path and
freeze phase SETP with a boot-lifetime one-shot latch at the first successful
`WAIT_OFFSET_STABLE → TRACK_PHASE` transition. The latch must block TRACK
adjustments/fallbacks and every later phase-setpoint write path, including
`SYNC_PHASE` and servo initialization; capture should stop if the servo leaves
`TRACK_PHASE`. This distinguishes continued CKO motion under fixed SETP from
motion that only appears while the controller is actively updating SETP. The
earlier attempt did not reacquire TRACK and was inconclusive; this run now
demonstrates that the `/4` acquisition baseline can reach TRACK, so any retry
must preserve the current build/program/read-only discipline and explicitly
prove the latch was exercised.
