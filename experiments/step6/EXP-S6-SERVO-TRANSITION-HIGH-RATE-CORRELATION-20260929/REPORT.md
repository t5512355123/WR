# EXP-S6-SERVO-TRANSITION-HIGH-RATE-CORRELATION-20260929 — report

## Verdict

```text
JTAG_PREFLIGHT                              = PASS
READ_ONLY_DASHBOARD_PREFLIGHT              = PASS
READER_SMOKE                               = PASS (5/5 samples per board)
HIGH_RATE_CAPTURE                          = PASS (60/60 accepted samples per board)
SLAVE_STEP5_LOCKS_DURING_CAPTURE            = 60/60 samples
SLAVE_GLOBAL_TIME_AND_SERVO_STATE_VALID     = 60/60 samples
SLAVE_SERVO_STATES                          = WAIT_OFFSET_STABLE 55; SYNC_PHASE 5; TRACK_PHASE 0
SLAVE_OFFSET_WITHIN_STRICT_60PS             = 0/60 samples
SERVO_TRANSITION_CAUSE                      = NOT_ESTABLISHED
STEP6_EXPANDED_ACCEPTANCE                   = NOT_ESTABLISHED
```

The high-rate capture improved the dashboard's 10-second cadence to a median
579 ms between accepted Slave rows (minimum 10.229 ms, maximum 1179.603 ms).
It observed repeated `WAIT_OFFSET_STABLE` ↔ `SYNC_PHASE` changes while all
five Step 5 lock indicators and valid Global Time remained asserted. The
source-audited signed CKO/phase-offset values ranged from -3943 ps to +2109 ps
(median +853.5 ps); none of the 60 rows was strictly inside (-60,+60) ps.
No `TRACK_PHASE` sample occurred in this capture.

This is useful evidence that the servo revisits its acquisition states while
the downstream SoftPLL lock bits stay asserted. It does **not** prove why a
transition occurred: the fastest complete rows still span hundreds of
milliseconds, and each row consists of sequential mailbox reads rather than
an atomic single-cycle snapshot. The overall `FRAME_VALID` field was 0 in all
rows because live counters/diagnostic fields changed during the multi-register
window; the reader independently marked each Slave Step 5 sample valid, its
servo-state block valid, and the lock flags asserted. Therefore use the local
state/offset values for bounded temporal correlation, not single-cycle causal
claims.

## Exact checkout and preflight

- Pain branch/commit/tree: `feat/file_cleanup` /
  `2c17883fc8fcb9fd0295903fa8b92120a23a83b7` /
  `504937d84f2d7e94472ea028d71916a10981f327`.
- Checkout was clean before raw evidence was generated.
- No competing Quartus programmer, SignalTap reader, or dashboard process was
  active at preflight.
- Both intended cables were listed: `DE5 [1-11.1]` and `DE5 [1-11.2]`.
- Frozen Step 6 source manifest verified; reader SHA-256 was
  `16c0ec707ee2d020754423261f3f8f460c88e7cb369d762ea291a97c5e576de6`.
- Dashboard smoke at `2026-09-29 21:39:39+08:00`: both boards had Link/TM and
  valid Global Time; Slave Helper, Main frequency, Main phase, Main lock, and
  PSTAT were all 1. Its point offset was +2273 ps in `WAIT_OFFSET_STABLE`.
- No compile, FPGA programming, reset, power-cycle, control-setting write, or
  change to the frozen milestone source was performed in this experiment. The
  capture is a continuation of the previously recorded frozen-image session;
  this run does not independently read back a bitstream hash from the FPGA.

## Smoke and high-rate capture

The reader smoke completed 5 samples on each board in about 7 seconds, with
`STEP5_SAMPLE_VALID=1` on all 5 Slave samples. Quartus/Tcl reported success
with 0 errors and 0 warnings.

The full reader capture ran from `2026-09-29T13:40:25.565Z` to
`2026-09-29T13:41:37.071Z` (72 seconds). It emitted 60 accepted rows for each
board and exited 0 with no reader error/timeout lines and no Quartus errors or
warnings. The reader enumerates the Master first and Slave second; board
series are sequential, not simultaneous.

| Measure | Master | Slave |
|---|---:|---:|
| Accepted rows | 60/60 | 60/60 |
| `STEP5_SAMPLE_VALID` | 60/60 | 60/60 |
| `FRAME_VALID` | 0/60 | 0/60 |
| Valid servo-state block | Not applicable to Master role | 60/60 |
| All five Step 5 locks | Not applicable to Master role | 60/60 |
| `TIME_VALID` and `PPS_VALID` | 60/60 | 60/60 |
| Median accepted-row interval | 583.073 ms | 579.151 ms |

Slave sample-start timestamps span 34.772209 seconds. Servo state was
`WAIT_OFFSET_STABLE` in 55/60 rows and `SYNC_PHASE` in 5/60; there were no
sampled `TRACK_PHASE` rows. The sampled state changes occurred at samples
1, 2, 3, 21, 23, 43, and 45. CKO offset extrema and median are from the 60
accepted, servo-state-valid Slave rows; they are not a continuous time trace.

`DMS` had 31 distinct values, `SETP` had 4, and `UCNT` increased from 3729 to
3761. These show changes in the captured diagnostic/measurement values, but
do not by themselves identify the cause of the servo state changes.

## Interpretation and next action

The 2026-09-29 dashboard capture previously found one -17 ps point followed
10 seconds later by +1165 ps. This faster capture did not observe the brief
`TRACK_PHASE` state or any strict `<60 ps` point. It did observe the servo
cycling between `SYNC_PHASE` and `WAIT_OFFSET_STABLE` while the Step 5 lock
signals remained high. Because a state transition could occur between the
roughly 0.58-second median samples, the next useful instrument is a minimal
read-only reader for only the source-audited SSTAT/CKO and lock/validity words,
with per-row framing retained. Do not change firmware, servo thresholds,
gains, or the Step 6 frozen image until finer trace evidence supports a cause.

The strict-offset acceptance remains **NOT ESTABLISHED**: this run had no
in-range Slave offset sample and lasted about 35 seconds on the Slave, not the
full 300-second qualification window. Historical same-PPS and dual-board
digital-trigger evidence remains separate and unchanged.

## Integrity and evidence

- The same four raw logs were hashed on Pain and Laptop. Their digests are in
  `raw/SHA256SUMS`; all matched exactly.
- The observer used the frozen reader through its existing in-system source
  probe mailbox. `write_source_data` carried diagnostic read requests only;
  no WR settings, target/ARM controls, or `DATA_SNAPSHOT` register was written.
- Dashboard parsing/analyzer tests: 2/2 passed locally.
- The archived `/home/b10504072/04_WR_archive_step6_pass/` was not accessed.
