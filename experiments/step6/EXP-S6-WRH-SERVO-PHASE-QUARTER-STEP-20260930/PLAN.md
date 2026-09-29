# EXP-S6-WRH-SERVO-PHASE-QUARTER-STEP-20260930

## Objective

Test whether a more conservative WR servo acquisition correction can keep the
Slave phase offset strictly inside `(-60 ps, +60 ps)` for a full 300-second
observation while Global Time and all Step 1/5 gates remain valid.

## Evidence and hypothesis

The coherent full-step update pairs measured a phase-setpoint-to-offset gain
of approximately `-1.964` and `-2.008`; a full correction therefore reverses
the residual with nearly equal magnitude. The earlier half-step candidate
briefly moved `CKO=-184 ps` through `-74 ps` to `-1 ps`, but later samples were
outside the gate and no sustained strict-offset window was established.

For a plant gain near `-2`, a quarter-step acquisition update predicts a
residual factor near `1 + (-2 / 4) = 0.5` per accepted servo correction. This
is a deliberately damped follow-up to the unaccepted half-step candidate; it
is a testable hypothesis, not a claim that the offset noise is caused only by
the acquisition gain.

## Single functional variable

Candidate patch: [`candidate.patch`](candidate.patch).

Change only the `WRH_SYNC_PHASE` acquisition action to add `offset_ps / 4`
to `cur_setpoint_ps`. Leave the 60 ps threshold, `WRH_WAIT_OFFSET_STABLE`
retry behavior, `WRH_TRACK_PHASE` correction, Step 5 SoftPLL controls, PPS/
TAI logic, RTL, SDB, and timing constraints unchanged. The frozen milestone
source tree and checked-in milestone SOFs must remain byte-identical in Git;
apply this experiment patch only temporarily on Pain for candidate build and
reverse-apply it after programming/build evidence is saved.

## Laptop validation and publish

1. Verify the repository is clean on `feat/file_cleanup` at baseline
   `4b4aef834e2ba85d633b09972cec696809ced739`.
2. Run `scripts/tests/test_step6_servo_phase_quarter_step.py`,
   `git apply --check candidate.patch`, and `git diff --check`.
3. Commit and push the plan, isolated source patch, and offline test to
   `origin/feat/file_cleanup`.

## Pain candidate build and hardware run

1. Pull the exact pushed commit on `/home/b10504072/04_WR`; require a clean
   worktree and both DE5 cables visible. Do not access
   `/home/b10504072/04_WR_archive_step6_pass/`.
2. Verify the frozen Step 6 source manifest and baseline SOF hashes before
   applying the candidate patch. Confirm no competing Quartus/JTAG reader or
   writer is active.
3. Apply only `candidate.patch` to the frozen Step 6 source file. Build Master
   firmware + SOF, then Slave firmware + SOF with the existing source-tree
   build scripts. Preserve complete logs and SHA-256 values for the candidate
   SOFs; timing closure is not part of this functional experiment.
4. Program the candidate Slave then candidate Master. Preserve programmer
   logs; require one configured device and zero programming errors.
5. Run the read-only dashboard preflight. If startup prerequisites are not
   ready, observe without reprogramming for at most 30 minutes, using the
   established bounded settling procedure. Do not start the strict capture
   before both links, valid/stable Global Time, and all five Slave Step 5 lock
   fields are valid.
6. Run two 15-second dashboard-equivalent observer smokes. Each must have at
   least 20 rows, at least 75% trusted/UCNT-paired rows, all per-row link,
   Global-Time, Step 1, and five Step 5 lock gates valid, median row time below
   450 ms, and no transport errors or reset/generation changes.
7. If both smokes pass, run one 300-second dashboard-equivalent Slave capture
   using the existing read-only observer at the established 10-second
   dashboard cadence. Preserve the unfiltered capture, timestamps, process
   status, and analyzer output. The target result requires every accepted row
   to meet strict `abs(CKO) < 60 ps` alongside all health/lock gates.
8. Reverse-apply the exact patch and verify the frozen source manifest and
   baseline SOF checksums again. Save the patch, build outputs, programming
   logs, capture, hashes, and analyzer result under this experiment's `raw/`
   paths; copy and verify them on Laptop before writing the final report.

## Stop conditions

- Stop before build/program on branch/commit/source-manifest/cable mismatch,
  occupied JTAG, or a dirty Pain worktree.
- Stop immediately on candidate firmware/Quartus build failure, programming
  error, reset/generation change, board identity change, persistent link loss,
  invalid/stale capture frames, or repeated reader/transport failure.
- Do not automatically change to another gain, threshold, timeout, image, or
  port within this run. Report the measured result and make the next experiment
  a separate Laptop commit.
- Step 6 strict stability is `PASS` only if the full 300-second capture has
  complete valid gates and every accepted Slave phase-offset sample is
  strictly within ±60 ps. Otherwise record the exact duration, sample count,
  in-range count, and failure boundary as `NOT_ESTABLISHED`.

## Data and integrity

Use the existing dashboard-equivalent observer and analyzer; do not add JTAG
writers or diagnostic mailbox writes. Record candidate source revision,
candidate SOF hashes, baseline source/SOF verification, programming result,
capture SHA-256, analyzer output, and the patch reverse-application check.
