# EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-TWELFTH-20260930

## Objective

Find a Step 6 servo setting that keeps every accepted Slave CKO sample strictly inside (-60 ps, +60 ps) for one complete 300-second capture, with Step 1/link, stable valid Global Time, and all five Step 5 lock signals valid in every accepted row.

## Evidence and single-variable hypothesis

The immediately preceding /2 acquisition + /8 tracking candidate reached valid Global Time and exercised the tracking path. Its 15-second smoke produced 42 coherent UCNT-paired rows, with CKO from -120 to +243 ps and 17/42 rows inside the strict 60 ps band. The servo changed among SYNC_PHASE, TRACK_PHASE, and WAIT_OFFSET_STABLE during those observations.

The subsequent /2 + /16 candidate did not reach the Global-Time readiness gate during 174 dashboard frames over 28m50s. Slave link and all five displayed Step 5 bits stayed high, while TIME_VALID/PPS_VALID remained 0 and the dashboard result remained LOCK_ACQUIRED_NOT_STABLE. No CKO smoke was run, so that candidate supplies no offset evidence and does not prove that /16 caused the time-validity failure.

Previously measured coherent phase-actuator response was approximately -2:1. Under that local linear approximation, tracking correction /12 leaves a residual fraction between /8 and /16. This intermediate value tests whether /8 excursions can be damped without the slower /16 candidate's readiness problem. This is a hypothesis only; it predicts neither Global-Time recovery nor a pass.

## Candidate definition

Apply candidate.patch only to a temporary copy of the frozen Step 6 source. Final values:

- WRH_SYNC_PHASE acquisition: cur_setpoint_ps += offset_ps / 2 (unchanged).
- WRH_TRACK_PHASE correction: cur_setpoint_ps += offset_ps / 12.

Relative to the just-programmed /2 + /16 candidate, the only functional change is the tracking divisor /16 -> /12. Keep thresholds, timeout/retry behavior, lock controls, PPS/TAI logic, RTL, SDB, reset, timing constraints, and all other behavior unchanged. Do not edit frozen source or milestone SOFs.

## Laptop validation and publish

1. Start from a clean feat/file_cleanup checkout at f0540b00f1726827fd8746c7010df1e4bd5549ef.
2. Verify the patch applies to the frozen source package; run the focused offline patch/model test and git diff --check.
3. Commit and push plan, patch, test, runner, and the raw-evidence .gitattributes rule before Pain pulls or builds.

## Pain build, program, and observation

1. Fast-forward /home/b10504072/04_WR to the exact pushed commit. Preserve any existing untracked data; do not access /home/b10504072/04_WR_archive_step6_pass/.
2. Require a clean tracked worktree, both expected JTAG cables, no active Quartus/JTAG process, and matching frozen-source (3219 entries) and milestone-artifact (4 entries) manifests.
3. Run scripts/build_program_candidate.sh with the exact pulled HEAD. It applies only candidate.patch to the temporary source copy, builds Master then Slave, programs Slave then Master, and restores the source in an EXIT trap. Save full raw logs and SOF hashes.
4. After programming, use the repository-root scripts/monitor/step1_6_dashboard.sh (not the older dashboard copy inside the frozen source package). Sample every 10 seconds for at most 30 minutes. This dashboard also displays WR PTP servo state and phase offset. Do not run another JTAG reader concurrently.
5. Readiness requires both boards' Step 1/link gates, valid/stable Global Time, and all five Slave Step 5 lock signals. If readiness occurs, stop the dashboard and run the same 15-second interleaved Slave smoke as the previous experiment. Require at least 20 accepted rows, at least 75% valid UCNT-paired phase-context rows, every per-row Step 1/Global-Time/lock gate, strict abs(CKO) < 60 ps in every accepted row, median row time below 450 ms, and no transport/reset errors. Run a 300-second acceptance capture with a 900-second process deadline only if all smoke criteria pass.
6. If readiness does not occur by the 30-minute bound while Slave Step 1/link and all five displayed lock signals remain healthy, stop the dashboard and run the existing read-only source-attribution observer for up to 180 seconds: quartus_stp -t scripts/jtag/read_step6_tmvalid_source_attribution.tcl 180000 1000 {DE5 [1-11.2]}. Save its output as diagnostic evidence. It does not count as offset acceptance or Step 6 pass; do not start a 300-second capture in this case.
7. If smoke meets all health and transport conditions but fails only the strict offset condition, preserve the failed smoke and run one 300-second read-only diagnostic capture to characterize the excursions. Label it diagnostic, never acceptance.
8. Reverse-apply the exact patch, verify both manifests, copy all raw files to Laptop, compare their SHA-256 values, write REPORT.md and raw/SHA256SUMS, push the report, then fast-forward Pain to that report commit.

## Stop conditions and verdict

Stop before build/program on branch/commit, manifest, cable, or JTAG occupancy mismatch. Stop on build/program failure, board identity change, reset/generation change, persistent link loss, repeated invalid frame, or reader/transport failure. Never change another control parameter in this run.

Only a complete 300-second acceptance capture where every accepted sample is strictly inside (-60 ps, +60 ps) and all required health/lock gates are valid is STABLE_OFFSET_300S=PASS. Dashboard values or source-attribution diagnostics do not qualify.
