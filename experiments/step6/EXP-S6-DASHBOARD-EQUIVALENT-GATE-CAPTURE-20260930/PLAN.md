# EXP-S6-DASHBOARD-EQUIVALENT-GATE-CAPTURE-20260930

## Objective

Verify the Slave's strict Step 6 condition using the same full Step 1 gate as
the dashboard, together with a coherent/stable valid Global-Time snapshot,
all five Step 5 lock bits, and `abs(CKO) < 60 ps` in each qualifying sample.
The prior paired capture omitted explicit Step 1 status bits from its
qualifying-row predicate, so its four in-range rows are promising but are not
used alone to claim a dashboard-equivalent pass.

## Change and controls

- Modify only `scripts/jtag/read_step6_servo_interleaved_offset.tcl` read-only
  observability: decode the dashboard's Step 1 status bits from the already
  read status probe, print them, and require the complete Step 1 gate before
  incrementing `QUALIFYING_SAMPLE`.
- Add an offline regression test that verifies the bit mapping and gate.
- Do not modify production C/RTL, servo/SoftPLL controls, thresholds, timing,
  PPS, mailbox, reset, or the frozen milestone images.
- The observer performs no Wishbone writes, programming, reset, or power-cycle.

## Procedure and stop conditions

1. Run the Step 6 analyzer/Tcl-format offline tests; push the change to
   `feat/file_cleanup`; fast-forward Pain to the exact commit.
2. Confirm no competing JTAG reader. Run a 15-second Slave-only smoke with
   `phase_context=2`; require valid frames, matching UCNT joins, valid Global
   Time, all five Step 5 locks, valid Step 1 status, and zero reset changes.
3. If smoke passes, run one 300-second read-only capture in a single JTAG
   session. Preserve every raw row. Stop on timeout, invalid-frame streak,
   board reset/generation change, or early termination.
4. A pointwise dashboard-equivalent Step 6 observation requires all Step 1
   status bits, stable/valid Global Time, and all five Step 5 locks high while
   `abs(CKO) < 60 ps`. Report whether this happened and how many consecutive
   rows it lasted; do not claim 300-second offset stability unless the full
   capture supports it.
5. After the capture, copy raw data to the laptop, verify SHA-256, analyze,
   update the report and milestone docs, push, sync Pain, then stop. No
   production tuning or image change is part of this experiment.
