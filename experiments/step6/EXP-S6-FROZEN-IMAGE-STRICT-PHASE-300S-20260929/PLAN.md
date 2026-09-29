# EXP-S6-FROZEN-IMAGE-STRICT-PHASE-300S-20260929

## Objective

Re-observe the strict Step 6 phase-offset gate on the exact frozen Step 6
milestone images. Preserve the separate historical digital-trigger evidence;
do not claim the expanded Step 6 gate unless fresh hardware data qualifies it.

## Fixed image and scope

- Master SOF: `artifacts/milestones/step6_global_time/master.sof`
  - SHA-256: `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`
- Slave SOF: `artifacts/milestones/step6_global_time/slave.sof`
  - SHA-256: `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`
- Use the frozen Step 6 programmer wrappers and board mapping only.
- Program Slave first, then Master. Do not compile, reset, power-cycle, alter
  firmware/RTL/servo parameters, or run any other JTAG writer.
- The archived tree `/home/b10504072/04_WR_archive_step6_pass/` is out of
  scope and must remain untouched.
- No consultant is to be contacted or awaited.

## Execution sequence

1. On Pain, verify the exact pulled Git commit and clean worktree. Confirm both
   DE5 JTAG cables are present and no Quartus programmer, JTAG observer, or
   dashboard process is using them.
2. Verify the two SOF SHA-256 values above and the Step 6 source checksum
   manifest. Save the command output under `raw/preflight/`.
3. Program the exact frozen Slave SOF on `DE5 [1-11.2]`, then Master SOF on
   `DE5 [1-11.1]`, using the milestone wrappers. Preserve complete programmer
   logs under `raw/program/`; require one configured device and zero errors.
4. Run a one-shot read-only dashboard smoke with a 2000 ms per-board
   observation window. Save all output under `raw/observe/`. A link-down
   result immediately after programming is an early-startup observation, not
   by itself a persistent regression: the historical exact-image reproduction
   first captured both links up about 20 minutes after the last programmer
   completed. Stop here only for missing boards, an actual reader/JTAG error,
   or an identity mismatch.
5. Run a read-only dashboard startup-settling capture at a 10-second target
   cadence and 2000 ms per-board window, with screen clearing disabled, for
   up to 30 minutes from completion of the Master programming operation. Stop
   earlier only after both boards report healthy Step 1/link, valid/stable
   Global Time, and all required Slave lock/offset fields are valid for ten
   consecutive dashboard samples. Preserve the complete log and timestamps.
   If those readiness conditions are not reached by the 30-minute deadline,
   stop with `NOT_ESTABLISHED`; do not reprogram or power-cycle.
6. Only after startup readiness is reached, run the separate read-only
   dashboard capture for at least 300 seconds at a 10-second target cadence
   with a 2000 ms per-board window. Save the unfiltered output,
   process exit/timeout status, and start/end times. Do not use the dashboard's
   host-side Global-Time wait option.
7. Transfer the raw logs back to the laptop experiment directory, analyze
   per-board sample counts and time span, verify every record, write the
   verdict, and push the report/evidence to GitHub. Pull that exact result
   commit to Pain and verify identical commit/tree and clean status.

## PASS criteria

This run supports `STEP6_EXPANDED_OBSERVATION = PASS` only if all conditions
below are supported by fresh data from the programmed frozen images:

- Both boards remain Step 1/link healthy and provide valid, stable Global-
  Time snapshots with `TIME_VALID=1` and `PPS_VALID=1` throughout the accepted
  observation window.
- The Slave's signed `WR_SERVO_OFFSET_PS` is a valid integer and strictly
  inside `(-60, +60)` in every accepted sample. Exactly `+60` or `-60` fails.
- On the Slave, Helper lock, Main frequency lock, Main phase lock, Main lock,
  and PSTAT lock remain asserted in every accepted sample across at least 300
  seconds of fresh observations.
- The observation contains enough accepted samples to establish the interval
  (target at least 25 per board); board identity is stable and no reset,
  generation change, stale/invalid frame, or JTAG transport anomaly occurs.
- Historical Step 6A same-PPS and Step 6B dual-board scheduled digital-trigger
  gates remain separately identified as previously passed; this re-observation
  does not silently replace or re-run them.

If any condition fails or data is incomplete, report `NOT_ESTABLISHED` or
`INCONCLUSIVE` with the exact boundary. A short smoke or a single in-range
offset sample is not a 300-second PASS.

## Stop conditions

Stop before programming if the checkout, SOF hash, cable identity, or free-JTAG
preflight does not match. Stop during observation for a missing board, actual
JTAG/reader failure, or board identity change. A transient startup link-down
sample is preserved and observed read-only up to the fixed 30-minute deadline;
it is not treated as PASS or as a persistent failure before that deadline. If
reset or generation changes, stop and preserve the event. Do not compensate
with a reprogram, power cycle, servo adjustment, or a different image in this
run.

## Safety and data handling

The dashboard is read-only and uses only the fitted-design read probes and the
existing runtime snapshot reader. Do not trigger diagnostic snapshots or write
Wishbone/ARM/target registers. All generated evidence belongs in this
experiment's `raw/` tree; the frozen milestone source and archived tree remain
unchanged.
