# Current-image TIME_VALID-only 300s — one observation, then stop

User instruction, 2026-10-03: change this round's objective to TIME_VALID
300 seconds; current hardware may already satisfy it; stop experiments
after this check. This supersedes the strict-offset acceptance requirement
for this round, not the definition of a strict-offset milestone.

## Scope

- Observe the current running Master and Slave; no build, compile, FPGA
  programming, role change, calibration write, reset or power cycle.
- Do not disable existing firmware validity protection or force a valid bit.
- No advisor, no gain/Ki/threshold changes, no next candidate or retry trial.
- Frozen milestones and `/home/b10504072/04_WR_archive_step6_pass/` untouched.
- Use existing source-identical Laptop/Pain observer and analyzer at checkout
  `7dccbebda69545183832203dde0422a4552bafb2`.
- Current output metadata identifies compile source
  `359984a54d41a488006050c6c406fd43f2fd3fbe`; this metadata is not a new
  FPGA-programming event or an independent readback of loaded SOF bytes.

## Acceptance

Both DE5 [1-11.1] and DE5 [1-11.2] must each have a complete sampled window:

- `STATUS_TIME_VALID=1` in every row, no discarded invalid samples.
- Observed sample span >=300000ms; requested window303000ms.
- Sequential sample indices, matching DONE count, both expected boards.
- At least301 rows, positive gaps <=1000ms, no capture error.

CKO <60 entry, <=120 retention, PPS/snapshot validity, PLL lock flags,
link diagnostics and TAI/cycle diagnostics are not additional acceptance
gates for this explicitly TIME_VALID-only check. The underlying firmware
continues its current behavior; a validity drop remains a failed sample.

This is sampled bit retention, not proof of continuous per-clock validity,
offset accuracy, simultaneous two-board observation or physical SMA skew.
The existing collector observes boards sequentially,303s per board; total
wall time is about606s plus setup. Do not call this one simultaneous300s run.

## Execution and terminal behavior

Confirm no other JTAG owner; execute exactly one existing
`read_step6_global_time_observability.tcl 303000 250 ""` session, with a
900s process deadline. Run the unchanged `step6_time_valid_300s.py` with
300000ms duration,1000ms gap limit,301 minimum samples and both board IDs.
Capture began2026-10-03T21:00:16+08:00 on Pain.

Preserve full raw, result and SHA256 files; return them to Laptop and
recompute the verdict independently. Report PASS or NOT_ESTABLISHED, then
stop. Do not restart after a failure, extend into another experiment,
promote a strict-offset milestone, merge main, or reprogram automatically.
