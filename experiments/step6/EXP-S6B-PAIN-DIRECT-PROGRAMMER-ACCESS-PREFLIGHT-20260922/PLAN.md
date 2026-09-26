# EXP-S6B-PAIN-DIRECT-PROGRAMMER-ACCESS-PREFLIGHT-20260922

## Purpose

Determine whether Pain can enumerate both DE5 JTAG programming cables with a
direct, non-sudo Quartus Programmer command after the previous run stopped at
the wrapper's sudo prompt. This is an infrastructure preflight only. It does
not program either FPGA and does not validate Step6 functionality.

## Fixed contract

```text
COMPILE           = NO
FIRMWARE BUILD    = NO
MASTER PROGRAM    = NO
SLAVE PROGRAM     = NO
FPGA_PROGRAM_COUNT= 0
RESET             = NO
PTP RESTART       = NO
POWER CYCLE       = NO
TARGET/ARM WRITE  = NO
SUDO              = FORBIDDEN
```

Before the read-only command, the runner must verify the exact fitted SOF/MIF
hashes, fitted design source commit, and the prior post-fit timing proof. A
mismatch stops with zero program count.

The only hardware-facing command is:

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm -l
```

The command must return zero and list both `DE5 [1-11.1]` and `DE5 [1-11.2]`.
The log must contain no sudo/password prompt and no configuration/programming
success message. Any such message is an unexpected-action stop.

## Results

The raw command log, provenance record, stop classification, and JSON summary
are written under `raw/` and `analysis/`. A PASS only means direct programmer
access is available; it does not authorize programming in this experiment.
