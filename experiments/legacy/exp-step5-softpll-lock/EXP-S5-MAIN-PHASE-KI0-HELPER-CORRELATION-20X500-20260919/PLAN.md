# EXP-S5-MAIN-PHASE-KI0-HELPER-CORRELATION-20X500-20260919

## Purpose

Follow-up to `EXP-S5-MAIN-PHASE-KI0-MECHANISM-20260919`. The direct runtime gate had shown WR link up but Helper unlocked and Main disabled. The advisor-required next action was a single read-only Helper/DCO continuity trace in the same freshly programmed session.

## Fixed scope

- Keep the existing `Main phase Ki=0` image and live session.
- Do not reprogram either board.
- Do not run F4L.
- Do not change PI, gain, threshold, timeout, bootstrap, PHY, RTL, or control branches.
- Execute exactly 20 samples with a 500 ms gap.

## Command

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 20 500
```

## Stop rule

Stop after sample 20 under every outcome. Classify Helper lock continuity, Helper error trajectory, DCO step progress, and DCO error only. A Ki=0 or Step5 conclusion requires a later direct runtime confirmation and F4L smoke.
