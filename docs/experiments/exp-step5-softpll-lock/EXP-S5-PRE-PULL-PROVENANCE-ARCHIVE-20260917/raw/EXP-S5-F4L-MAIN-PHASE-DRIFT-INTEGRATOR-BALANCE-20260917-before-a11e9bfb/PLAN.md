# EXP-S5-F4L-MAIN-PHASE-DRIFT-INTEGRATOR-BALANCE-20260917

## Purpose

Use one passive, read-only F4L capture to explain why Main phase acquisition
does not remain converged. This is a diagnostic experiment, not a Step5 pass
claim and not a gain sweep.

The four QSFP cables are already connected, so this run uses the validated
original JTAG runtime-diag Master/Slave images and the existing physical path.
The earlier QSFP-B startup-gate result is retained as a separate experiment;
it is not mixed into this causal capture.

## Frozen functional state

- Main/Slave Kp = 300; Ki = 1; boost = 20.
- Helper Kp = -2250; Ki = -2.
- Guard = 8 s; Slave bootstrap = 3388; Master bootstrap disabled.
- PI, gain schedule, threshold, lock samples, anti-windup, DAC order, timeout,
  bootstrap, arbiter, mailbox, PHY, reset, RTL, and SDB are unchanged.
- F4L is Main `dac_index=0` producer-side observability only.
- One reader, no control write, no Helper PI snapshot, no debug FIFO drain.

## F4L evidence collected

- 16-bin signed phase-error histogram.
- Signed frequency-error count/sum/min/max while on the phase branch.
- Same-generation, same-source, consecutive-update phase deltas with modulo
  16384 shortest-distance handling and explicit gap/ambiguity breaks.
- Actual integrator before/new/after, Ki proposal, clamp side, anti-windup,
  and mismatch counts.
- Versioned companion pages with publication/source coherence checks.

## Offline checks

Run the existing F4L analyzer/tests before pushing. The analyzer may classify
the diagnostic as complete, but it must always report `step5_pass=false` until
the independent Step5 sustained-lock criteria are met.

## Hardware procedure

1. Laptop: run offline tests, commit only this plan, the observer contract
   change, and the Pain build/program helpers; push the exact commit.
2. Pain: pull that exact commit, build the original JTAG Master/Slave images,
   record manifests, program Slave on `DE5 [1-11.2]` and Master on
   `DE5 [1-11.1]`.
3. Pain: run the existing F4L Tcl observer as one session. It performs a
   10-second smoke gate and then targets 120 seconds, with a 130-second hard
   ceiling and a 10-second no-valid-frame stop condition.
4. Copy raw logs and manifests back to Laptop; run the offline analyzer.
5. Write `REPORT.md`, push the report, and stop. Do not auto-adjust gains or
   launch a second control experiment from this capture.

## Expected verdicts

- `DIAGNOSTIC_COMPLETE` is useful evidence but is not `STEP5_PASS`.
- `INCONCLUSIVE` is the correct result for invalid/stale/incomplete pages.
- A reset, generation change, schema mismatch, reader conflict, or transport
  failure is recorded as the stop reason and invalidates causal claims.
