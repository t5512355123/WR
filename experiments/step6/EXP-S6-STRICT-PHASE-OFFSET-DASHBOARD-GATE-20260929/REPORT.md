# EXP-S6-STRICT-PHASE-OFFSET-DASHBOARD-GATE-20260929

## Verdict

`DASHBOARD_GATE_IMPLEMENTED_AND_OFFLINE_TESTED; LIVE_HARDWARE_GATE_NOT_MET`

The Step 1–6 dashboard now requires the Slave's signed WR phase offset to be a
valid integer with strict magnitude below 60 ps before that board can report
Step 6 `PASS`. The Master has no Slave-servo offset and is not subjected to
that check. Existing link, Step 1, Global-Time, PPS, snapshot-valid, and
snapshot-stable requirements remain unchanged.

## Motivation

The previous dashboard displayed a `<60 ps` target but did not include it in
the Step 6 gate. It could therefore report Step 6 `PASS` while the Slave
offset was outside the required range. The updated Tcl reader emits
`WR_PHASE_OFFSET_OK`; the shell monitor also fails closed if the field is
missing, disagrees with the numeric offset, or has an unknown board role.

## Verification

- The dashboard regression suite passed **12/12** tests. Coverage includes
  offsets `+59` and `-59` as eligible, and `+60`, `-60`, `+539`, `-539`, and
  invalid/missing values as not eligible.
- A monitor-side disagreement case confirms that a claimed `PASS` with a
  reported offset of 59 ps but a false qualification bit is rejected.
- Bash syntax validation passed. No Quartus build, FPGA programming, reset,
  or hardware observation was performed in this gate-correction change.
- The 2026-09-27 frozen-image experiment remains a historical pass for the
  original Global-Time and digital-trigger scope, but its retrospective raw
  dashboard values were `-158 ps` after the 300-second series and `+135 ps`
  after re-arm. Both have valid Global Time and both fail the strict `<60 ps`
  offset requirement. The separate 2026-09-29 half-gain experiment observed
  `-539 ps` and likewise did not establish expanded Step 6 acceptance.
- A read-only six-sample dashboard observation was performed on Pain at
  2026-09-29 19:03:14–19:04:24 (+08:00), using the currently programmed
  half-gain candidate image documented in
  `EXP-S6-WRH-SERVO-PHASE-HALF-GAIN-20260929`, not the original frozen SOFs.
  Master reported Step 6 `VALID` in all six samples. Slave remained
  `WAITING`; `TIME_VALID=0`, `PPS_VALID=0`, snapshot count `0`, and the
  displayed servo offset ranged from +944 ps to +2555 ps. The sample summary
  is in `raw/observe/live-offset-samples.tsv`; it is transcribed from the
  filtered terminal output, not a complete raw dashboard log. Snapshot counts
  not preserved by that output are marked `NA`. Thus the stricter live
  hardware gate is not met. This short series is evidence of a non-settled
  runtime state, not a 300-second stability result or proof of a unique root
  cause.
- No FPGA build, programming, reset, or power-cycle was performed for this
  read-only observation.

## Next action

No consultant input is part of the next action. The user directed the
experiment to proceed directly. Reprogram the exact frozen Step 6 milestone
SOFs, verify their SHA-256 values before programming, take a short read-only
dashboard smoke, and only if the two boards remain healthy capture a
300-second read-only dashboard series. The series must preserve per-sample
Global-Time snapshot validity/stability, all four Slave Step 5 locks, the
signed servo offset, and board/reset identity. The expanded Step 6 gate is
eligible only when the Slave has a valid/stable snapshot and
`abs(WR_SERVO_OFFSET_PS) < 60`; a 300-second claim additionally requires the
four Step 5 lock indicators to remain asserted for the complete fresh-data
window. Do not modify the frozen source or control parameters during this
re-observation. See the dedicated plan at
`../EXP-S6-FROZEN-IMAGE-STRICT-PHASE-300S-20260929/PLAN.md`.
