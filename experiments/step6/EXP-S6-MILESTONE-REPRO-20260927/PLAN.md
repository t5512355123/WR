# EXP-S6-MILESTONE-REPRO-20260927

## Objective

Independently reproduce the Step 6 milestone from its frozen source, then
revalidate the Step 5 direct-lock stability, Step 6A Global-Time validity and
same-PPS agreement, and Step 6B scheduled dual-board digital trigger.

## Source and build identity

- Hardware/firmware source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Laptop repository commit used by Pain: `eedd3664c3ba7cfdddfed86de346e828ce32aca9`.
- Frozen source path: `artifacts/milestones/step6_global_time/source/`.
- Build tool: Quartus Prime Standard Edition 17.0.0 Build 595.
- Build order: Master firmware, Master Quartus; Slave firmware, Slave Quartus.
- Programming order: Slave (`DE5 [1-11.2]`), then Master (`DE5 [1-11.1]`).

The only functional firmware overlay in this experiment is SFF-8636-aware
QSFP+ / QSFP28 serial-ID parsing for the installed module. It reads Upper Page
00h without changing the page selector and validates both checksums before
looking up the module's existing calibration record. No guessed calibration,
PLL tuning, timeout, reset, RTL, SDB, or timing-constraint changes are allowed.

## Acceptance sequence

1. Independently clean-build both boards from the frozen source and retain the
   complete firmware/Quartus logs, MIFs, QSF/SDC hashes, timing summaries, and
   SOF hashes in `raw/build/`.
2. Program the newly rebuilt SOFs in Slave-then-Master order. Retain complete
   Programmer logs in `raw/program/`.
3. Run the current read-only Step 1–6 dashboard with a bounded Global-Time
   wait. Preserve its raw output in `raw/observe/`.
4. Capture direct Step 5 lock signals with timestamps for at least 300 seconds:
   Helper/HPLL, Main frequency, Main phase, Main lock, PSTAT, link, and reset
   stability. A one-shot dashboard is not sufficient for this gate.
5. Verify valid/stable Global-Time snapshots on both boards and collect multiple
   common PPS labels for same-PPS cycle comparison.
6. Use one common future Global-Time target for the validated digital trigger
   and repeatability run. Preserve every approved arm/target write and all
   post-fire reads. Require one firing per board, matching digital labels, and
   healthy post-fire link/Global Time.

Physical SMA/output-pin skew is outside this digital experiment and remains
`NOT_EVALUATED` without oscilloscope evidence.

## Non-gating diagnostic

The guarded `sfp params` query is an ancillary calibration/identity diagnostic,
not a Step 6 Global-Time or digital-trigger acceptance gate. If the observer
cannot establish a safe idle command boundary, it must stop without sending the
command and record the result as inconclusive. No calibration values may be
guessed or substituted. The query's inconclusive status does not invalidate a
Step 6 PASS when all Step 5 stability, Global-Time, same-PPS, and digital-trigger
criteria above pass.

## Stop conditions

- Any build/programmer error: stop before programming or observing, preserve
  logs, and diagnose the first failed boundary.
- Read-only preflight failure, reset/generation change, link loss, or invalid
  snapshots: stop the applicable acceptance stage and retain raw evidence.
- Step 6 is not PASS unless every acceptance item above is independently
  verified from this newly built/programmed image.
