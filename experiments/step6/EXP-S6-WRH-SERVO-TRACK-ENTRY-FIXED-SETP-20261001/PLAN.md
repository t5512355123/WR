# EXP-S6-WRH-SERVO-TRACK-ENTRY-FIXED-SETP-20261001

## Objective

Test whether the Slave CKO remains within the strict `abs(CKO) < 60 ps`
band for a fully qualified 300-second window when phase SETP is frozen at the
first successful `WAIT_OFFSET_STABLE → TRACK_PHASE` transition. The capture
must also prove the SETP invariant and keep all required link, Global-Time,
Step 5, and reset gates valid.

## Why this is the next experiment

The immediately preceding in-band-hold candidate reached `TRACK_PHASE`, valid
Global Time, and all five Step 5 locks, but two coherent/UCNT-matched 15-second
smokes still contained out-of-band CKO rows. This means the acquisition path
was reached, but holding SETP only inside ±60 ps did not establish stability.
The earlier fixed-SETP attempt on the frozen package never reached TRACK, so
its latch was not exercised and it provided no fixed-SETP evidence. The latest
run demonstrates that the current `/4` acquisition path can reach TRACK within
the bounded readiness window; retry the diagnostic against the current source.

## Baseline and single intervention

- Branch: `feat/file_cleanup`.
- Exact Laptop baseline: `5c31fdb41be3a106baff0b40031f939177c31632`.
- The current source uses `/4` acquisition and `/4` tracking correction, with
  the 60 ps entry threshold and 120 ps TRACK fallback. Its existing in-band
  deadband is retained; the new boot-lifetime latch disables the entire TRACK
  actuation block before the first TRACK update can execute.
- One diagnostic intervention: at the first successful strict
  `abs(offset) < 60 ps` WAIT→TRACK transition, set an independent static latch.
  Do not clear it during servo reset or reinitialization.
- Once latched, guard every WR-servo phase-setpoint write and arithmetic path:
  servo initialization, `SYNC_PHASE`, and `TRACK_PHASE`. Keep coarse TAI/nsec
  counter correction, state transitions, reporting, and the IPC setter for
  `wrh_tracking_enabled` unchanged. The independent latch must not be controlled
  by IPC.
- Source audit currently finds three `adjust_phase(s->cur_setpoint_ps)` call
  sites in this file; the offline test requires all three to be guarded.
- No PI/gain/threshold, PTP/DMS, Step 5, RTL, SDB, reset-tree, PHY, or timing
  constraint changes.

The latch is intended as a diagnostic intervention, not a pre-judged fix. A
quiet CKO under fixed SETP would be consistent with a tracking-controller
contribution; continuing excursions would show that active tracking writes are
not necessary for those observed excursions. Neither result alone proves a
specific physical measurement fault or controller cause.

## Laptop validation and publish

1. Run the new `tests/test_source_latch.py` and
   `tests/test_analyze_fixed_setpoint.py`.
2. Run the existing Step 6 dashboard-capture tests and `git diff --check`.
3. Verify only the latch/guards and this experiment's test/docs/analysis change.
4. Commit and push to `origin/feat/file_cleanup` before any Pain build.

## Pain build, program, and observation

1. Fast-forward `/home/b10504072/04_WR` to the exact pushed commit. Require a
   clean tracked tree, both expected cables, and no competing Quartus/JTAG
   process. Do not access `/home/b10504072/04_WR_archive_step6_pass/`.
2. Build both firmware and full Quartus images; preserve build logs and SOF
   SHA-256 values.
3. Program Slave `DE5 [1-11.2]`, then Master `DE5 [1-11.1]`; require one
   configured device and zero programmer errors per board.
4. Use only one read-only dashboard/JTAG session for up to 600 seconds after
   programming. Wait for the Slave's first `TRACK_PHASE` sample while Step 1,
   link, Global Time, and all five Step 5 locks are valid. If TRACK is not
   reached by 600 seconds, classify `INCONCLUSIVE_BASELINE_NOT_REACQUIRED`,
   stop, and do not run a smoke or 300-second capture.
5. Stop the dashboard before launching the interleaved observer. Run:

   ```bash
   quartus_stp -t scripts/jtag/read_step6_servo_interleaved_offset.tcl \
       30000 100 1-11.2 1
   ```

   This is a 30-second Slave smoke with `phase_context=1` (same WDIAGS
   publication frame). Require at least 20 trusted samples,
   at least 75% same-frame phase-context coverage, `SERVO_STATE=4` in every
   trusted row, exactly one SETP value, valid Step 1/Global-Time/all five lock
   gates, and no reset/read/transport errors. CKO may be out of band in this
   diagnostic smoke.
6. Only if the smoke passes, run one 300-second capture from the same programmed
   image:

   ```bash
   quartus_stp -t scripts/jtag/read_step6_servo_interleaved_offset.tcl \
       300000 1 1-11.2 1
   ```

   The observer is read-only. Analyze the entire capture, including all
   out-of-band CKO values; do not stop merely because CKO exceeds 60 or 120 ps.
7. `STEP6_STRICT_OFFSET_300S_STABILITY=PASS` requires all of: at least 900
   unique trusted rows, at least 95% structurally trusted rows, no trusted-row
   gap over 1000 ms, every trusted row remains in `TRACK_PHASE` with one SETP
   value, all Step 1/Global-Time/Step 5/reset gates valid, and every accepted
   CKO strictly in `(-60 ps, +60 ps)`. Otherwise report `NOT_ESTABLISHED`.
8. Preserve complete raw capture and checksums, analyze on Laptop, update this
   report and the Step 6 index, push, then fast-forward Pain to the report
   commit.

## Stop conditions

Do not start the 300-second capture if the 30-second smoke fails. Stop the
capture on reset/generation change, Step 1/link loss, Global-Time invalidity,
any Step 5 lock loss, a SETP change, leaving `TRACK_PHASE`, five consecutive
untrusted rows, transport error, or duration completion. A CKO value outside
the strict band is not itself a stop condition during this diagnostic; it is a
direct failure of the Step 6 acceptance criterion and must be retained.

No physical power cycle is planned. Timing closure is not a functional gate.
