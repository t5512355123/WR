# EXP-S5-MAIN-FREQ-LOCK-OCCUPANCY-20260919

## Purpose

Determine whether the Main frequency-lock detector remains saturated while a residual frequency error is still large enough to drive phase drift. This is a read-only occupancy trace after the formal Ki=0 result; it does not change the controller.

## Fixed scope

- Keep the existing Ki=0 image and live Pain session.
- Do not reprogram either board.
- Do not run F4L.
- Do not change PI, gain, threshold, timeout, bootstrap, PHY, RTL, or control branches.
- Analyze only Slave `DE5 [1-11.2]`.
- Execute exactly 20 samples with a 500 ms gap.

## Command

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_wb_timeseries_session.tcl 20 500 3
```

## Stop rule

Stop after sample 20 under every outcome. Classify only Main `freq`, `freq_cnt/50`, Helper validity, and the recorded WR delock count. Do not continue to F4L or alter any control parameter from this trace.
