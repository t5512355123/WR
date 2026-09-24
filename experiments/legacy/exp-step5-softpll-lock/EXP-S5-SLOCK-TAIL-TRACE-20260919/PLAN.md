# EXP-S5-SLOCK-TAIL-TRACE-20260919

## Objective

Use the existing F4M reader once as a read-only S_LOCK tail-bank diagnostic.
The purpose is to distinguish a firmware S_LOCK timeout that already exists
from a new terminal edge allegedly caused by the F4L observer.

This is not an F4M acquisition experiment and is not a Step5 pass attempt.

## Fixed conditions

- Branch: exp/step5-softpll-lock
- Source/report baseline: a81f8edf
- Hardware path: QSFP-A lane0
- Master: DE5 [1-11.1]
- Slave: DE5 [1-11.2]
- Existing programmed image/session retained; no reprogramming
- No firmware, RTL, control-parameter, PI, timeout, bootstrap, or PHY change
- One Slave context only
- One execution only; stop regardless of result

## Command

    quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 1 100 "" 3000 3000 f4m

## Required evidence

Read only STEP5_F4M_FIRST_LOSS_SAMPLE:

- trace_valid
- SLOCK_MAGIC_RAW
- SLOCK_STAGE
- SLOCK_RETRY
- SLOCK_ENTRY_TICS
- SLOCK_REMAINING_MS
- SLOCK_POLL_RET
- SLOCK_WR_STATE
- SLOCK_SEQ
- WR_TERMINAL

## Stop rule

Stop after the single sample. Do not rerun F4L and do not program a new
image in this experiment.
