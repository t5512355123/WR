# EXP-S6-SERVO-SLAVE-MICROTRACE-20260929 — report

## Verdict

```text
READER_AND_OFFLINE_TESTS                  = PASS (3/3)
20_ROW_SLAVE_SMOKE                         = PASS (20/20 accepted; 0 errors)
300S_MICROTRACE_PROCESS                    = PASS (Quartus exit 0; 0 errors/warnings)
ACCEPTED_SLAVE_ROWS                        = 8779/8779
FAILED_ATTEMPTS                            = 9 (all recovered by retry)
SERVO_STATE_VALID_ROWS                     = 8779/8779
TRACK_PHASE_AND_ABS_CKO_LT_60PS            = OBSERVED (70 consecutive rows; ~2.39s summed row time)
OTHER_ABS_CKO_LT_60PS_WINDOW               = OBSERVED (23 rows; WAIT_OFFSET_STABLE; ~0.78s summed row time)
STRICT_OFFSET_300S_ACCEPTANCE              = NOT ESTABLISHED
STEP6_EXPANDED_PASS                        = NO
```

The high-rate observer confirms that the slower 400-row capture missed brief
phase-tracking windows. It does **not** show 300 seconds of continuous phase
lock, nor prove why the measured offset abruptly changes. This was a
read-only diagnostic run, not a Step 6 pass.

## Provenance and safety

- Branch: `feat/file_cleanup`.
- Reader commit on Pain: `93508ea54c0e35f8cbcb8a6736a223cb14645de2`.
- Exact Step 6 SOF files present on Pain matched the milestone hashes:
  - Master: `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`
  - Slave: `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`
- No compile, programming, reset, or power cycle occurred. The live target
  image was not read back; these are the frozen artifact hashes on disk.
- Only Slave cable `DE5 [1-11.2]` was opened by the microtrace. The run used
  six diagnostic-mailbox reads per row and did not write a Wishbone target,
  ARM/control setting, PPS register, or snapshot request.
- Pre/post dashboard and capture raw files were transferred from Pain and
  byte-verified; see [`raw/SHA256SUMS`](raw/SHA256SUMS).
- `/home/b10504072/04_WR_archive_step6_pass/` was not accessed.
- No adviser was contacted.

## Preflight and smoke

The preflight at `2026-09-29 23:23:45+08:00` found both intended JTAG cables,
no competing Quartus reader/programmer/dashboard process, and a clean Pain
checkout at the experiment commit. Both boards reported Link and valid Global
Time. The Slave's Helper, Main frequency, Main phase, Main lock, and PSTAT
signals were all 1; its instantaneous offset was `+2361 ps`, so the expanded
Step 6 gate was not qualified.

The short smoke completed 20/20 accepted rows, no retries, no reader error,
and no Quartus warning/error. Internal row durations were about `33.4–34.9 ms`.
The observed offset moved from `+1117 ps` during the smoke; the Slave servo
state changed from `SYNC_PHASE` to `WAIT_OFFSET_STABLE`.

## 300-second capture

The capture ran on the already-programmed session for a five-minute reader
window (Quartus elapsed `00:05:01`) and exited successfully. It yielded 8,788
attempt rows and 8,779 accepted samples. Nine invalid attempts were retried
successfully; there were no reader errors, repeated failures, or `MICRO_STOP`
events. Internal row duration was `32.2–39.9 ms`, median `33.924 ms`.

| Measure | Result |
|---|---:|
| `WAIT_OFFSET_STABLE` at row start / end | 7,808 / 7,807 |
| `SYNC_PHASE` at row start / end | 865 / 867 |
| `TRACK_PHASE` at row start / end | 106 / 105 |
| SSTAT changes within a row / across adjacent rows | 26 / 29 |
| CKO begin/end range; median | `-4043..+2454 ps`; `+598 ps` |
| Within-row CKO delta min/max | `-4361 / +3801 ps` |
| Both CKO boundaries strictly inside `(-60,+60) ps` | 93/8,779 |
| Longest consecutive strict-offset run | 70 rows; samples 2,384–2,453 |
| Summed reader time in longest run | `2.389836 s` |
| Longest run offset at both boundaries | `-32..-31 ps` |
| Strict-offset rows with `TRACK_PHASE` at both boundaries | 70 |

There were exactly two contiguous strict-offset episodes:

| Sample range | Rows | Sum of row durations | State | Offset at both boundaries |
|---|---:|---:|---|---:|
| 2,384–2,453 | 70 | 2.389836 s | `TRACK_PHASE` throughout | `-32..-31 ps` |
| 8,111–8,133 | 23 | 0.783491 s | `WAIT_OFFSET_STABLE` throughout | `+9 ps` |

The second window demonstrates that an in-range offset can be present in the
diagnostic register while the sampled servo remains in `WAIT_OFFSET_STABLE`;
the reads are not atomic and do not reveal when the next servo update ran.

### Transition sequence

In the longest run, sample 2,383 was `WAIT_OFFSET_STABLE` at `-3889 ps`;
sample 2,384 was `TRACK_PHASE` at `-32 ps`. The offset remained between
`-32` and `-31 ps` through sample 2,453. It then read `+92 ps` from sample
2,454 through 2,488 while remaining in `TRACK_PHASE`. At sample 2,489 the
offset read `-3650 ps` and SSTAT changed `TRACK_PHASE → SYNC_PHASE`.

The frozen source sets the `WAIT_OFFSET_STABLE → TRACK_PHASE` entry threshold
to `abs(offset) < 60 ps`; in `TRACK_PHASE`, it returns to `SYNC_PHASE` when
`abs(offset_ps) > 120 ps` (`wrh-servo.c:299–329`; threshold in `wrh.h:56`).
The observed state changes agree with those source conditions. The sampled
`+92 ps` value is outside the strict Step 6 limit but below the `120 ps` exit
threshold, so remaining in `TRACK_PHASE` there is expected. The later
`-3650 ps` sample is consistent with leaving tracking. This identifies the
state-machine boundaries, **not the origin of the multi-nanosecond offset
jumps**.

The host output-arrival interval had a `4.177 ms` median and `1102.194 ms`
maximum because Quartus/Tcl output is buffered. It is not the sample cadence.
The report uses the reader's measured per-row duration instead. The sequential
mailbox reads are not a same-cycle snapshot, and the summed durations within a
run are not a continuous 300-second lock assertion.

The preflight dashboard after capture at `2026-09-29 23:30:50+08:00` again
showed both links and Global Time valid, with all five Slave Step 5 lock bits
at 1. The instantaneous offset was `+685 ps` and the servo was in
`WAIT_OFFSET_STABLE`; the dashboard explicitly reported Step 6 `NOT QUALIFIED`.
The compact reader did not sample lock bits or Global Time during its
five-minute window, so the endpoint dashboards cannot prove those signals
stayed asserted throughout the capture.

## Next experiment

Correlate the same Slave `SSTAT`/`CKO` transitions with source-backed
`WDIAG_UCNT`, `WDIAG_SETP`, and `WDIAG_DMS` in one compact, read-only trace.
`UCNT` is the WR servo update counter; `SETP` is `cur_setpoint_ps`; `DMS` is
the corrected `delayMS` term (`meanDelay + delayAsymmetry`) used to calculate
`offsetFromMaster`. Bracket `UCNT`, `SETP`, SSTAT, and CKO so a jump can be
classified as coincident with a servo update/setpoint/delay change or occurring
without one. Keep all controller and timing parameters fixed. This is the next
correlation-observation step; it still cannot be called Step 6 PASS without a
separate full acceptance window.
