# EXP-S6-SERVO-OFFSET-UPDATE-CORRELATION-20260929 — Report

## Verdict

```text
READER_AND_ANALYZER_TESTS                 = PASS (4/4 on Laptop and Pain)
20_ROW_SLAVE_SMOKE                         = PASS (20/20 accepted; 0 retries)
300S_CAPTURE                               = PASS (300032 ms; Quartus exit 0)
ACCEPTED_ROWS                              = 3763/3763
INVALID_ATTEMPTS_RECOVERED                 = 5
READER_ERRORS / QUARTUS_ERRORS / WARNINGS   = 0 / 0 / 0
OFFSET_TRANSITION_BRACKETS_GE_120PS        = 140
TRANSITIONS_WITH_UCNT_AND_DMS_CHANGE        = 96/140
STRICT_CKO_BOTH_BOUNDARIES_LT_60PS         = 7/3763
STEP6_EXPANDED_ACCEPTANCE                  = NOT_ESTABLISHED
```

The capture shows that many large sampled offset changes fall in the same
read bracket as both a servo update-count increment and a change in corrected
delay (`DMS`). Other large changes have no observed `UCNT`, `SETP`, or `DMS`
change in that bracket. Because these are sequential mailbox reads, neither
pattern establishes same-cycle causality. The run did not meet the expanded
Step 6 phase-offset gate and is not a Step 6 pass.

## Provenance and scope

- Branch: `feat/file_cleanup`.
- Reader commit at capture: `d6b9ca9d`.
- Final offline analyzer revision: `b00ac2fb`.
- Capture was made on the existing Slave session; there was no compile,
  programming, FPGA reset, or power cycle.
- The on-disk frozen Step 6 milestone SOFs matched the recorded hashes:
  - Master: `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`
  - Slave: `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`
- The live programmed image was not read back; SOF hashes identify the frozen
  files on disk, not an independent live-image readback.
- Only Slave JTAG cable `DE5 [1-11.2]` was selected by the reader. The source
  probe was used only to issue diagnostic mailbox read requests; no Wishbone
  target, ARM/control setting, PPS register, or snapshot request was written.
- Pre/post dashboards, smoke, capture, and analyzer summary are preserved in
  [`raw/`](raw/); all five raw artifacts verify against
  [`raw/SHA256SUMS`](raw/SHA256SUMS).
- `/home/b10504072/04_WR_archive_step6_pass/` was not accessed.

## Preflight and smoke

The one-shot preflight at `2026-09-30 00:08:12+08:00` showed both boards with
Link and Global Time valid. On the Slave, Helper, Main frequency, Main phase,
Main lock, and PSTAT were all 1. The instantaneous offset was `+447 ps`, so
Step 6 was `NOT QUALIFIED` at preflight; this did not prevent the planned
read-only diagnostic smoke.

The smoke selected the exact Slave cable and accepted all 20 rows without
retry or reader error. Median row duration was `79.171 ms` (range
`77.860–80.621 ms`), below the 100 ms plan limit. During the smoke the servo
state changed from `WAIT_OFFSET_STABLE` to `SYNC_PHASE`; the observed `UCNT`
advanced, while `SETP` remained unchanged. Quartus exited with 0 errors and
0 warnings.

## 300-second capture

The single capture ran from `2026-09-29 16:09:44 UTC` to
`2026-09-29 16:14:45 UTC` (`2026-09-30 00:09:44–00:14:45 +08:00`). The
reader-reported interval was `300032 ms`; Quartus elapsed time was `00:05:01`.
It produced 3,768 attempt rows, of which 3,763 were accepted. Five invalid
attempts were recovered by retry; no sample was ultimately rejected. Internal
row duration was `77.820–88.572 ms`, median `79.185 ms`. There were no reader
errors, five-consecutive-invalid stop, Quartus errors, or Quartus warnings.

| Measure | Result |
|---|---:|
| `WAIT_OFFSET_STABLE` at row begin / end | 3,422 / 3,415 |
| `SYNC_PHASE` at row begin / end | 334 / 340 |
| `TRACK_PHASE` at row begin / end | 7 / 8 |
| CKO transitions ≥120 ps, within-row or adjacent-row bracket | 140 |
| Transitions with `UCNT` change in bracket | 96/140 |
| Transitions with corrected `DMS` change in bracket | 101/140 |
| Transitions with both `UCNT` and `DMS` change | 96/140 |
| Transitions with `SETP` change in bracket | 10/140 |
| DMS change without UCNT change | 5/140 |
| No UCNT, SETP, or DMS change in bracket | 39/140 |
| UCNT change without DMS change | 0/140 |
| Both CKO boundaries strictly inside ±60 ps | 7/3,763 |
| Strict-offset rows with `TRACK_PHASE` at both boundaries | 7/3,763 |

Examples from the largest brackets:

| Sample | CKO change | DMS change | Derived `CKO−DMS` change | UCNT / SETP |
|---:|---:|---:|---:|---|
| 3306 | +6,168 ps across rows | +1,831 ps across rows | +4,337 ps across rows | UCNT +1 within row; SETP 0 |
| 2028 | +6,045 ps within row | +1,955 ps within row | +4,090 ps within row | UCNT +1 within row; SETP 0 |
| 560 | +5,910 ps across rows | 0 in bracket | +5,910 ps across rows | UCNT 0; SETP 0 |
| 1842 | −4,203 ps within row | −3,795 ps within row | −408 ps within row | UCNT +1 within row; SETP 0; state changed to `SYNC_PHASE` |

The source equation is `offsetFromMaster = t1 - t2 + delayMS`, with
`DMS = delayMS = meanDelay + delayAsymmetry`. The analyzer therefore also
computes `CKO−DMS` as a derived residual corresponding algebraically to
`t1−t2`. That residual is **not an independent direct measurement**; it is
derived from two sequentially read values. Its change was at least 120 ps in
137/140 large CKO-transition brackets. This arithmetic decomposition helps
show that sampled CKO movement is not explained by DMS alone, but does not
identify a physical or software root cause.

The 39 brackets without a measured `UCNT`, `SETP`, or `DMS` change, together
with the sequential/non-atomic read order, leave timing between reads and the
other offset term unresolved. Do not infer that the servo update caused the
change, or that any one component is the root cause. The setpoint changed in
only 10 of the 140 large-transition brackets, so this capture does not support
prioritizing a setpoint/gain adjustment. No control parameter was changed.

## Postflight and Step 6 decision

The final one-shot dashboard at `2026-09-30 00:15:28+08:00` again showed both
links and Global Time valid, and all five Slave Step 5 lock signals at 1. The
instantaneous Slave offset was `−3801 ps`; Step 6 remained `NOT QUALIFIED`.
The observer itself did not sample locks or Global Time during the five-minute
window, so the endpoint dashboards do not prove those signals remained high
throughout the capture.

```text
STEP5_REQUIRED_LOCKS_AT_PRE_AND_POST_DASHBOARD = PASS
GLOBAL_TIME_AT_PRE_AND_POST_DASHBOARD           = PASS
SERVO_OFFSET_LT_60PS_AT_POSTFLIGHT              = NO (-3801 ps)
STEP6_EXPANDED_GATE                             = NOT_ESTABLISHED
HISTORICAL_DIGITAL_STEP6_SCOPE                  = UNCHANGED / PASS
PHYSICAL_SMA_OUTPUT_EDGE_SKEW                   = NOT EVALUATED
```

## Next diagnostic

If continuing without changing production control, use a read-only interleaved
capture that places each `DMS` read immediately adjacent to its corresponding
`CKO` read, keeps `UCNT` around the pair, and retains `SSTAT` framing. The
current event counts show why tighter alignment is needed: a 79 ms row can
bracket multiple sequential state changes, and the 64-bit DMS high/low words
are themselves read separately. Do not tune PI/gain/threshold from this run;
first obtain tighter time-aligned component evidence. Step 6 still requires a
separate qualifying Global-Time/offset observation.
