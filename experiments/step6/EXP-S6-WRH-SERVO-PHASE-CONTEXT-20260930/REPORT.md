# EXP-S6-WRH-SERVO-PHASE-CONTEXT-20260930 — Report

## Verdict

```text
SAME_FRAME_PHASE_CONTEXT_SMOKE = FAIL (0/5 accepted coherent rows)
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
- Raw log: [`smoke_same_frame_guard_20260930.log`](raw/observe/smoke_same_frame_guard_20260930.log)
- SHA-256: `58b0bfb5440b14c1e14bda86c665d47141c4b082dc72c9f76e1833378a71b96d`

## Smoke observations

- Configured duration 15,000 ms, requested delay 1 ms, phase-context mode 1.
- Quartus/Tcl returned exit 0 after the reader stopped at five consecutive
  untrusted samples; observed duration was 1,051 ms and row count was 5.
- Individual reads and DMS/SETP context reads were valid in 5/5 rows.
- The primary WDIAGS epoch changed between the before/after checks in 5/5
  rows (`DIAG_FRAME_VALID=0`, `COHERENT=0`); accepted context rows: 0/5.
- The guarded payload interval was 88.752–92.772 ms. The three added DMS/SETP
  transactions occupied 33.141–34.578 ms of that interval.
- Global Time and all five Step 5 lock fields were valid in 5/5 rows. Timeout,
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
explicit. Run another short smoke first; do not start a 300-second capture
unless it passes.
