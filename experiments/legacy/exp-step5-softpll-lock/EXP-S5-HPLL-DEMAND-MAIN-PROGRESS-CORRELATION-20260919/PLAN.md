# EXP-S5-HPLL-DEMAND-MAIN-PROGRESS-CORRELATION-20260919

## Purpose

Correlate the existing Slave Helper measurement with DCO step activity in
the already-running QSFP-A lane-0 session. The experiment is diagnostic only;
it is not a Step5 lock attempt.

## Frozen controls

- No FPGA programming or power cycle.
- No production source, RTL, PI gain, threshold, timeout, bootstrap,
  arbiter, mailbox, PHY, reset, DAC, FINC, or FDEC change.
- No WDIAGS configuration write and no second observer competing for the
  diagnostic bank.
- Read-only observer:
  `scripts/jtag/read_hpll_helper_correlation.tcl 60 500`.

## Procedure

1. Keep the recovered QSFP-A lane-0 hardware session alive.
2. Run the existing observer for 60 samples at a 500 ms interval.
3. Save the complete raw output and stop after that capture.
4. Classify Helper demand, DCO activity, residual frequency proxy, and
   transaction status without declaring Step5.

## Entry/stop criteria

The capture is valid only if the script completes and the raw sample count
and board names are complete. Stop after this one capture regardless of the
result. A subsequent experiment must not be selected from this report without
reviewing the DCO transaction boundary evidence.
