# EXP-S5-MAIN-PHASE-KI0-DIRECT-GATE-20260919

## Purpose

Follow the advisor-approved next boundary after Helper acquisition passed: perform exactly one read-only `read_wb_runtime.tcl --raw` in the same freshly programmed Main-phase-Ki=0 session to determine whether the SoftPLL sequence started Main.

## Fixed scope

- Keep the existing Ki=0 session.
- Do not reprogram either board.
- Do not run F4L in this experiment.
- Do not change any control parameter, firmware, RTL, threshold, timeout, or gain.
- Stop immediately after the one direct runtime read.

## Command

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
```

## Entry gate requested by advisor

The intended complete gate is: link/PHY healthy, Helper locked with count 1000, Main enabled, all reset/generation/SI-drop deltas zero, and `WR_FAILURE_REASON=0`. Main frequency/phase lock are status outputs only in this read and are not required for entry.
