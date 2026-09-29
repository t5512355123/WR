# EXP-S6-WDIAGS-HIGH-RATE-SERVO-20260930

## Objective

Increase the observation density of the Slave servo offset trace after the
per-row WDIAGS epoch guard passed its smoke and 300-second read-only capture.
The previous 500 ms requested delay produced a 696 ms median row interval,
which observed only about 1.4 samples per second despite a 100 ms WDIAGS
publication cadence.

## Single experiment variable

- Keep the reader and all register/probe reads unchanged at baseline
  `2268c76b`.
- Change only the observer's requested sleep from 500 ms to 1 ms. Wishbone
  transaction and row processing time will determine the actual rate; do not
  describe this as a 1 kHz capture.
- This is read-only. No firmware/RTL, PI/gain, threshold, timeout, timing,
  PPS, mailbox, target, FPGA image, reset, or power-cycle changes.
- Do not access `/home/b10504072/04_WR_archive_step6_pass/`.

## Procedure and gates

1. Laptop/GitHub/Pain must be on the exact experiment source revision. No FPGA
   build or programming is needed because only the host-side observer cadence
   and analyzer are involved.
2. Run a 15-second Slave smoke with `SAMPLE_MS=1`. Require at least 20 rows,
   all individual reads valid, at least 75% valid WDIAGS frames, no Wishbone
   timeouts/invalid counters, no reset change, and median row duration below
   250 ms. Stop if any condition fails.
3. Only if smoke passes, run one 300-second read-only capture with the same
   cadence, 900-second hard deadline, one JTAG session, and the existing
   reset/five-invalid-row stop rules.
4. Analyze actual row spacing, frame-validity, Global Time, all five Slave
   Step 5 locks, CKO range, and the fraction of rows with `abs(CKO) < 60 ps`.
   A Step 6 expanded PASS still requires every accepted row to satisfy the
   complete gate; higher sampling density alone is not a pass.
5. This Slave-only run does not establish Master/Slave Global-Time agreement
   or dual-board trigger skew. Keep those Step 6A/6B requirements explicit.

## Analyzer correctness

The analyzer estimates expected row count from observed sample spacing rather
than requested sleep, because reader execution time dominates when
`SAMPLE_MS=1`. It also checks the last-row-to-capture-end tail against the
maximum gap so a capture with a long unsampled ending cannot pass.
