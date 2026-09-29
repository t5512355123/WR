# EXP-S6-SERVO-OFFSET-UPDATE-CORRELATION-20260929

## Objective

Determine whether the observed Slave CKO jumps and servo-state transitions
coincide with a WR servo update (`UCNT`), phase-setpoint change (`SETP`), or
corrected master-slave delay change (`DMS`). This is a read-only observation;
it does not adjust the controller.

## Frozen scope

- Branch: `feat/file_cleanup`.
- Baseline: synchronized commit `4b0d0020225e77536dcd9609a4e9b04c87c6812b`.
- Use the same running Step 6 images and Slave session; do not compile,
  program, reset, power-cycle, or change controller/timing settings.
- No production C/RTL, PI/gain, threshold, PPS, clock, QSF, or SDC changes.
- Never access `/home/b10504072/04_WR_archive_step6_pass/`.
- No adviser contact or wait.

## Source-audited register read set

Each row brackets the state/offset, update counter, phase setpoint, and
64-bit DMS high/low words with the diagnostic command-stage word:

1. `0x00100A04` command stage begin
2. `0x00100A48` WDIAG_UCNT begin
3. `0x00100A34` / `0x00100A38` WDIAG_DMS MSB/LSB begin
4. `0x00100A44` WDIAG_SETP begin
5. `0x00100A08` WDIAG_SSTAT begin
6. `0x00100A40` WDIAG_CKO begin/end
7. WDIAG_SSTAT end
8. WDIAG_SETP end
9. WDIAG_DMS MSB/LSB end
10. WDIAG_UCNT end
11. command stage end

`task-diags.c` publishes `SETP=cur_setpoint_ps`, `DMS=pp_time_to_picos(delayMS)`,
`CKO=pp_time_to_picos(offsetFromMaster)`, and the PTP servo `update_count`.
The standard servo computes `delayMS=meanDelay+delayAsymmetry` and
`offsetFromMaster=t1-t2+delayMS`. `UCNT` begin/end changes identify an update
within a row; changes between the previous row's end and current row's begin
identify an update between rows. The 64-bit DMS words are sequential, not an
atomic pair; preserve both boundary pairs and use UCNT brackets as context.

The source-probe mailbox writes are read requests only. The reader does not
write a Wishbone target, ARM/control setting, timing parameter, PPS register,
or snapshot request. Accept/retry policy is the same as the prior compact
microtrace: require stable framing and valid SSTAT at both row boundaries;
stop after five consecutive unaccepted rows.

## Execution and stop rules

1. Require the pushed commit and clean Pain checkout. Check the two cables,
   no concurrent Quartus/JTAG observer/programmer, and a fresh one-shot
   dashboard showing Slave Link, Global Time, and all five Step 5 lock signals.
2. Run a 20-row smoke. Continue only if all rows are accepted, no errors occur,
   and median internal row duration is at most 100 ms.
3. Run one 300-second Slave-only capture with a 900-second hard deadline and
   two retries. Do not run another JTAG process concurrently.
4. The reader validates mailbox framing and servo-state validity, but does not
   continuously sample link/reset counters. Stop on five consecutive invalid
   rows, repeated mailbox/JTAG failure, or hard deadline. Preserve partial
   data as `INCONCLUSIVE`; do not reset or reprogram automatically.
5. Run the final one-shot dashboard; transfer and verify raw files; analyze
   register deltas and SSTAT/CKO transitions; write the report and push.

## Interpretation limits

Each field is read sequentially. Even values inside one command-stage frame
are not a same-cycle snapshot. A simultaneous-looking UCNT/SETP/DMS/CKO change
supports correlation only; it is not proof of causality. The capture can
classify whether sampled offset jumps bracket a servo update or diagnostic
change, but it cannot alone establish the continuous 300-second Step 6 gate.
Link/reset validity is established only by the pre/post dashboards and is not
claimed continuously during the correlation capture.
