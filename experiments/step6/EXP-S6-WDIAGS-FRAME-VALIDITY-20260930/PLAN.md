# EXP-S6-WDIAGS-FRAME-VALIDITY-20260930

## Objective

Repeat the Step 6 read-only servo observation while rejecting any critical
CKO/SSTAT/UCNT group that overlaps a WDIAGS cache refresh. The
firmware diagnostics task publishes the servo fields at a 100 ms cadence and
clears `WDIAGS_CTRL.DATA_VALID` while updating the cache. A 300-second capture
must establish whether the prior offset trace remains outside the strict
`abs(CKO) < 60 ps` gate when the diagnostic publication frame is explicitly
validated.

## Scope

- Reader-only change; no production C, RTL, PI/gain, threshold, timing,
  timeout, clock, or PPS change.
- Read `WDIAGS_CTRL` (`base + 0x04`) and mapping counter/inverse
  (`base + 0x134/+0x138`) around a minimal three-register payload (`CKO`,
  `SSTAT`, `UCNT`). Require DATA_VALID high before and after, a valid
  counter/inverse pair at the start, and an unchanged low-16-bit epoch.
- Do not begin the payload at an arbitrary point in the refresh window. At
  the start of each row, read that row's current epoch, then wait up to 350 ms
  for a different epoch with DATA_VALID high and a valid inverse pair. Read
  CKO/SSTAT/UCNT immediately, then validate the frame after the payload. A
  sample that cannot find such a frame is invalid, not a reason to extend the
  capture or relax the guard.
- Do not read DMS/SETP in this framed payload: the first smoke showed the full
  group took about 200 ms and crossed one or two 100 ms WDIAGS epochs. DMS
  correlation remains documented in the earlier experiment; this follow-on
  prioritizes a trustworthy CKO/state sample.
- Preserve all prior read-only restrictions: no target/ARM writes, no
  diagnostic snapshot request, no FPGA programming, reset, or power cycle.
- Do not access `/home/b10504072/04_WR_archive_step6_pass/`.

## Procedure and gates

1. Run the focused analyzer tests and Tcl completeness/syntax checks.
2. The first three short smokes failed the 75% valid-frame floor. The per-row
   epoch-baseline reader then passed: 22/22 valid framed rows, zero reader
   errors, and 195.366 ms median row duration. See `REPORT.md`.
3. A 300-second read-only Slave capture completed in 300277 ms (429 rows).
   All rows were framed and individually valid, but only 2/429 met the strict
   offset condition; Step 6 expanded acceptance was not established. See the
   final report for the next experiment.
4. Keep Step 6 acceptance strict: both boards' Global Time must be valid in
   pre/post checks; all five Slave Step 5 locks and `abs(CKO) < 60 ps` must
   hold in every accepted row across the 300-second window. Timing closure and
   physical SMA edge skew are not part of this gate.
5. Raw evidence was copied to Laptop, verified against SHA-256, analyzed,
   reported, and pushed.

The diagnostic epoch check is a publication-frame guard, not an atomic
hardware snapshot. It can reject observed cache refresh crossings; it cannot
prove behavior between reads or establish servo causality.
