# EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930

## Objective

Repeat the phase-context observation without enlarging the primary CKO/SSTAT/
UCNT frame. The preceding same-frame attempt returned valid DMS/SETP reads but
all rows crossed a publication epoch. This iteration reads the minimal
CKO/SSTAT/UCNT group and DMS/SETP context in two separate, independently
guarded WDIAGS frames, and joins a pair only when both frames' published UCNT
values match.

The join means “same published servo update identity observed in two valid
frames”; it does not mean the two groups were simultaneous or prove physical
actuator causality.

## Scope and controls

- Reader-only change; use observer argument `phase_context=2`.
- Primary frame: CKO, SSTAT, UCNT with the existing DATA_VALID/epoch guard.
- Context frame: UCNT, DMS high/low, SETP with its own DATA_VALID/epoch guard.
- Accept a composite row only if both guards pass, all words are valid, and
  the two UCNT values are identical. Never relax either frame guard.
- Global-Time and lock reads remain separate context; do not claim cycle-level
  alignment with the servo payload.
- No firmware/RTL, PI/gain, threshold, timeout, mailbox/control, PPS, FPGA
  image, reset, or power-cycle changes. Do not request snapshots.
- Do not access `/home/b10504072/04_WR_archive_step6_pass/`.

## Procedure and gates

1. Run both offline analyzer/Tcl-format test suites, review the diff, push the
   laptop commit to `feat/file_cleanup`, and fast-forward Pain to that exact
   commit. No build or FPGA programming is needed.
2. Ensure there is no competing Quartus/JTAG reader. Run one 15-second
   Slave-only smoke with requested sleep 1 ms and `phase_context=2`.
3. Smoke passes only with at least 20 rows; all individual reads valid; at
   least 75% rows accepted with both valid frames and matching UCNT; Global
   Time and all five Step 5 locks valid in every row; zero timeout/invalid/reset
   changes or early stop; median row duration below 450 ms.
4. On any failed smoke gate, preserve raw output and stop. Do not run the
   300-second capture and do not alter production controls.
5. Only if smoke passes, run one 300-second read-only capture under a
   900-second hard deadline, retaining the existing reset/five-consecutive
   untrusted-row stop rules. Copy raw evidence back, verify SHA-256, analyze,
   report, push, and stop.

This diagnostic does not itself establish Step 6. It reports the current
expanded offset/Global-Time gate separately and cannot establish physical SMA
edge skew.
