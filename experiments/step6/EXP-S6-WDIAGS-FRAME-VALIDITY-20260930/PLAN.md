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
- Do not read DMS/SETP in this framed payload: the first smoke showed the full
  group took about 200 ms and crossed one or two 100 ms WDIAGS epochs. DMS
  correlation remains documented in the earlier experiment; this follow-on
  prioritizes a trustworthy CKO/state sample.
- Preserve all prior read-only restrictions: no target/ARM writes, no
  diagnostic snapshot request, no FPGA programming, reset, or power cycle.
- Do not access `/home/b10504072/04_WR_archive_step6_pass/`.

## Procedure and gates

1. Run the focused analyzer tests and Tcl completeness/syntax checks.
2. On Pain, run a 15-second smoke with at least 20 rows, zero transport
   errors/timeouts, median row duration below 250 ms, and at least 75% rows
   with valid WDIAGS framing and an unchanged diagnostic epoch.
3. If smoke passes, run one 300-second read-only Slave capture, with a 900
   second hard deadline. Stop on reset signature change, five consecutive
   untrusted rows, transport failure, or deadline; preserve partial evidence.
4. Keep Step 6 acceptance strict: both boards' Global Time must be valid in
   pre/post checks; all five Slave Step 5 locks and `abs(CKO) < 60 ps` must
   hold in every accepted row across the 300-second window. Timing closure and
   physical SMA edge skew are not part of this gate.
5. Copy raw evidence to Laptop, verify hashes, analyze, report, and push.

The diagnostic epoch check is a publication-frame guard, not an atomic
hardware snapshot. It can reject observed cache refresh crossings; it cannot
prove behavior between reads or establish servo causality.
