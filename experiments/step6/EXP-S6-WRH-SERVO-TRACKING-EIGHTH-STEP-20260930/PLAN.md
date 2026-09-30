# EXP-S6-WRH-SERVO-TRACKING-EIGHTH-STEP-20260930

## Objective

Find a WR servo setting that keeps every trusted Slave phase-offset sample
strictly inside `(-60 ps, +60 ps)` for a complete 300-second observation,
while the dashboard Step 1, valid/stable Global Time, and all five Step 5 lock
signals remain valid.

## Evidence and hypothesis

The previous quarter-step acquisition candidate built and programmed
successfully, and its two smoke runs passed. During the 300-second capture,
all 957 rows had valid Step 1, Global Time, and Step 5 lock gates, but only
315/957 (32.9%) rows met the full dashboard-equivalent phase gate. In sampled
`TRACK_PHASE`, 75/375 rows were fully qualified; the longest full-gate run was
3.099 seconds. Therefore the 300-second stability target remains unmet.

The preceding coherent setpoint/offset update pairs measured a local plant
gain near -2. With the acquisition correction kept at one quarter, the
in-range `WAIT_OFFSET_STABLE` distribution was much better than the sampled
`TRACK_PHASE` distribution. A one-eighth tracking correction is the next
single-variable test: under the same local linear approximation it reduces
the per-update correction magnitude and should reduce tracking excursions.
This is a hypothesis only; sequential register reads and the prior capture do
not establish that tracking gain alone caused the excursions.

## Single variable relative to the prior candidate

Apply [`candidate.patch`](candidate.patch) only to a temporary copy of the
frozen Step 6 source on Pain. The composed candidate must have:

- `WRH_SYNC_PHASE`: `cur_setpoint_ps += offset_ps / 4` (unchanged from the
  previous quarter-step candidate).
- `WRH_TRACK_PHASE`: change `cur_setpoint_ps += offset_ps / 4` to
  `cur_setpoint_ps += offset_ps / 8`.

Keep the strict 60 ps threshold, timeout/retry behavior, lock controls, PPS/TAI
logic, RTL, SDB, reset, timing constraints, dashboard gates, and observation
procedure unchanged. Do not edit the tracked frozen source or milestone SOFs.

## Laptop validation and publish

1. Require a clean `feat/file_cleanup` checkout after the prior experiment
   report commit `dcda6231`.
2. Run `git apply --check` against the frozen source, the focused offline test,
   and `git diff --check` for the new text files.
3. Commit and push the plan, patch, and test to `origin/feat/file_cleanup`
   before Pain pulls or builds this candidate.

## Pain build and hardware run

1. Pull the exact pushed commit in `/home/b10504072/04_WR`. Require matching
   HEAD, clean tracked worktree, both expected DE5 cables, and no active
   Quartus/JTAG reader or writer. Do not inspect or modify
   `/home/b10504072/04_WR_archive_step6_pass/`.
2. Verify the frozen Step 6 source manifest and milestone SOFs. Apply only
   `candidate.patch` to the frozen source file. Build Master firmware/SOF,
   then Slave firmware/SOF. Save complete logs and candidate SOF SHA-256s.
3. Program Slave (`DE5 [1-11.2]`) then Master (`DE5 [1-11.1]`); require one
   configured device and zero programming errors per board.
4. Use the existing read-only dashboard and bounded settling procedure. Do
   not begin captures until both boards have healthy Step 1/link and valid,
   stable Global Time, and the Slave has all five Step 5 locks.
5. Run two 15-second dashboard-equivalent smokes. Each needs at least 20 rows,
   at least 75% trusted/UCNT-paired rows, every row's required link/Step 1/
   Global-Time/lock gates, median row time below 450 ms, and no transport
   errors or reset/generation changes.
6. If both smokes pass, run one 300-second read-only Slave capture with the
   existing observer at the established cadence. Retain the unfiltered data,
   timing, process status, and analyzer output. The target is every accepted
   row strictly `abs(CKO) < 60 ps` with all health/lock gates valid.
7. Reverse-apply the exact patch and verify the frozen source and SOF
   manifests. Transfer raw evidence to Laptop and verify every checksum before
   writing the final report.

## Stop conditions and verdict

Stop before build/program for a branch, commit, manifest, board, cable, or
JTAG-occupancy mismatch. Stop on build/program failure, board identity change,
reset/generation change, persistent link loss, invalid/stale frames, or
repeated transport failure. Do not change another parameter in this run.

Only a complete 300-second capture with every accepted sample strictly inside
±60 ps and every required health/lock gate valid is `STABLE_OFFSET_300S=PASS`.
Otherwise report the exact duration, valid/qualified counts, consecutive-run
length, offset range, and stop/failure boundary as `NOT_ESTABLISHED`.
