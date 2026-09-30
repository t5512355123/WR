# EXP-S6-WRH-SERVO-QUARTER-ACQUIRE-EIGHTH-TRACK-20260930

## Objective

Find a reproducible Step 6 servo setting that keeps every accepted Slave CKO sample strictly inside (-60 ps, +60 ps) for a continuous 300 seconds, while all required Step 1, stable Global-Time, and five Step 5 lock gates remain valid.

## Evidence and hypothesis

The completed EXP-S6-WRH-SERVO-PHASE-QUARTER-STEP-20260930 measured the quarter-step acquisition baseline in a 300-second capture:

- 957 rows; all required health and lock gates remained high.
- Accepted CKO range: −275 to +306 ps.
- Strict abs(CKO) < 60 ps: 351/957 rows (36.7%).
- Fully dashboard-equivalent qualified rows: 315/957 (32.9%).
- Longest consecutive fully qualified run: 11 samples / 3099 ms.
- It did not establish sustained 300-second stability.

The immediately preceding candidate in this sequence, full acquisition + /12 tracking + a 4× fallback guard, produced 0/857 accepted in-band rows and observed no TRACK_PHASE state. Do not carry that wider guard forward.

This candidate follows the earlier quarter-step report's proposed damping test: keep its /4 acquisition, restore the original 2× fallback guard, and change only the fine tracking correction from offset_ps / 4 to offset_ps / 8. A gentler tracking step may reduce the repeated excursions; that remains a hypothesis until measured.

## Single-variable candidate

Reference configuration: EXP-S6-WRH-SERVO-PHASE-QUARTER-STEP-20260930.

WRH_SYNC_PHASE acquisition: offset_ps / 4 (unchanged)
WRH_TRACK_PHASE correction: offset_ps / 4 -> offset_ps / 8 (only functional change)
TRACK fallback guard: 2 × 60 ps (unchanged)
Strict threshold: abs(CKO) < 60 ps (unchanged)

Apply candidate.patch temporarily only to the frozen source copy at artifacts/milestones/step6_global_time/source/. Do not edit the production source tree or any unrelated firmware, RTL, SDB, PPS/TAI, timeout, reset, PHY, or timing-constraint behavior.

## Laptop validation and publish

1. Run scripts/tests/test_step6_servo_quarter_acquire_eighth_track.py.
2. Run git apply --check for this candidate patch against the frozen Step 6 source and git diff --check.
3. Confirm the patch changes only the two documented phase-update expressions relative to the frozen package; relative to the quarter-step reference, only TRACK_PHASE changes.
4. Push this plan, patch, offline test, and build/program runner to feat/file_cleanup before Pain pulls.

## Pain build, program, and observe

1. Fast-forward /home/b10504072/04_WR to the exact pushed commit. Preserve any untracked user data. Never access /home/b10504072/04_WR_archive_step6_pass/.
2. Require a clean tracked worktree, both expected DE5 cables, no competing Quartus/JTAG process, and passing frozen-source (3219-entry) and milestone-artifact (4-entry) manifests.
3. Run this experiment's scripts/build_program_candidate.sh with the exact HEAD. It builds both images, programs Slave then Master, reverse-applies the temporary patch, and verifies both manifests.
4. Run the read-only Step 1–6 dashboard every 10 seconds for at most 30 minutes, with no concurrent JTAG reader. Readiness requires both link gates, stable valid Global Time, and all five Slave Step 5 locks.
5. On readiness, stop the dashboard before the existing 15-second interleaved Slave smoke. Require at least 20 coherent accepted rows, at least 75% UCNT-paired phase-context coverage, all health/lock gates high, median row time below 450 ms, and no reset, transport, timeout, or invalid-read errors.
6. Run 300-second acceptance only if every accepted smoke CKO sample is strictly inside the band. If smoke telemetry/context/health gates pass but the offset gate alone fails, run one 300-second read-only diagnostic and label it diagnostic—not acceptance.
7. Stop on reset/generation change, link/lock loss, repeated invalid frames, bank conflict, or transport error. Do not tune any additional parameter during the run.
8. Copy every raw file back to Laptop, compare each SHA-256, write REPORT.md and raw/SHA256SUMS, push the report, and fast-forward Pain to the report commit. Preserve remote raw in a named stash before syncing; do not drop older stashes.

## Verdict rule

Only a complete 300-second acceptance capture with every accepted CKO sample strictly inside (-60 ps, +60 ps) and every required health/lock gate valid establishes STABLE_OFFSET_300S=PASS. Smoke, diagnostic data, an average/median, or a short in-band run is not a pass.
