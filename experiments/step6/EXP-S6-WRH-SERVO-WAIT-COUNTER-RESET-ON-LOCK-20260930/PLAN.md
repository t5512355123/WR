# experiments/step6/EXP-S6-WRH-SERVO-WAIT-COUNTER-RESET-ON-LOCK-20260930

## Objective

Find a Step 6 servo setting that keeps every accepted Slave CKO sample strictly inside `(-60 ps, +60 ps)` for a continuous 300-second acceptance capture, with Step 1/link, stable Global Time, and all five Step 5 lock signals valid on every accepted row.

## Evidence and hypothesis

The last successful `/2 acquisition + /12 tracking` run reached valid/stable Slave Global Time and produced 857 coherent accepted rows in its 300-second diagnostic. Only 310/857 (36.17%) met the strict CKO band; the trace had 154 `SYNC_PHASE`, 398 `TRACK_PHASE`, and 305 `WAIT_OFFSET_STABLE` rows, including 44 sampled `TRACK_PHASE → SYNC_PHASE` transitions.

The following four-times TRACK-exit-guard experiment did not reach Global-Time readiness: the dashboard saw 166 `WAIT_OFFSET_STABLE`, 14 `SYNC_PHASE`, and zero `TRACK_PHASE` frames. Its modified guard was therefore not exercised. Read-only source attribution classified the current boundary as `FAIL_PTP_SERVO_NOT_COMPLETE`, with no reset, transport error, or mapping mismatch.

Source audit found that `missed_iters` increments when `WAIT_OFFSET_STABLE` misses the 60 ps threshold and resets only after it reaches 10. When a later sample succeeds and enters `TRACK_PHASE`, the counter is not cleared. Thus a success can carry prior misses into a future WAIT episode. The hypothesis is that this stale count can cause an early reacquisition after a later TRACK exit and contribute to unnecessary state churn. This is a source-derived hypothesis, not established causality.

## Single-variable candidate

Apply `candidate.patch` only to the temporary frozen Step 6 source copy.

Relative to the known `/2 acquisition + /12 tracking`, original-2×-guard candidate, the only new behavior is:

- When `remaining_offset < WRH_SERVO_OFFSET_STABILITY_THRESHOLD` and the WAIT state successfully transitions to `TRACK_PHASE`, set `missed_iters = 0`.

Keep the acquisition divisor (/2), tracking divisor (/12), original TRACK fallback guard (2×60 ps), strict 60 ps entry threshold, retry limit of 10, timeout/retry behavior otherwise, lock controls, PPS/TAI behavior, RTL, SDB, reset, and timing constraints unchanged. The frozen milestone source and SOFs remain byte-identical in Git; the patch is temporary on Pain and must be reverse-applied after build/program.

## Laptop validation and publish

1. Start from the clean `feat/file_cleanup` branch at the preceding experiment-report commit.
2. Verify `candidate.patch` applies to the frozen source; run the focused offline contract/model test and `git diff --check`.
3. Commit and push this plan, patch, test, runner, and byte-preserving `.gitattributes` rule before Pain pulls or builds.

## Pain build, program, and observation

1. Fast-forward `/home/b10504072/04_WR` to the exact pushed commit. Preserve any existing untracked user data; do not access `/home/b10504072/04_WR_archive_step6_pass/`.
2. Require clean tracked state, both expected DE5 cables, no competing Quartus/JTAG reader or writer, and passing frozen-source (3219-entry) and milestone-artifact (4-entry) manifests.
3. Run `scripts/build_program_candidate.sh` with the exact pulled HEAD. It applies only the candidate patch temporarily, builds Master and Slave, programs Slave then Master, and restores/verifies both manifests.
4. Run the read-only Step 1–6 dashboard every 10 seconds for at most 30 minutes, with no concurrent JTAG reader. Readiness requires both link gates, valid/stable Global Time, and all five Slave Step 5 locks.
5. If readiness occurs, stop the dashboard before the existing 15-second interleaved Slave smoke. Require at least 20 coherent accepted rows, at least 75% UCNT-paired phase-context coverage, every accepted row's Step 1/Global-Time/five-lock gates, median row time below 450 ms, no reset/transport/invalid-read errors, and strict `abs(CKO) < 60 ps` in every accepted row before starting 300-second acceptance.
6. If readiness does not occur by the 30-minute bound while link and lock indicators remain healthy, perform only the existing bounded read-only TM-valid source-attribution capture. Do not start an offset capture or claim an offset result in that case.
7. If smoke health/telemetry passes but strict offset alone fails, preserve it and run one 300-second read-only diagnostic capture, explicitly not acceptance. Stop on reset change, link/lock loss, repeated invalid frames, bank conflict, or transport error.
8. Restore/verify manifests, transfer all raw files to Laptop, compare every SHA-256, write `REPORT.md` and `raw/SHA256SUMS`, push the report, then fast-forward Pain to that report commit. Preserve existing raw via a named stash before syncing; never drop old stashes.

## Verdict rule

Only a complete 300-second acceptance capture with every accepted sample strictly inside `(-60 ps, +60 ps)` and all required health/lock gates valid is `STABLE_OFFSET_300S=PASS`. Dashboard samples, source-attribution diagnostics, smoke, averages, and a successful build/program are not a substitute.
