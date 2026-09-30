# EXP-S6-WR-REARM-TO-STABLE-WINDOW-TRACE-20261001

## Purpose

Trace the Slave's observed initial `WRS_S_LOCK`, timeout record, return to
`WRS_PRESENT`, re-entry to `WRS_S_LOCK`, and source-backed successful WR lock
event. If that admission sequence completes, test whether the existing frozen
`/4 acquire + /4 track` image sustains every Step 6 functional gate and strict
`abs(CKO) < 60 ps` for 300 sampled seconds.

This is a passive observer/analyzer experiment. It does not alter the servo,
build source, firmware, RTL, or SOF contents. It does not claim every instant
between samples or physical SMA edge skew.

## Exact baseline and pinned images

- Repository: <https://github.com/t5512355123/WR>
- Branch: `feat/file_cleanup`
- Laptop/GitHub/Pain source baseline: `00d1a6a5154238700bbcd674e2638a0e6f15932e`
- Candidate build source commit: `9c9afa345c1de03760ec9ee07eb742888c3fa8fe`
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`
- Slave `DE5 [1-11.2]` SOF SHA-256:
  `13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19`
- Master `DE5 [1-11.1]` SOF SHA-256:
  `697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a`

Pain image paths:

~~~text
artifacts/milestones/step6_global_time/source/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof
artifacts/milestones/step6_global_time/source/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof
~~~

If either pinned image is missing, its hash differs, or the build provenance
cannot be verified, stop before programming. Do not compile or substitute an
image.

## Permitted file changes

Only this experiment's `scripts/`, `PLAN.md`, `REPORT.md`, and captured raw
evidence may change. Production C/RTL, firmware, PI/gain, thresholds, DMS/PTP,
timeout behavior, SETP, and all SOFs are frozen.

## Observer contract

- One Slave JTAG source-probe session and one read-only WB reader. Do not run a
  dashboard or another reader concurrently.
- Do not issue a shell command, controller/firmware command, reset, power
  cycle, `DATA_SNAPSHOT`, or Helper PI snapshot.
- WDIAGS frames require `DATA_VALID=1`, `DATA_SNAPSHOT=0`, unchanged full
  mapping-counter and inverse words before/after, and a valid source mapping.
  `UCNT` is required to advance for a publication to count as fresh. Matching
  UCNT at two reads alone is not treated as an atomicity proof.
- Global Time uses the separate probe sequence `63 → 62 → 63`; both sequence
  reads must match, and the published snapshot plus `TIME_VALID` and
  `PPS_VALID` must be valid. Global-Time and WDIAGS groups are not claimed to
  be cross-group atomic.
- Preserve raw A6C (`0x00100A6C`) and A8C (`0x00100A8C`) words, with separate
  read-begin/read-end timestamps. A6C carries failure count/role/state and
  sticky-disable metadata; A8C carries the last lock-result/reason/timer
  fields. Their separate reads are not represented as one-cycle causality.
- Source-backed success events are `WRS_S_LOCK`→next `WRS_LOCKED`, current
  `WRS_LOCKED`, or local `TX` message ID `0x1002` with nonzero count. No poll
  counter subtraction or S_LOCK tail value triggers admission or a verdict.

## Capture and workflow

1. Run the Tcl policy regression, full-script Tcl completeness check, Python
   analyzer tests, wrapper syntax check, and `git diff --check` on Laptop.
2. Push the observer-only experiment to GitHub.
3. On Pain, fast-forward `/home/b10504072/04_WR` to that exact commit and
   verify clean status and both pinned SOF hashes/provenance.
4. Program the exact pinned Slave SOF, then the exact pinned Master SOF, once
   each. Do not compile. Run the single read-only observer immediately after
   programming.
5. Maximum capture is 900 seconds: up to 600 seconds for a source-backed
   recovery-admission event, then up to 300 seconds of stable qualification.
   The external watchdog is 930 seconds. The sample delay is a minimum 100 ms;
   actual read cadence is recorded.
6. Copy raw logs and checksums to Laptop, verify hashes, run the offline
   analyzer, complete `REPORT.md`, and push the evidence. Stop after this
   capture; do not automatically start a second experiment.

## Admission and 300-second stable-window rules

Recovery admission is reported separately and is supported only after the
observer records an initial `WRS_S_LOCK`, a new count delta paired in the same
row with A8C reason 3 (`WR_S_LOCK_TIMEOUT`), a later `WRS_PRESENT`, a later
`WRS_S_LOCK`, and one of the source-backed success events. Because A6C and A8C
are separate reads, this is a sampled correlation, not proof of same-cycle
causality.

The stable window starts on the first *later* fresh, fully qualified
publication after recovery admission. Every counted publication must have:

- Step 1 gate and all five Slave Step 5 lock signals asserted;
- stable, valid Global-Time snapshot and PPS/time-valid flags;
- servo `TRACK_PHASE` (`SSTAT` state 4);
- strict signed `abs(CKO_PS) < 60` (exactly ±60 fails);
- unchanged reset/boot signatures, no new failure record, and no sticky
  extension-disable record;
- a valid WDIAGS publication with advancing UCNT and coherent phase payload.

At least 300,000 ms must elapse from the first trusted qualification to the
last fresh qualifying publication. Adjacent fresh publications may be at most
1,000 ms apart. Cached repeats never extend the window.

## Immediate stops

- missing/ambiguous Slave target, fatal Tcl/JTAG error, or mismatched pinned
  SOF hash/provenance;
- any boot/reset signature change;
- Step 1 loss after Step 1 was established;
- valid sticky extension-disable metadata;
- five consecutive invalid required raw/guarded frames;
- same UCNT with changed phase payload, UCNT rollback/implausible jump, or
  failure-counter discontinuity;
- trusted loss of any stable-window qualification, new failure during the
  window, or a fresh-observation gap greater than one second;
- 600 seconds without recovery admission, or 900 seconds total without the
  300-second sampled window.

A timeout followed by `WRS_PRESENT` is a recovery boundary, not an automatic
stop. Do not retry or start a second capture in this experiment.

## Interpretation limits

`RECOVERY_ADMISSION_SUPPORTED` and `PASS_300S_SAMPLED_STABLE_OFFSET` are
separate outcomes. A sampled pass does not prove continuous behavior between
samples, physical SMA output skew, or analog clock alignment. No timing-closure
claim is part of this experiment.
