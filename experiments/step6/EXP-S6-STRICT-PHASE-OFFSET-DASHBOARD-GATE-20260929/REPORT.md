# EXP-S6-STRICT-PHASE-OFFSET-DASHBOARD-GATE-20260929

## Verdict

`DASHBOARD_GATE_IMPLEMENTED_AND_OFFLINE_TESTED; HARDWARE_REPRODUCTION_NOT_RUN`

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
  original Global-Time and digital-trigger scope, but it predates the strict
  phase-offset gate. The separate 2026-09-29 half-gain experiment observed
  -539 ps and did not establish the expanded Step 6 acceptance.

## Next action

Run the updated read-only dashboard against the exact frozen Step 6 image.
Record a valid/stable Slave snapshot with `abs(WR_SERVO_OFFSET_PS) < 60` and
retain the existing Global-Time and dual-board-trigger evidence as separate
gates. Do not infer hardware PASS from these offline tests.
