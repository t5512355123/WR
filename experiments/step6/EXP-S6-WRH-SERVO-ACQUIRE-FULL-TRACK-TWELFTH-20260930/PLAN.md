# EXP-S6-WRH-SERVO-ACQUIRE-FULL-TRACK-TWELFTH-20260930

## Objective

Reach stable Slave phase offset strictly inside `(-60 ps, +60 ps)` for a continuous 300-second accepted CKO capture, while Step 1/link, stable Global Time, and all five Step 5 lock indicators remain valid on every accepted row.

## Evidence and hypothesis

The preceding `/2 acquisition + /12 tracking`, original-2×-guard candidate achieved valid/stable Global Time in one run, but its 300-second diagnostic contained only 310/857 (36.17%) accepted rows with strict `abs(CKO) < 60 ps`. The most recent wait-counter-reset trial showed 163 `WAIT_OFFSET_STABLE`, 17 `SYNC_PHASE`, and zero `TRACK_PHASE` dashboard frames during its 30-minute observation. Its new counter-reset branch only executes on a successful `WAIT_OFFSET_STABLE → TRACK_PHASE` transition and was therefore not exercised. The read-only TM-valid attribution ended with `FAIL_PTP_SERVO_NOT_COMPLETE`, while link, Step 5 locks, UCNT progress, and transport remained healthy.

This candidate tests whether using the source-default full `SYNC_PHASE` correction reaches the strict entry band more reliably than the `/2` correction. This is a hypothesis, not a proven cause.

## Single-variable candidate

Use the frozen Step 6 source with one temporary patch:

- Keep `SYNC_PHASE` at the source-default full correction `s->cur_setpoint_ps += offset_ps`, replacing the prior `/2` candidate behavior.
- Keep `TRACK_PHASE` correction at `/12`, as in the previously measured best candidate.
- Keep the original 2× TRACK fallback guard, strict `<60 ps` WAIT entry threshold, ten-miss retry, and every other control unchanged.
- Do not include the unexercised `missed_iters` reset, broaden the guard, or modify PI thresholds, PPS/time-valid logic, firmware scheduler, RTL, SDB, reset, PHY, or timing constraints.

The candidate patch is applied only to the temporary frozen-source copy for build/program and must be reverse-applied with both manifests verified afterward.

## Laptop validation and publish

1. Start from the clean `feat/file_cleanup` branch at the preceding report commit.
2. Verify the candidate patch changes only the TRACK correction `/4 → /12`; verify the frozen `SYNC_PHASE` line remains the source-default full correction. Run the focused offline test and `git diff --check`.
3. Push this plan, patch, test, runner, and raw `.gitattributes` rule before Pain pulls/builds.

## Pain build, program, and observation

1. Fast-forward `/home/b10504072/04_WR` to the exact pushed commit. Preserve existing untracked user data; never access `/home/b10504072/04_WR_archive_step6_pass/`.
2. Require clean tracked state, both expected DE5 cables, no competing Quartus/JTAG reader or writer, and passing frozen-source (3219-entry) and milestone-artifact (4-entry) manifests.
3. Run this experiment's `scripts/build_program_candidate.sh` with the exact pulled HEAD. It builds both boards, programs Slave then Master, restores the source patch, and verifies both manifests.
4. Run the read-only Step 1–6 dashboard every 10 seconds for at most 30 minutes, with no concurrent JTAG reader. Readiness requires both link gates, valid/stable Global Time, and all five Slave Step 5 locks.
5. If ready, stop the dashboard before the existing 15-second interleaved Slave smoke. Require at least 20 coherent accepted rows, at least 75% UCNT-paired phase-context coverage, all health/lock gates high, median row time below 450 ms, and no reset/transport/invalid-read errors. Start 300-second acceptance only if every accepted smoke row has strict `abs(CKO) < 60 ps`.
6. If readiness does not occur by 30 minutes while link/lock remain healthy, run only the bounded read-only TM-valid attribution. Do not run an offset capture or claim an offset result without readiness.
7. If smoke telemetry is healthy but strict offset alone fails, preserve one 300-second read-only diagnostic (not acceptance). Stop on reset change, link/lock loss, repeated invalid frames, bank conflict, or transport error.
8. Transfer every Pain raw file to Laptop, compare every SHA-256, write the report and `raw/SHA256SUMS`, push the report, and fast-forward Pain to that report commit. Preserve raw with a named stash before syncing; do not drop prior stashes.

## Verdict rule

Only a complete 300-second acceptance capture with every accepted CKO sample strictly inside `(-60 ps, +60 ps)` and all required health/lock gates valid is `STABLE_OFFSET_300S=PASS`. Dashboard samples, source-attribution diagnostics, smoke, averages, or successful builds do not substitute for that proof.
