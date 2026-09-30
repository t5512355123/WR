# EXP-S6-WRH-SERVO-EIGHTH-ACQUIRE-EIGHTH-TRACK-20260930

## Objective

Reach a continuous 300-second Slave phase-offset capture with every accepted
CKO sample strictly inside `(-60 ps, +60 ps)`, while Step 1, stable Global
Time, and all five Step 5 lock gates remain valid.

## Evidence and rationale

The immediately preceding quarter-acquire/eighth-track candidate built and
programmed successfully, but its 29m50s read-only dashboard had `0/180`
Slave offsets inside the strict band. Its state was
`WAIT_OFFSET_STABLE` in 165 frames, `SYNC_PHASE` in 15, and `TRACK_PHASE` in
zero. Slave Global Time remained invalid behind the same offset gate. Thus
the candidate's tracking `/8` change was not exercised.

Source audit confirms `WRH_SYNC_PHASE` applies the acquisition adjustment,
then enters `WRH_WAIT_OFFSET_STABLE`; a miss increments `missed_iters`, and
ten misses return to `WRH_SYNC_PHASE`. The next controlled test changes only
acquisition damping relative to the preceding candidate. The measured
phase-actuation response is approximately `-2:1`; `/8` should reduce the
coarse correction versus `/4` and may avoid repeated misses. This remains a
hypothesis, not a claimed fix.

## Single-variable candidate

Reference: `EXP-S6-WRH-SERVO-QUARTER-ACQUIRE-EIGHTH-TRACK-20260930`.

- `WRH_SYNC_PHASE`: `offset_ps / 4` → `offset_ps / 8` (only change relative
  to the preceding candidate).
- `WRH_TRACK_PHASE`: remains `offset_ps / 8`.
- `WRH_WAIT_OFFSET_STABLE` threshold remains strict `< 60 ps`.
- Fallback remains the original `2 × 60 ps` guard; all other controls,
  firmware, RTL, SDB, PPS/TAI, timeout, reset, PHY, and timing constraints
  remain unchanged.

Apply the patch temporarily only to the frozen source copy at
`artifacts/milestones/step6_global_time/source/`. Do not modify the production
source tree or access Pain's protected Step6 archive.

## Laptop validation and publish

1. Run `scripts/tests/test_step6_servo_eighth_acquire_eighth_track.py`.
2. Verify `git apply --check`, `git diff --check`, the two intended source
   expressions, and frozen-source/artifact manifests.
3. Push this plan, patch, offline test, and build/program runner to
   `feat/file_cleanup` before Pain pulls.

## Pain build, program, and observe

1. Fast-forward `/home/b10504072/04_WR` to the exact pushed commit while
   preserving all unrelated files. Never access
   `/home/b10504072/04_WR_archive_step6_pass/`.
2. Require clean tracked files, expected Master and Slave cables, no competing
   Quartus/JTAG process, and passing 3,219-entry source and four-entry
   milestone-artifact manifests.
3. Run this experiment's `scripts/build_program_candidate.sh` with exact
   `HEAD`. It builds both images, programs Slave then Master, restores the
   temporary patch, and rechecks both manifests.
4. Run the read-only dashboard every 10 seconds for at most 30 minutes, with
   no concurrent JTAG reader. Readiness requires both boards' link gates,
   valid/stable Global Time, and all five Slave Step 5 locks.
5. If ready, stop the dashboard before the existing 15-second interleaved
   Slave smoke. Require at least 20 coherent accepted rows, at least 75%
   UCNT-paired phase-context coverage, all health/lock gates high, median row
   time below 450 ms, and no reset, transport, timeout, or invalid-read
   errors.
6. Run 300-second acceptance only if every accepted smoke CKO sample is
   strictly inside the band. If only the offset gate fails while telemetry,
   context, and health gates pass, run one 300-second read-only diagnostic
   clearly labelled diagnostic, not acceptance.
7. Stop on reset/generation change, link/lock loss, repeated invalid frames,
   bank conflict, or transport error. Do not tune further parameters.
8. Copy every raw file back to Laptop, compare each SHA-256, write the report
   and `raw/SHA256SUMS`, push them, and fast-forward Pain to the report commit.
   Preserve Pain raw with a named stash before syncing; never drop older stashes.

## Verdict rule

Only a complete 300-second acceptance capture with every accepted CKO sample
strictly inside `(-60 ps, +60 ps)` and every required health/lock gate valid
establishes `STABLE_OFFSET_300S=PASS`. Dashboard samples, a smoke, a short
in-band run, or a diagnostic do not prove the objective.
