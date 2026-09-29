# EXP-S6-WRH-SERVO-PHASE-CONTEXT-20260930

## Objective

Determine whether source-published DMS and phase setpoint (SETP) values change
alongside the servo's CKO offset, UCNT update identity, and WRH servo state.
The preceding 300-second high-rate capture had 1,501 valid rows but only three
`TRACK_PHASE` rows; 90.3% of samples were `WAIT_OFFSET_STABLE`. This experiment
adds phase context to the existing per-row guarded WDIAGS frame so those
signals can be compared without crossing a publication epoch.

This is a diagnostic experiment only. It does not tune or change the servo and
cannot by itself prove physical actuator response or Step 6 acceptance.

## Single variable

- Reuse source-mapped WDIAGS addresses: DMS high/low at `0x00100A34` and
  `0x00100A38`, SETP at `0x00100A44`; CKO/SSTAT/UCNT remain unchanged.
- Add an optional fourth reader argument `phase_context=1`. The default is
  `0`, preserving the existing minimal observer behavior.
- In phase-context mode, read DMS and SETP after CKO/SSTAT/UCNT and before the
  existing DATA_VALID / mapping-epoch end checks. Reject the whole row if
  those reads are invalid or the guarded WDIAGS frame changes.
- Preserve raw DMS words and SETP; the decoded DMS is an unsigned 64-bit
  picosecond value and SETP/CKO are signed picoseconds.
- No production firmware, RTL, PI/gain, thresholds, timeout, mailbox/control,
  PPS, FPGA image, reset, or power-cycle changes. Do not request snapshots.
- Do not access `/home/b10504072/04_WR_archive_step6_pass/`.

## Source and observation boundaries

The address mapping comes from `vendor/wrpc-sw/include/hw/wrc_diags_regs.h`
and its WDIAGS publisher in `vendor/wrpc-sw/lib/task-diags.c`. Servo-state
names and the `WAIT_OFFSET_STABLE`/`TRACK_PHASE` transition conditions are
source-defined in `vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c`.

Each accepted row has stable DATA_VALID and mapping epoch around the WDIAGS
payload. This is a publication-frame guard, not a hardware-atomic snapshot.
Global-Time and Step 5 locks are read separately and are reported as context;
they are not claimed to be cycle-aligned with WDIAGS.

## Procedure and stop conditions

1. Laptop: run Tcl/analyzer unit tests, inspect the source diff, commit and push
   to `feat/file_cleanup`.
2. Pain: fast-forward pull the exact GitHub commit. No build/program is needed.
3. Run a 15-second Slave-only smoke with 1 ms requested sleep and
   `phase_context=1`, in one read-only JTAG session. Do not run concurrently
   with another JTAG observer.
4. Smoke passes only with at least 20 rows; all row reads valid; at least 75%
   valid coherent WDIAGS+phase-context frames; Global Time and all five Step 5
   lock bits valid in every row; zero timeouts/invalid reads/reset changes or
   early stop; and median row duration below 250 ms.
5. If any smoke condition fails, stop immediately, preserve raw output, and do
   not start a long capture. Diagnose the reader only; do not relax the frame
   guard or change production behavior.
6. If smoke passes, run one 300-second capture with the same observer settings,
   a 900-second hard process deadline, and the existing reset/five-consecutive
   untrusted-row stop rules. Save the complete raw log and checksum.
7. Analyze state-grouped CKO/DMS/SETP ranges and adjacent UCNT pairs. Distinguish
   unchanged, one-step, and skipped counter intervals. Correlation is not
   causality; sequential host reads do not prove a physical phase adjustment.
8. Copy raw evidence to Laptop, verify SHA-256, write the report, run tests, and
   push the report. Stop after that report; do not automatically tune or start
   another experiment.

Even a successful smoke or complete diagnostic capture is not a Step 6 PASS.
The current expanded Step 6 requirement remains a separate 300-second
acceptance criterion, including the stated valid Global-Time/lock/offset gate.
