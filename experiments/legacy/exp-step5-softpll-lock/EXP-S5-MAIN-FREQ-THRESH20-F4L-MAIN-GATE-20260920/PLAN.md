# EXP-S5-MAIN-FREQ-THRESH20-F4L-MAIN-GATE-20260920

## Objective

Confirm that the Helper-locked threshold20 + F4L session has reached the Main
runtime gate without changing the image or any control parameter.

## Session preservation

```text
FPGA/source commit        = 00d7572fa4943dbba1e28b2245f884fc04386a94
previous Helper report    = 121d882f
Slave main limits         = 00320014
Master main limits        = 00320032
F4L diagnostic owner      = 1 on Master and Slave
```

Use the same live, already-programmed session. This round is read-only: no
recompile, no reprogram, no reset/power-cycle, no PI/gain/threshold/timeout
change, and no formal F4L capture.

## Allowed action

Run exactly once:

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
```

Capture complete stdout and checksum it. Stop immediately after the command,
regardless of the gate result.

## Slave admission fields

```text
spll_main_limits = 00320014
HELPER_LOCKED = 1
HELPER_LOCK_COUNT = 1000
MAIN_ENABLED = 1
PHY_LINK_USABLE = 1
PSTAT_LINK = 1
RXERR delta = 0
BOOT_GENERATION delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
SI_CONFIG_DROP_COUNT delta = 0
JTAG/WB transport = TRUSTED
```

`MAIN_FREQ_LOCKED` may be 0 or 1 in this gate. If the required fields are
healthy, mark the Main runtime gate PASS and allow a later formal F4L round;
do not run formal in this round. If Helper is unlocked, Main is disabled, or
runtime infrastructure regresses, classify the corresponding failure and stop.
