# EXP-S6-WRH-SERVO-QUARTER-ACQUIRE-REACQUISITION-TRACE-20260930

## Purpose

Obtain a durable, high-resolution, structurally guarded acquisition trace on
the exact fixed-SETP candidate after the previous 600-second observation did
not sample TRACK_PHASE. This is an acquisition reproducibility diagnostic,
not a Step 6 acceptance run and not a new controller candidate.

The fixed-SETP hypothesis remains unadjudicated until a trusted
WAIT_OFFSET_STABLE -> TRACK_PHASE event is observed and post-entry data are
captured.

## Frozen candidate and image identity

- Git branch: feat/file_cleanup
- Published baseline/report commit: 1c274654de78fbaef5c4da275ef8062279b640db
- Fixed-SETP candidate source commit: 9c9afa345c1de03760ec9ee07eb742888c3fa8fe
- Frozen source origin: 74dc28862653d306e0450cf437ba6d3a230d979d
- Slave SOF SHA-256: 13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19
- Master SOF SHA-256: 697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a

On Pain, first locate and hash the existing two SOFs. If either exact image is
absent or has a different SHA-256, stop. Do not rebuild, substitute, or
reprogram a non-matching image. If both hashes match, program those existing
SOFs Slave first, then Master; this is a fresh programming run, with no
compile and no control-source change.

## Allowed changes

This experiment adds only:

- a dedicated read-only acquisition Tcl observer;
- a wrapper that writes output directly to the permanent experiment raw path;
- an offline analyzer and tests;
- this plan, report, and raw checksum manifest.

Do not modify the candidate patch, wrh-servo.c, any acceptance-reader
semantics, Step 5 controls, gains, thresholds, missed_iters, DMS/PTP,
PPS/TAI, RTL, QSF/SDC, reset behavior, or the FPGA images.

## Acquisition capture

Use one read-only reader session, Slave DE5 [1-11.2] only, with separate
guarded primary and context WDIAGS frames joined by UCNT. The fixed sampling
delay is 250 ms; actual sample spacing is also determined by guarded-frame
publication waits and is recorded per row.

The Tcl observer starts its own high-resolution monotonic timer after the
Slave JTAG source-probe setup and ends normally at 600,000 ms, after finishing
the row already in progress. It records:

~~~text
ACQ_START_MONOTONIC_US
REQUESTED_DURATION_MS=600000
LAST_ROW_START_MS
LAST_ROW_END_MS
ELAPSED_MS
STOP_REASON
~~~

The shell wrapper applies a 605-second external watchdog only as a hung-process
safety net. The Tcl observer's 600-second monotonic deadline is authoritative.
The log is opened directly under raw/observe/ before the reader starts.
Signal/exit handling may append status but must never remove or truncate raw
capture data.

### Per-row fields

Primary guarded frame:

~~~text
CKO_PS, SERVO_STATE, UCNT
DIAG_EPOCH_BEFORE, DIAG_EPOCH_AFTER, DIAG_FRAME_VALID
~~~

Separate context guarded frame:

~~~text
PHASE_CONTEXT_UCNT, SETP_PS, DMS_HI, DMS_LO, DMS_PS
PHASE_CONTEXT_EPOCH_BEFORE, PHASE_CONTEXT_EPOCH_AFTER
PHASE_CONTEXT_FRAME_VALID, PHASE_CONTEXT_MATCH
~~~

Record health and reset information on every row:

~~~text
Step 1 gate and all component status bits
HELPER_LOCK, MAIN_FREQ_LOCK, MAIN_PHASE_LOCK, MAIN_LOCK, PSTAT_LOCK
GLOBAL_TIME_VALID, STATUS_TIME_VALID, STATUS_PPS_VALID
snapshot valid/stable/count and ESCR validity
BOOT_GENERATION, CPU_RESET_COUNT, WR_CORE_RESET_COUNT, SI_CONFIG_DROP_COUNT
~~~

Global-Time validity is recorded, but it must not determine structural trust
during acquisition. The <60 ps gate can legitimately keep Global Time
invalid while acquisition evidence remains useful.

### Validity layers

STRUCTURALLY_TRUSTED_ROW=1 requires all low-level reads to be valid, both
guarded frames valid, matching primary/context UCNT, and a valid reset
signature. It does not require Global Time, Step 1, Step 5 lock, or the <60 ps
condition.

STEP6_QUALIFYING_ROW=1 additionally requires Global Time valid, Step 1 PASS,
all five Step 5 locks high, and strict abs(CKO_PS) < 60.

Do not merge these two meanings. Do not claim the separate frames are atomic
in one hardware cycle.

## Stop conditions

Stop acquisition immediately on:

- a structurally trusted SERVO_STATE=4 (TRACK_PHASE);
- reset/boot-generation signature change;
- Step 1 gate loss or invalidity;
- any of the five Step 5 locks low or invalid;
- five consecutive structurally untrusted rows;
- fatal JTAG/reader error;
- the 600,000 ms monotonic deadline.

Do not stop merely because Global Time is invalid, abs(CKO)>60 ps,
abs(CKO)>120 ps, or the state is SYNC_PHASE (3) / WAIT_OFFSET_STABLE (5).

## Follow-on if TRACK is observed

Do not reset or reprogram. After the acquisition Tcl exits, run the existing
15-second phase-context smoke sequentially in the same live hardware state:

~~~sh
quartus_stp -t scripts/jtag/read_step6_servo_interleaved_offset.tcl \
  15000 1 1-11.2 2
~~~

Require at least 20 structurally valid rows, at least 75% UCNT-matched
contexts, all trusted rows at SSTAT=4, exactly one SETP value, valid Global
Time, Step 1 PASS, all five locks high, and no reset/transport issue. Only if
the smoke passes, run the original 300-second fixed-SETP diagnostic with
phase_context=2. CKO outside 60/120 ps is not itself a stop condition.

## If TRACK is not observed in 600 seconds

Report whether TRACK_PHASE was sampled and whether the fixed-SETP latch trigger
was established. If TRACK_PHASE is not sampled, do not claim the latch
definitely did not fire because a sampled observer can miss a brief state
transition and the latch has no telemetry bit. A full-window but data-inadequate
capture remains inconclusive.

Report structural coverage, health/reset counts, SSTAT distribution, CKO,
SETP, DMS, UCNT, adjacent deltas, and each trusted acquisition-state interval.
In particular, correlate SYNC_PHASE rows to the next adjacent trusted
publication: CKO before, SETP before/after and delta, DMS before/after and
delta, UCNT, and whether observed delta_SETP is consistent with the /4
acquisition expression. Describe this as correlation, not same-cycle
causality.

If coverage is inadequate, classify as inconclusive. If a full, well-covered
600-second trace keeps Step 1 and all five locks healthy, has no reset, and
contains only state 3/5, classify the observed acquisition failure without
tuning gain/threshold. Use the trace to decide the next production-side
experiment; do not preselect /2, /8, or missed_iters changes.

For this diagnostic only, predeclare a full trace as data-adequate when it has
at least 1,000 structurally trusted rows, at least 95% structural coverage,
zero analyzer-vs-row validity-flag mismatches, and Step 1 plus all five lock
gates high on every trusted row. This is a diagnostic evidence-quality gate,
not a Step 6 acceptance threshold.

## Laptop verification and publish

Before pushing:

1. Require a clean feat/file_cleanup worktree at the exact current origin tip.
2. Run the new analyzer/offline tests and shell syntax check.
3. Run git diff --check.
4. Confirm the diff contains no production control, acceptance-reader, or
   candidate-SOF source change.
5. Commit and push the experiment scripts/plan/report to
   origin/feat/file_cleanup.

After the Pain capture, transfer raw output to this experiment's raw/
directory, verify SHA-256, complete REPORT.md, write raw/SHA256SUMS, and push
the report. Keep the active Step 6 goal open unless a separately qualified
300-second capture proves every accepted offset sample is strictly inside
(-60 ps,+60 ps) with all required health gates valid.
