# EXP-S6-WRH-SERVO-FIRST-TRACK-FIXED-SETP-OPEN-LOOP-20260930

## Objective

Determine whether the observed CKO excursions continue after the first
successful `TRACK_PHASE` entry when the phase SETP is frozen, without changing
PLL gains, thresholds, DMS/PTP behavior, or the Step 5 control loops. This is a
root-cause diagnostic, not a Step 6 acceptance run.

## Evidence and exact baseline

Use the known `EXP-S6-WRH-SERVO-PHASE-QUARTER-STEP-20260930` candidate:

- Branch: `feat/file_cleanup`.
- Historical candidate/source commit: `c97d45f2f3ad028ded9ecf1e10060461a1edc432`.
- Frozen Step 6 source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- `WRH_SYNC_PHASE` acquisition: `offset_ps / 4`.
- `WRH_TRACK_PHASE` correction: `offset_ps / 4` before the one-shot latch.
- Entry threshold: strict `abs(offset) < 60 ps`.
- Normal exit guard: strict `abs(offset) > 120 ps`.
- `missed_iters`, Step 5 locks/gains, PTP, DMS, PPS/TAI, RTL, SDB,
  constraints, and reset behavior remain unchanged.

The 300-second baseline observed CKO `−275..+306 ps`, with `351/957` rows
strictly inside ±60 ps. Correct source mapping is `SSTAT=3` `SYNC_PHASE`,
`4` `TRACK_PHASE`, and `5` `WAIT_OFFSET_STABLE`. The historical report's 4/5
names were reversed; raw numeric counts are unchanged.

## Single diagnostic intervention

The candidate is applied only to the frozen source copy under
`artifacts/milestones/step6_global_time/source/` by
[`candidate.patch`](candidate.patch). It retains quarter-step acquisition and
tracking, then latches a diagnostic fixed-SETP mode at the first successful
`WAIT_OFFSET_STABLE → TRACK_PHASE` transition.

The independent latch blocks later phase-setpoint writes from servo init, the
`SYNC_PHASE` acquisition branch, and the `TRACK_PHASE` tracking branch. Do not
assign to `wrh_tracking_enabled` at latch time and do not change its IPC setter.
The entire TRACK control block is gated by both the tracking-enabled flag and
the independent latch, so the latch blocks phase correction and the normal
`>120 ps` fallback even if IPC later enables tracking. In `SYNC_PHASE`, only
the SETP arithmetic and `adjust_phase()` call are guarded; the existing
`WAIT_HW` flag and state transition remain outside that guard. Coarse
TAI/nsec counter handling, state reporting, and other behavior remain
untouched. Do not clear the latch on servo reset; any reset/reinitialization
ends this capture.

This is one diagnostic behavior—freeze phase actuation after first TRACK—not
a gain or threshold change. The additional `SYNC_PHASE` and init guards are
required because source audit found these phase-write paths are not guarded by
`wrh_tracking_enabled`; without them, the SETP invariant could fail if a
coarse-sync/reinitialization path occurred.

## Laptop validation and publish

1. Require a clean `feat/file_cleanup` baseline at
   `92825901488f5b9a6717fdc460a863e3b4ee676f` before this experiment's changes.
2. Verify the candidate patch applies to the frozen source; run the new
   offline test and `git diff --check`.
3. Confirm the frozen-source SHA256 manifest has 3,219 entries and the
   milestone artifact manifest has 4 entries before pushing.
4. Commit and push the plan, candidate patch, build/program runner, offline
   test, and corrected quarter-step report to `origin/feat/file_cleanup`.

## Pain build and program

1. Fast-forward `/home/b10504072/04_WR` to the exact pushed commit. Preserve
   unrelated files and all existing stashes. Never access
   `/home/b10504072/04_WR_archive_step6_pass/`.
2. Require clean tracked files, both expected DE5 JTAG cables, no competing
   Quartus/JTAG process, and passing frozen-source/artifact manifests.
3. Run `scripts/build_program_candidate.sh EXPECTED_COMMIT`. It applies the
   patch temporarily to the frozen source copy, builds both firmware/SOFs,
   programs Slave then Master, restores the patch, and verifies both
   manifests again. Save complete logs and candidate SOF hashes.
4. Use one read-only dashboard/JTAG session only. Observe acquisition for at
   most **600 seconds** after programming. When the Slave first reports
   numeric `SSTAT=4` (`TRACK_PHASE`), stop the dashboard. If no such state is
   seen by 600 seconds, stop as `INCONCLUSIVE_BASELINE_NOT_REACQUIRED`; do not
   tune another parameter.
5. Do not run a dashboard concurrently with the interleaved observer. Start a
   15-second Slave smoke with explicit phase context mode 2:

   ```bash
   quartus_stp -t scripts/jtag/read_step6_servo_interleaved_offset.tcl \
       15000 1 1-11.2 2
   ```

   Smoke gates: at least 20 structurally trusted rows; at least 75% of rows
   have valid separate context frames joined by matching UCNT; all trusted
   rows remain `SSTAT=4`; SETP has exactly one distinct value; Global Time,
   Step 1, and all five Slave Step 5 lock gates are valid; no reset/generation
   change, Global-Time loss/invalidity, or transport/read error. Do **not**
   require `abs(CKO)<60 ps` for this diagnostic smoke.
6. If smoke passes, run one **300-second diagnostic** with the same explicit
   `phase_context=2` observer. It is not an acceptance run. Do not stop merely
   because `abs(CKO)` exceeds 60 or 120 ps; those excursions are the subject
   of the experiment.
7. Stop immediately on reset/boot-generation change, CPU/WR/SI reset counter
   change, Step 1/link loss, Global-Time loss/invalidity, any of the five Step
   5 locks dropping, SETP changing, `SSTAT != 4`, transport error, or five
   consecutive untrusted rows. Preserve the partial capture and exact stop
   reason.
8. Transfer all raw files to Laptop, verify their SHA-256 values, analyze,
   write `REPORT.md` and `raw/SHA256SUMS`, push the report, then fast-forward
   Pain to the report commit without dropping any stash.

## Required analysis

Only trusted primary/context frames joined by identical UCNT count as phase
context rows. Separate frames with a matching publication/update ID are not
claimed to be same-cycle atomic.

Report SETP min/max/distinct count; CKO and DMS min/max; maximum adjacent
absolute deltas and counts at or above 120 ps; `R = CKO − DMS` min/max and
adjacent jumps; SSTAT distribution; UCNT-paired row count; and all health,
lock, reset, and Global-Time validity counts. Keep raw data and do not
substitute mean/RMS for the strict range/jump analysis.

Interpretation is correlational. Fixed SETP with continuing CKO excursions
shows tracking adjustment is not necessary for those observed excursions;
it supports investigating delay/timestamp/measurement paths but does not
prove a specific fault. A quieter CKO under fixed SETP is consistent with a
tracking-controller contribution but is not causal proof because this is not
a same-session A/B.

## Verdict

This candidate is a diagnostic only. `STABLE_OFFSET_300S=PASS` remains
unestablished unless a separate, fully qualified 300-second acceptance run
has every accepted Slave CKO sample strictly within `(-60 ps, +60 ps)` and all
required health/lock gates valid.
