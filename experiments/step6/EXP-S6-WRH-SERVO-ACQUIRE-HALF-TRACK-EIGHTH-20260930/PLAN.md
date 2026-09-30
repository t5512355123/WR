# EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-EIGHTH-20260930

## Objective

Reach and then hold the strict Slave phase-offset gate `abs(CKO) < 60 ps` for
one complete 300-second capture, while Step 1, stable/valid Global Time, and
all five Step 5 lock signals remain valid in every accepted row.

## Evidence and single variable

The immediately preceding `/8 TRACK_PHASE` candidate built and programmed,
but its 29m56s post-program settling bound produced no logged in-band sample
or `TRACK_PHASE` dashboard sample. All 168 logged Slave rows had Step 1/link
and all five Step 5 lock bits high, but `TIME_VALID/PPS_VALID` stayed 0 and
the offset ranged from −1243 to +3633 ps. That run therefore did not exercise
the `/8` tracking correction.

Earlier coherent offset/setpoint pairs measured the phase-actuator response
near −2:1. With a half-offset acquisition correction, the local linear model
predicts the next residual will fall into the existing 60 ps band in one
update for both observed directions. A prior half-gain run also observed a
correction from `CKO=-184 ps` with `SETP delta=-92 ps`, followed by `-74 ps`
and `-1 ps`, but did not establish the full 300-second stability target.

Create the composite candidate from the frozen Step 6 source with:

- `WRH_SYNC_PHASE`: `cur_setpoint_ps += offset_ps / 2`.
- `WRH_TRACK_PHASE`: `cur_setpoint_ps += offset_ps / 8`.

Relative to the immediately preceding eighth-step candidate, the only
functional change is acquisition `/4` → `/2`. Keep the 60 ps threshold,
tracking `/8`, retry/timeout behavior, lock controls, PPS/TAI logic, RTL, SDB,
reset, timing constraints, and all other behavior unchanged.

## Laptop validation and publish

1. Require a clean `feat/file_cleanup` checkout at the preceding report
   commit `91c45d94`.
2. Run `git apply --check` against the frozen source, the focused offline
   model/patch test, and `git diff --check` on new text files.
3. Commit and push this plan, patch, and test before Pain pulls or builds.

## Pain build, program, and observation

1. Pull the exact pushed commit in `/home/b10504072/04_WR`. Verify matching
   HEAD, clean tracked worktree, both intended JTAG cables, and no active
   Quartus/JTAG process. Do not access
   `/home/b10504072/04_WR_archive_step6_pass/`.
2. Verify the frozen-source (3219 entries) and milestone-artifact (4 entries)
   manifests. Apply only `candidate.patch` to the Pain build copy of the
   frozen source. Build Master firmware/SOF, then Slave firmware/SOF; retain
   full logs and SOF hashes.
3. Program Slave `DE5 [1-11.2]` then Master `DE5 [1-11.1]`. Require one
   configured device and zero programming errors for each. Save programmer
   logs.
4. Run the read-only dashboard for at most 30 minutes after programming.
   Readiness requires both boards' Step 1/link gates, valid/stable Global
   Time, and all five Slave Step 5 lock signals. Do not treat lock bits alone
   as readiness.
5. If readiness is reached, stop the dashboard and run a 15-second
   `read_step6_servo_interleaved_offset.tcl` smoke for the Slave. Require at
   least 20 accepted rows, at least 75% valid UCNT-paired phase-context rows,
   all per-row Step 1/Global-Time/lock gates, strict `abs(CKO) < 60 ps` in
   every accepted row, median row time below 450 ms, and no transport/reset
   errors. Only then run its 300-second capture with a 900-second process
   deadline; every accepted row must meet the same complete gate.
6. If readiness is not reached by the bound but link and five lock bits stay
   healthy, stop the dashboard and run the existing read-only
   `read_slave_offset_update_correlation.tcl` smoke, then one 300-second
   diagnostic capture. Store both logs in this experiment's `raw/observe/`;
   do not write into the earlier experiment folder. These diagnostic rows
   do not count as a Step 6 pass.
7. Reverse-apply the exact patch and verify frozen source and milestone
   artifact manifests. Transfer raw logs to Laptop, verify every checksum,
   write the report, push it, then fast-forward Pain to the report commit.

## Stop conditions and verdict

Stop before build/program for branch/commit, manifest, board/cable, or JTAG
occupancy mismatch. Stop on build/program failure, board identity change,
reset/generation change, persistent link loss, repeated invalid frames, or
reader/transport failure. Do not change any second control parameter.

Only a complete 300-second accepted capture with every row strictly inside
`(-60 ps, +60 ps)` and all required health/lock gates valid is
`STABLE_OFFSET_300S=PASS`. If settling never establishes readiness, the
300-second functional capture is `NOT_RUN`; use the separately labeled
correlation data only to choose the next acquisition change. Restore and
verify the frozen source after every candidate build.
