# EXP-S5-F4J-HELPER-ACQUISITION-CORRELATION-20260920

## Purpose

After the F4J fresh-image gate stopped at `SEQ_WAIT_HELPER`, perform the advisor-requested bounded, read-only Helper acquisition diagnosis. The goal is to distinguish Helper non-convergence from an inactive or failed DCO service path without changing the F4J image or any production control.

## Fixed session and command

The existing freshly programmed F4J image from `EXP-S5-F4J-MAIN-FREQ-ACCEPTANCE-AUDIT-20260919` was kept running. No reprogramming, firmware edit, build, parameter change, F4L run, direct gate, or F4J run was performed before this capture.

Exactly one command was run:

```text
quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 20 500
```

This fixed the window at 20 samples with a 500 ms gap. Sample 20 was the hard stop, regardless of the result.

## Evidence required

For the Slave, inspect `HELPER_ERROR`, `HELPER_STATE`, `HELPER_UPDATE_COUNT`, `STEP_DELTA`, `STEP_EVENT`, `BUSY`, `ERROR`, `LOCK_ENABLE`, and `SPLL_STATE`. The Master is retained as a non-target reference only.

## Stop rule

Do not run a follow-up direct gate or F4J automatically. If Helper acquires and holds, classify that result and wait for the next advisor instruction. If it remains out of band, classify non-convergence. Only a long-zero `STEP_DELTA` with changing demand/output or a nonzero DCO error would support a DCO-service regression classification.

## Actual outcome

The Slave Helper was locked in all 20 samples with count 1000, signed error from -162 to +188 (well inside the ±2000 threshold), and no DCO error. The DCO step event occurred in 19/20 samples after the first baseline sample, with nonzero step deltas 575–586. This is `HELPER_ACQUISITION=PASS` and `HELPER_LOCK_ACQUIRED_AND_HELD=YES`; the F4J acceptance audit remains not run.
