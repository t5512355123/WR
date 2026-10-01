# EXP-S6-TIME-VALID-300S-QUARTER-ACQUIRE-20261001

> Superseded before any FPGA programming by
> [EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001](../EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001/PLAN.md).
> A partial Master build attempt on Pain was interrupted before Quartus
> compilation completed; no SOF was programmed. Its four raw logs have been
> hash-verified against Pain and are archived with a checksum manifest; see
> REPORT.md. The historical /2-acquire +
> /12-track capture is a closer, already exercised candidate.

## Objective

Test the revised Step 6 functional target: both DE5a boards independently
maintain exported `STATUS_TIME_VALID=1` throughout at least 300 sampled seconds.
No phase-offset bound or timing-closure requirement applies.

## Baseline and sole candidate change

- Frozen Step 6 source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Frozen source package: `artifacts/milestones/step6_global_time/source/`.
- Canonical baseline SOFs remain unchanged and are verified against
  `artifacts/milestones/step6_global_time/SHA256SUMS` before the candidate is
  built.
- Candidate is the previously exercised quarter-step acquisition change from
  `EXP-S6-WRH-SERVO-PHASE-QUARTER-STEP-20260930`: in `WRH_SYNC_PHASE`, update
  `cur_setpoint_ps` by `offset_ps / 4` instead of the full `offset_ps`.
- Reuse the exact patch already validated and archived at
  `../EXP-S6-WRH-SERVO-PHASE-QUARTER-STEP-20260930/candidate.patch`; do not
  re-create or broaden it.
- No other firmware, RTL, PPS, threshold, timeout, PI/gain, PHY, SDB, or timing
  constraint changes are allowed. Do not force or software-write TIME_VALID.
- The frozen package and canonical milestone SOFs on Laptop/GitHub remain
  byte-identical. On Pain only, temporarily apply the patch to the exact frozen
  source file for the build, then reverse-apply it and verify the original
  manifest before completing the run; never commit or push the patched source.

## Required workflow

1. On Laptop, run the focused 300-second analyzer tests and the existing
   quarter-step patch tests. Check the patch against the frozen source and run
   `git diff --check`; commit/push the plan, patch, tests, and revised analyzer
   to `origin/feat/file_cleanup`.
2. On Pain, fast-forward `/home/b10504072/04_WR` to the exact pushed commit.
   Preserve any unrelated untracked experiment data. Never access
   `/home/b10504072/04_WR_archive_step6_pass/`.
3. Verify the frozen source and canonical SOF manifests. Confirm both JTAG
   boards are visible and no other JTAG reader/programmer is active.
4. Temporarily apply only the referenced quarter-step patch to
   `artifacts/milestones/step6_global_time/source/` on Pain. Build Master and
   Slave with the established Quartus 17.0 flow; preserve complete logs and
   candidate SOF hashes. Reverse-apply the patch and verify the source manifest
   before proceeding. A timing-closure failure is recorded but is not a
   functional gate.
5. Program the candidate Slave, then candidate Master. Require the expected
   board identity and successful programming for each. Save programmer logs.
6. Run one short read-only preflight for both boards. Wait for authentic
   `STATUS_TIME_VALID=1` on both before the long capture, for at most 1,800
   seconds after programming; if either bit never asserts, stop and record the
   failed gate. Never force the bit. Do not run multiple JTAG readers
   concurrently.
7. Run `scripts/jtag/read_step6_global_time_observability.tcl` with
   `duration_ms=303000`, `sample_ms=250`, and no board filter. The Tcl reader
   observes each connected board sequentially for the full requested duration.
   Save the unmodified raw output, process status, and SHA-256.
8. Analyze on Laptop with the default required boards `1-11.1,1-11.2`. Record
   each board's exact sample span, row count, largest sample gap, TIME_VALID
   count, first loss (if any), and verdict. Then update this report and push.

## PASS contract

`STEP6_TIME_VALID_300S=PASS` only when, for **each** board `1-11.1` and
`1-11.2`:

- samples cover at least 300,000 ms from first to last sample;
- the observer's board-specific completion record covers at least 300,000 ms;
- at least 301 ordered samples are present and no adjacent gap exceeds
  1,000 ms; and
- every sampled `STATUS_TIME_VALID` is exactly `1`.

Snapshot validity/stability, PPS_VALID, TAI/cycle parseability and monotonicity,
Step 1/link, Step 5 locks, phase offset, and timing closure are recorded only as
diagnostics. This criterion establishes sampled persistence of the exported
TIME_VALID bit; it does not prove cycle-by-cycle behavior between reads, equal
TAI on both boards at one instant, or physical SMA edge alignment. The two
board captures are sequential, not an atomic paired measurement.

## Stop and preservation conditions

- Stop before programming on branch/commit, source/SOF manifest, board identity,
  cable, or competing-JTAG mismatch.
- Stop on build/program/transport/Tcl errors, wrong board identity, or a reset
  that interrupts a capture. Preserve all partial raw records; do not label
  them PASS.
- If any sample has `STATUS_TIME_VALID!=1`, record `NOT_ESTABLISHED`; do not
  tune another parameter or launch a second candidate in the same run.
- Preserve exact source/SOF hashes, full build/program logs, raw capture,
  checksum, analyzer JSON, and final report. Verify the frozen package and
  canonical SOFs remain unchanged after the run.
