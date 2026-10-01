# EXP-S6-WRH-SERVO-TRACK-INBAND-HOLD-DEADBAND-20261001

## Objective

Test whether holding the phase setpoint while the Slave is already strictly
inside the Step 6 `abs(CKO) < 60 ps` band can extend the in-band dwell to a
complete, fully qualified 300-second capture.

## Baseline and single behavioral change

- Branch: `feat/file_cleanup`.
- Laptop baseline before this candidate: `679ade087db8f63b04585b1b16418e89dedf0fc5`.
- Best measured control reference: historical quarter-acquire/quarter-track
  experiment `EXP-S6-WRH-SERVO-PHASE-QUARTER-STEP-20260930`, built from the
  frozen source origin `74dc28862653d306e0450cf437ba6d3a230d979d` with its
  quarter-acquisition patch. Its 300-second run had 270/418 strictly in-band
  TRACK rows, range `-275..+306 ps`, and a longest fully qualified run of
  3.099 seconds.
- Candidate acquisition returns to the measured `/4` baseline.
- Candidate TRACK behavior: when `abs(offset_ps) < 60 ps`, do not update
  `cur_setpoint_ps` and do not call `adjust_phase()`. At or outside 60 ps,
  retain the existing `/4` tracking correction. The `>120 ps` fallback,
  strict WAIT entry threshold, ten-miss retry, and all other behavior remain
  unchanged.
- Relative to the measured `/4 + /4` baseline, the only functional variable is
  the in-band TRACK actuation deadband. It is a hypothesis, not an established
  fix; prior CKO/DMS samples are separately framed and do not prove actuation
  caused the short dwell.

## Laptop validation and publish

1. Run `scripts/tests/test_step6_track_inband_hold_deadband.py` and
   `git diff --check`.
2. Verify the source diff restores acquisition `/4` and guards only the
   existing TRACK `/4` SETP update with `abs(offset_ps) >= 60 ps`; verify the
   threshold, fallback, retry, reset, Step 5, PTP/DMS, RTL, SDB, and timing
   constraints are unchanged.
3. Commit and push source, test, plan, and initial report to
   `origin/feat/file_cleanup`.

## Pain build, program, and observation

1. Fast-forward `/home/b10504072/04_WR` to the exact pushed commit. Require a
   clean tree, correct branch, both expected DE5 cables, and no concurrent
   Quartus/JTAG session. Never access
   `/home/b10504072/04_WR_archive_step6_pass/`.
2. Build Master and Slave firmware and full Quartus projects from the exact
   candidate commit. Preserve full logs and both SOF SHA-256 values.
3. Program Slave `DE5 [1-11.2]` first, then Master `DE5 [1-11.1]`; require one
   configured device and zero programmer errors for each.
4. Run the read-only dashboard for at most 30 minutes to establish both-board
   Step 1/link, valid/stable Global Time, and all five Slave Step 5 locks. Do
   not interpret lock bits without valid Global Time as offset readiness.
5. If ready, run two sequential 15-second Slave smokes using
   `scripts/jtag/read_step6_servo_interleaved_offset.tcl` with explicit
   `phase_context=2`. Each must contain at least 20 accepted rows, at least
   75% structurally trusted UCNT-matched phase-context rows, all health/lock
   gates valid, every accepted CKO strictly inside `(-60,+60) ps`, and no
   reset, transport, or timeout errors. Do not run a 300-second capture if
   either smoke fails.
6. If both smokes pass, run one 300-second capture in the same read-only mode.
   Pass requires at least 900 unique trusted rows, at least 95% structural
   coverage, no accepted-row gap over 1000 ms, all required Step 1/Global-Time/
   lock/context gates valid, no reset, and every accepted CKO strictly inside
   `(-60,+60) ps`.
7. Stop immediately on link/Step 1 loss, Global-Time invalidity, any Step 5
   lock loss, reset/generation change, board identity change, five consecutive
   invalid rows, transport error, or duration completion. A CKO sample outside
   the band rejects this candidate's 300-second stability claim; preserve the
   complete smoke/capture evidence and do not tune another control in this run.
8. Transfer raw evidence and hashes to Laptop, verify byte identity, complete
   the report, push the report commit, then fast-forward Pain to it.

No physical power cycle is planned. Timing closure is not a functional
acceptance gate.
