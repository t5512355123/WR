# EXP-S6-WRH-SERVO-FULL-ACQUIRE-TRACK-TWELFTH-GUARD-FOURX-20260930

## Objective

Keep every accepted Slave CKO sample strictly inside `(-60 ps, +60 ps)` for a continuous 300-second acceptance capture, with Step 1/link, stable Global Time, and all five Step 5 lock indicators valid on every accepted row.

## Evidence and hypothesis

The immediately preceding full-acquisition + `/12` tracking run reached the `<60 ps` readiness gate once (`+39 ps`), but the next dashboard frame was `−1083 ps`. Its 15-second smoke had 41 coherent accepted rows, of which 10 (24.39%) were strictly in-band. The 300-second diagnostic had 851 accepted rows, only 70 (8.23%) in-band; 55/75 accepted `TRACK_PHASE` rows were in-band, while 663 rows were `WAIT_OFFSET_STABLE`. There were 17 sampled `TRACK_PHASE → SYNC_PHASE` transitions. Health/context gates remained valid and no reset/transport errors occurred.

These results show the TRACK path can be effective when entered, but its occupancy and strict-offset stability are poor. The earlier 4× guard trial used `/2` acquisition and never entered TRACK, so it did not test whether a wider TRACK exit guard helps once the path is reached. This candidate tests that hypothesis with the newly verified full-acquisition baseline; it does not presume the wider guard is a fix.

## Single-variable candidate

Baseline is the just-tested source-default full `SYNC_PHASE` correction, `/12` `TRACK_PHASE` correction, and original 2× fallback guard. Change only:

```text
abs(offset_ps) > 2 × WRH_SERVO_OFFSET_STABILITY_THRESHOLD
                                      ↓
abs(offset_ps) > 4 × WRH_SERVO_OFFSET_STABILITY_THRESHOLD
```

Keep the threshold at 60 ps, source-default full acquisition correction, `/12` tracking correction, ten-miss retry, and all other control behavior unchanged. Do not modify PI thresholds, timeout, PPS/time-valid logic, firmware scheduler, RTL, SDB, reset, PHY, or timing constraints. Apply the patch temporarily only to the frozen source copy and restore/verify both manifests after build/program.

## Laptop validation and publish

1. Start from the clean `feat/file_cleanup` branch at the preceding report commit.
2. Confirm the patch differs from the full-acquisition `/12` candidate only in the TRACK fallback guard. Run the focused offline test, patch apply check, and `git diff --check`.
3. Push the plan, patch, test, runner, and raw `.gitattributes` rule before Pain pulls/builds.

## Pain build, program, and observation

1. Fast-forward `/home/b10504072/04_WR` to the exact pushed commit. Preserve any existing untracked user data; never access `/home/b10504072/04_WR_archive_step6_pass/`.
2. Require clean tracked state, both expected DE5 cables, no competing Quartus/JTAG reader/writer, and passing frozen-source (3219-entry) and milestone-artifact (4-entry) manifests.
3. Run this experiment's `scripts/build_program_candidate.sh` with the exact pulled HEAD. It builds both boards, programs Slave then Master, restores the patch, and verifies both manifests.
4. Run the read-only Step 1–6 dashboard every 10 seconds for at most 30 minutes, with no concurrent JTAG reader. Readiness requires both link gates, valid/stable Global Time, and all five Slave Step 5 locks.
5. On readiness, stop the dashboard before the existing 15-second interleaved Slave smoke. Require at least 20 coherent accepted rows, at least 75% UCNT-paired phase-context coverage, every health/lock gate high, median row time below 450 ms, and no reset/transport/invalid-read errors. Run 300-second acceptance only if every accepted smoke row has strict `abs(CKO) < 60 ps`.
6. If readiness does not occur by the 30-minute bound while link and locks remain healthy, run only the bounded read-only TM-valid attribution; do not start an offset capture or claim offset evidence without readiness.
7. If smoke health/telemetry passes but strict offset alone fails, run one 300-second read-only diagnostic, explicitly not acceptance. Stop on reset change, link/lock loss, repeated invalid frames, bank conflict, or transport error.
8. Copy every Pain raw file to Laptop, compare every SHA-256, write `REPORT.md` and `raw/SHA256SUMS`, push the report, and fast-forward Pain to that report commit. Preserve raw in a named stash before syncing; never drop older stashes.

## Verdict rule

Only a complete 300-second acceptance capture with every accepted CKO sample strictly inside `(-60 ps, +60 ps)` and all required health/lock gates valid is `STABLE_OFFSET_300S=PASS`. Dashboard readings, a transient lock frame, smoke, averages, or a diagnostic capture are not sufficient.
