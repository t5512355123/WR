# EXP-S6-WDIAGS-HIGH-RATE-SERVO-20260930 — Report

## Verdict

```text
HIGH_RATE_SMOKE                  = PASS (76/76 framed rows; median 197 ms)
HIGH_RATE_300S_CAPTURE           = COMPLETE (300165 ms; 1501 rows)
WDIAGS_FRAME / GLOBAL_TIME / LOCKS = 1501/1501 valid
ABS_CKO_LT_60_PS                 = 3/1501 (0.20%)
STEP6_EXPANDED_ACCEPTANCE        = NOT ESTABLISHED
```

The reader interval change passed its smoke, and the 300-second run achieved
about 5 Hz without transport errors or reset changes. Greater sampling
density did not produce sustained phase-offset lock: only three rows met the
strict threshold.

## Provenance and safety

- Branch: `feat/file_cleanup`; source revision: `d40f4fe3`.
- Raw evidence is in [`raw/observe/`](raw/observe/) and listed in
  [`raw/SHA256SUMS`](raw/SHA256SUMS).
- No firmware/RTL, servo control, PI/gain, threshold, timeout, clock, or PPS
  changes; no build/program, reset, or power cycle.
- The Pain archive `/home/b10504072/04_WR_archive_step6_pass/` was not
  accessed.
- This is a Slave-only read; it does not establish Master/Slave Global-Time
  agreement or dual-board trigger timing.

## High-rate smoke

Raw log: [`smoke_20260929T184320Z.log`](raw/observe/smoke_20260929T184320Z.log)

- 76 rows over 15.160 s; all individual reads, Global Time, five Step 5 lock
  bits, and WDIAGS frame checks were valid.
- No timeout/invalid count, reset change, or early stop. Median row duration
  was 195.481 ms and median row spacing was 197 ms.
- CKO ranged from −3840 to +721 ps; none of the 76 rows met `abs(CKO) < 60 ps`.
- Analyzer: `SMOKE_PASS` for the observer gate only.

## 300-second capture

Raw log: [`capture_20260929T184407Z.log`](raw/observe/capture_20260929T184407Z.log)

- Completed 300165 ms with 1501 rows. Quartus/Tcl exit 0, no early stop,
  reset change, transport timeout, or invalid count.
- Individual reads, Global Time, all five Step 5 lock bits, and valid WDIAGS
  framing: 1501/1501 rows.
- Median row duration: 195.482 ms; median row spacing: 197 ms; maximum gap,
  including the tail, was 213 ms.
- CKO range: −3980 to +2439 ps. `abs(CKO) < 60 ps`: 3/1501 rows (0.20%).
- Analyzer: `STEP6_EXPANDED_GATE_NOT_ESTABLISHED`.

## Servo-state correlation

The analyzer groups coherent CKO samples by the source-defined WRH servo
state (`task-diags.c` / `wrh.h`):

| State | Meaning | Rows | CKO range (ps) | `<60 ps` |
|---:|---|---:|---:|---:|
| 3 | `SYNC_PHASE` | 142 | −3911 to +2306 | 0 |
| 4 | `TRACK_PHASE` | 3 | −50 to −50 | 3 |
| 5 | `WAIT_OFFSET_STABLE` | 1356 | −3980 to +2439 | 0 |

Thus the observed WRH servo was in `WAIT_OFFSET_STABLE` for 90.3% of rows and
`SYNC_PHASE` for 9.5%; it reached `TRACK_PHASE` in only 3/1501 rows. All three
strictly in-band offsets coincided with state 4. This is consistent with the
source transition guard (`abs(offset) < 60 ps` to enter `TRACK_PHASE`), but
does not prove why the offset fails to remain in band.

Across 1500 adjacent valid update-counter pairs, UCNT changed 288 times and
was unchanged 1212 times; the maximum observed delta was one. UCNT movement
alone does not prove that a phase adjustment completed.

## Next experiment

Keep production controls frozen. The next read-only experiment adds the
published DMS and phase setpoint (SETP) to the same per-row validated WDIAGS
frame as CKO/SSTAT/UCNT. It is intended to show whether the phase setpoint
changes as the servo moves between `SYNC_PHASE`, `WAIT_OFFSET_STABLE`, and
`TRACK_PHASE`. First run a 15-second frame/transport smoke; only if it passes
should a 300-second capture run. See the next experiment's `PLAN.md`.
