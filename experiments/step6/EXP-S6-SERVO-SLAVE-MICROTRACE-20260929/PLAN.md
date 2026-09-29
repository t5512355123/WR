# EXP-S6-SERVO-SLAVE-MICROTRACE-20260929

## Objective

Use a compact, Slave-only, read-only JTAG microtrace to determine whether the
strict `abs(CKO) < 60 ps` window or `TRACK_PHASE` state occurs between the
roughly 73 ms rows of the preceding 400-row capture. Each row reads only the
diagnostic command-stage word, `SSTAT`, and `CKO` twice, bracketing the state
and offset with command-stage framing.

## Frozen baseline and scope

- Branch: `feat/file_cleanup`.
- Starting synchronized commit: `0e2787ac1c92d6c2d5eb590104cb3f8a3b5c79c1`.
- Use the already-running validated Step 6 images and Slave session.
- Master SOF SHA-256: `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`.
- Slave SOF SHA-256: `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`.
- No compile, program, reset, power-cycle, or production-source changes.
- No servo threshold, PI/gain, PPS, timing, or clock-setting changes.
- Never access `/home/b10504072/04_WR_archive_step6_pass/`.
- No adviser contact or wait.

## Read-only contract

The observer selects exactly `DE5 [1-11.2]`; it errors unless that unique
Slave cable is present. It uses the existing diagnostic source-probe mailbox
only to request reads. Per attempt it reads, in order:

1. `0x00100A04` command-stage begin,
2. `0x00100A08` SSTAT begin,
3. `0x00100A40` signed CKO begin,
4. `0x00100A40` signed CKO end,
5. `0x00100A08` SSTAT end,
6. `0x00100A04` command-stage end.

Accept a row only when the mailbox framing word is valid and unchanged at both
ends, SSTAT's WR-state-valid bit is asserted at both ends, and all six
mailbox reads decode without the known `0xA5A5xxxx` error marker. Preserve
rejected attempts and retry at most twice. Stop after five consecutive
unaccepted samples. Do not write a Wishbone target, ARM/control register,
setting, PPS register, or snapshot request.

## Execution and stop rules

1. On Pain, require the pushed experiment commit and a clean checkout. Verify
   both intended JTAG cables, no competing Quartus/JTAG observer or programmer,
   and a fresh one-shot dashboard showing the Slave link, global time, and all
   five Step 5 lock bits. Preserve preflight logs.
2. Run the 20-row smoke. Continue only if the exact Slave cable was selected,
   at least 19/20 rows are accepted, all accepted rows have valid SSTAT at both
   boundaries, no reader/JTAG errors occur, and median internal row duration
   is at most 50 ms. Otherwise save the smoke and stop without the long run.
3. If smoke passes, run one bounded 300-second capture with two retries and a
   900-second process deadline. No other JTAG session may run concurrently.
4. Stop immediately on identity loss, five consecutive invalid samples,
   JTAG/mailbox failure, link/reset change, or hard deadline. Preserve partial
   evidence and mark `INCONCLUSIVE`; do not automatically retry by resetting
   or reprogramming.
5. Run a one-shot dashboard after capture, transfer raw logs, verify checksums,
   analyze, report, and push. Keep the Step 6 gate unearned unless it separately
   meets its full acceptance window; a microtrace alone is diagnostic only.

## Interpretation limits

The SSTAT/CKO reads are bounded by the command-stage word but are not an atomic
snapshot. A boundary change proves only that a transition was bracketed during
the row. CKO values at either end are not simultaneous with SSTAT. A 300-second
capture with no in-range boundary still cannot exclude a sub-row transient.
The host's line-arrival cadence is not the sampling cadence; use the internal
`elapsed_us` measurement for each six-read row.
