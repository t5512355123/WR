# EXP-S6-WRH-SERVO-TRACK-EXIT-GUARD-FOURX-20260930

## Objective

Find a Step 6 setting that keeps every accepted Slave CKO sample strictly inside `(-60 ps, +60 ps)` for a continuous 300-second acceptance capture, with the required Step 1/link, valid/stable Global-Time, and five Step 5 lock gates.

## Evidence and hypothesis

The immediately preceding `/2 acquisition + /12 tracking` run built and programmed successfully and reached healthy Slave Global Time. Its 300-second diagnostic had 857 coherent accepted rows. Step 1, stable valid Global Time, and all five Step 5 locks were high on every accepted row, but only 310/857 (36.17%) had strict `abs(CKO) < 60 ps`; CKO ranged from `−322 ps` to `+296 ps`.

The source exits `TRACK_PHASE` when `abs(offset_ps) > 2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD` (2 × 60 ps). The diagnostic recorded 398 TRACK rows, 305 WAIT rows, 154 SYNC rows, and repeated transitions; in-band fractions were TRACK 262/398, WAIT 48/305, SYNC 0/154. This is consistent with reacquisition churn, but CKO and servo decision values came from separate read intervals, so the capture does not establish same-cycle causality.

## Single-variable candidate

Apply `candidate.patch` only to the temporary frozen Step 6 source copy. Final behavior:

- Acquisition correction remains `offset_ps / 2`.
- Tracking correction remains `offset_ps / 12`.
- Change only the TRACK fallback guard from `2 × stability_threshold` to `4 × stability_threshold` (120 ps to 240 ps at the current 60 ps threshold).
- Keep the WAIT state's strict `<60 ps` condition, threshold definition, timeout/retry behavior, lock controls, PPS/TAI logic, RTL, SDB, reset, timing constraints, and every other behavior unchanged.

This is a bounded hypothesis, not an assumed fix: tracking may continue through moderate excursions but still falls back to acquisition above 240 ps.

## Laptop validation and publish

1. Start from clean `feat/file_cleanup` at baseline `13a43ef951f998fe3b368abc7607ebdd9cc704ee`.
2. Verify the patch applies to the frozen source; run the focused offline contract test and `git diff --check`.
3. Commit and push this plan, patch, runner, test, and byte-preserving raw-evidence attributes before Pain pulls or builds.

## Pain build, program, and observation

1. Preserve all existing untracked Pain data; do not access `/home/b10504072/04_WR_archive_step6_pass/`.
2. Require exact branch/commit, clean tracked worktree, both expected JTAG cables, no active Quartus/JTAG process, and passing frozen-source (3219-entry) and milestone-artifact (4-entry) manifests.
3. Run `scripts/build_program_candidate.sh` with the exact pulled HEAD. It applies only this patch temporarily, builds Master then Slave, programs Slave then Master, and restores/verifies the frozen source and artifact packages in its exit trap.
4. Use the repository-root read-only Step 1–6 dashboard every 10 seconds for at most 30 minutes. Do not run a second JTAG reader concurrently. Readiness requires both board link gates, valid/stable Global Time, and all five Slave Step 5 locks.
5. Once ready, stop the dashboard before running the existing 15-second interleaved Slave smoke. Require at least 20 coherent accepted rows, at least 75% UCNT-paired phase-context coverage, every accepted row's Step 1/Global-Time/five-lock gates, median row time below 450 ms, no reset/transport/invalid-read errors, and strict `abs(CKO) < 60 ps` in every accepted row before starting 300-second acceptance.
6. If readiness does not occur within 30 minutes while link and lock indicators remain healthy, stop and perform only the existing bounded read-only time-valid source-attribution capture; do not claim an offset result.
7. If smoke health/telemetry passes but offset alone fails, preserve it and run one 300-second read-only diagnostic capture. Label it diagnostic, not acceptance. Stop on reset change, link/lock loss, repeated invalid frames, bank conflict, or transport error.
8. Restore/verify manifests, transfer raw files to Laptop, compare every SHA-256, write `REPORT.md` and `raw/SHA256SUMS`, push the report, then fast-forward Pain to that report commit. Preserve existing raw via a named stash before syncing; never drop old stashes.

## Verdict rule

Only a complete 300-second acceptance capture with every accepted sample strictly inside `(-60 ps, +60 ps)` and all required health/lock gates valid is `STABLE_OFFSET_300S=PASS`. Smoke, dashboard samples, diagnostics, or in-band averages cannot substitute.
