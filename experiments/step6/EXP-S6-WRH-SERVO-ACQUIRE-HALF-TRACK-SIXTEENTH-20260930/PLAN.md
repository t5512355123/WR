# EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-SIXTEENTH-20260930

## Objective

Find a WR servo setting that holds the Slave phase offset strictly inside
`(-60 ps, +60 ps)` for 300 continuous seconds, with Step 1/link, stable valid
Global Time, and all five Step 5 lock signals valid in every accepted sample.

## Evidence and one-variable hypothesis

The immediately preceding half-acquisition/eighth-tracking candidate built
and programmed successfully. It reached `TRACK_PHASE` and valid Global Time.
In the 15-second smoke, 42/48 rows had coherent UCNT-paired phase context,
all 48 rows retained Step 1, Global Time, and the five lock gates, but only
17/42 accepted rows met strict `abs(CKO) < 60 ps`; accepted offsets ranged
from −120 to +243 ps. The required 300-second acceptance capture was not run.

Earlier coherent phase-actuator pairs measured a local response near −2:1.
Under that local approximation, a `/8` tracking correction leaves about 75%
of the prior residual after each update, while `/16` leaves about 87.5%. The
smaller `/16` correction may reduce tracking excursions at the cost of slower
convergence. This is a testable damping hypothesis, not a predicted pass.

## Candidate definition

Apply [`candidate.patch`](candidate.patch) only to a temporary copy of the
frozen Step 6 source. Its final values are:

- `WRH_SYNC_PHASE`: `cur_setpoint_ps += offset_ps / 2` (unchanged from the
  preceding programmed candidate).
- `WRH_TRACK_PHASE`: `cur_setpoint_ps += offset_ps / 16` (the only functional
  change relative to the preceding `/2` acquisition + `/8` tracking image).

Keep the strict 60 ps threshold, acquisition `/2`, timeout/retry behavior,
lock controls, PPS/TAI logic, RTL, SDB, reset, timing constraints, and all
other behavior unchanged. Do not edit the frozen source or milestone SOFs.

## Laptop validation and publish

1. Start from a clean `feat/file_cleanup` checkout at `89ae9325`.
2. Check the patch applies to the frozen source package, run the focused
   offline patch/model test, and run `git diff --check`.
3. Commit and push the plan, patch, test, and raw-evidence `.gitattributes`
   rule before Pain pulls or builds.

## Pain build, program, and observation

1. In `/home/b10504072/04_WR`, fast-forward to the exact pushed commit.
   Preserve any pre-existing untracked data; do not delete it to make the
   pull succeed. Do not access `/home/b10504072/04_WR_archive_step6_pass/`.
2. Require a clean tracked worktree, the expected two JTAG cables, and no
   active JTAG/Quartus process. Verify the frozen-source (3219 entries) and
   milestone-artifact (4 entries) manifests before applying the patch.
3. Run the checked-in build/program runner with the exact pulled HEAD:
   `bash experiments/step6/EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-SIXTEENTH-20260930/scripts/build_program_candidate.sh <HEAD>`.
   It verifies the branch/commit, tracked worktree, JTAG occupancy, cables,
   and manifests; applies only `candidate.patch` to the temporary Pain build
   copy; builds Master then Slave; programs Slave then Master; and restores
   the frozen source in an exit trap. Preserve its full raw logs and verify
   both candidate SOF hashes. The initial remote orchestration attempt at
   11:13 +08:00 stopped before patch application or build; its preflight and
   restoration evidence is retained in `raw/preflight/`. A subsequent runner
   attempt also stopped before firmware build because the frozen package
   scripts lack executable mode; the runner now invokes them explicitly with
   `bash` and gives each attempt a unique log prefix.
4. Program Slave `DE5 [1-11.2]`, then Master `DE5 [1-11.1]`; require one
   configured device and zero programming errors/warnings for each.
5. Run the read-only dashboard, sampling every 10 seconds, for at most 30
   minutes. Readiness requires both boards' Step 1/link gates, valid/stable
   Global Time, and all five Slave Step 5 lock signals.
6. Once readiness is reached, run the same 15-second Slave interleaved smoke
   as the previous experiment. Require at least 20 accepted rows, at least
   75% valid UCNT-paired phase-context rows, every per-row Step 1/Global-Time/
   lock gate, strict `abs(CKO) < 60 ps` in every accepted row, median row time
   below 450 ms, and no transport/reset errors. Run the 300-second acceptance
   capture with a 900-second process deadline only if every smoke condition
   passes.
7. If the smoke is otherwise transport/reset clean and Step 1, Global Time,
   and all five lock gates stay high but the strict offset condition fails,
   save the failed smoke and run one 300-second read-only diagnostic capture
   to characterize the servo excursions. Label it diagnostic; it cannot be a
   Step 6 pass. Do not run that capture after a reset, repeated invalid frame,
   link loss, or JTAG transport failure.
8. Reverse-apply the exact patch, verify both manifests again, transfer the
   raw evidence to Laptop and check its hashes, write the report, push it, and
   fast-forward Pain to the report commit.

## Stop conditions and verdict

Stop before build/program on branch/commit, manifest, cable, or JTAG occupancy
mismatch. Stop after build/program failure, board identity change, reset or
generation change, persistent link loss, repeated invalid frames, or reader/
transport failure. Do not change another control parameter in this run.

Only a complete 300-second acceptance capture where every accepted sample is
strictly inside `(-60 ps, +60 ps)` and all required health/lock gates are valid
is `STABLE_OFFSET_300S=PASS`. A dashboard in-band sample or a diagnostic
capture does not qualify.
