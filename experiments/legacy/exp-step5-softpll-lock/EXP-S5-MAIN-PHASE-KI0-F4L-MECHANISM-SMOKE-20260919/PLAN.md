# EXP-S5-MAIN-PHASE-KI0-F4L-MECHANISM-SMOKE-20260919

## Purpose

Run the advisor-approved first causal smoke for the already programmed Main phase-`Ki=0` image. The smoke is limited to 10 seconds and must stop before any formal 120-second capture.

## Fixed scope

- Keep the same Pain session and image.
- Do not reprogram.
- Do not change any control parameter.
- Use one F4L reader only.
- Stop at 10 seconds or at any fresh runtime regression.

## Command

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 10000 30000 f4l
```

## Required checks

1. Obtain valid page 1 with phase updates.
2. Verify phase integrator and phase `Ki*x` accumulation remain zero while frequency actual and frequency proposal agree.
3. Check residual frequency/phase-drift direction against the frozen baseline.
4. Stop before any 120-second formal capture.
