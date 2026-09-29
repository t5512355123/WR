# EXP-S6-WRH-SERVO-PHASE-CONTEXT-20260930 — Report

## Verdict

```text
SAME_FRAME_PHASE_CONTEXT_SMOKE = FAIL (0/10 accepted across two 5-row attempts)
300S_CAPTURE                   = NOT RUN (smoke stop condition)
STEP6_EXPANDED_GATE            = NOT ESTABLISHED
```

The observer and source-mapped DMS/SETP reads executed successfully, but
adding them to the existing CKO/SSTAT/UCNT payload made every sampled WDIAGS
frame cross a publication epoch. The frame guard correctly rejected all five
rows and stopped. No long capture was started and no control was changed.

## Provenance and safety

- Branch: `feat/file_cleanup`; Pain source revision: `acf929a3`.
- Board: Slave `DE5 [1-11.2]`; read-only JTAG session.
- No firmware/RTL, PI/gain, threshold, timeout, PPS, image, reset, or
  power-cycle changes. No build or FPGA programming.
- Pain archive `/home/b10504072/04_WR_archive_step6_pass/` was not accessed.
- Officially captured raw log: [`smoke_same_frame_guard_20260930.log`](raw/observe/smoke_same_frame_guard_20260930.log)
  - SHA-256: `58b0bfb5440b14c1e14bda86c665d47141c4b082dc72c9f76e1833378a71b96d`
- Recovered first-run raw log: [`smoke_same_frame_guard_wrapper_first_run_20260930.log`](raw/observe/smoke_same_frame_guard_wrapper_first_run_20260930.log)
  - SHA-256: `9d31e7a4fa998835bc885a9bab08de6df05eff298a83ad73f712c4f405794f1d`

## Smoke observations

- Two 15,000 ms-configured smokes used 1 ms requested delay and
  `phase_context=1`. Both stopped after five consecutive untrusted samples;
  each produced 5 rows and 0 accepted coherent rows.
- The first Quartus run's output was accidentally redirected by the outer
  shell wrapper to a root-level filename. That log was recovered and
  preserved. Its Quartus/Tcl footer says the script completed successfully;
  the wrapper's exit-marker capture was malformed, so this is supplemental
  evidence rather than the official exit-status record.
- The second run was captured normally: Quartus/Tcl exit 0, observed duration
  1,051 ms, five rows, and stop reason `five_consecutive_untrusted_samples`.
- Individual reads and DMS/SETP context reads were valid in all 10 rows.
- The primary WDIAGS epoch changed between the before/after checks in all 10
  rows (`DIAG_FRAME_VALID=0`, `COHERENT=0`); accepted context rows: 0/10.
- The guarded payload interval was 88.752–92.772 ms. The three added DMS/SETP
  transactions occupied 33.141–34.578 ms of that interval in the normally
  captured attempt.
- Global Time and all five Step 5 lock fields were valid in 10/10 rows. Timeout,
  invalid-read, reset-change, and reset-stop counts were all zero.
- DMS and SETP values were returned, but because their enclosing WDIAGS frame
  was rejected, they are diagnostic smoke output only and were excluded from
  correlation analysis.

## Interpretation and next action

This smoke demonstrates a reader-bandwidth/frame-alignment limitation, not a
servo or hardware failure. Do not relax the epoch guard. The next bounded
reader-only iteration should capture CKO/SSTAT/UCNT and DMS/SETP in separate,
independently guarded WDIAGS frames, and accept a joined context row only when
both frames are valid and their published UCNT values match. This preserves
frame validity while making the non-atomic, update-ID-matched relationship
explicit. The bounded follow-up is specified in the [UCNT-paired frame
plan](../EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930/PLAN.md). Run
another short smoke first; do not start a 300-second capture unless it passes.
