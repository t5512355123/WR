# EXP-S5-MAIN-FREQ-THRESH20-F4L-DIAGNOSTIC-GATE-20260920

## Objective

Preserve the complete threshold20 production-control candidate while changing
only the compile-time diagnostic owner from F4J to F4L on both Master and
Slave.  Re-establish a fresh, valid operating gate before the formal threshold20
F4L phase-domain comparison.

## Allowed source difference

```text
DE5A_F4L_MAIN_PHASE_DIAG: 0 -> 1
Master identity: 1
Slave identity:  1
```

The following remain frozen:

```text
Slave Main frequency threshold = 20
Master Main frequency threshold = 50
Main Kp = 300
frequency Ki = 1
phase Ki = 0
frequency boost = 20
frequency lock samples = 50
delock floor = unchanged
phase threshold/samples = 1200/1000
bumpless preload = ON
Helper, timeout, PHY, RTL, SDB = unchanged
```

## Sequence

```text
laptop source/test/plan change and push
-> Pain pull
-> clean build
-> program both boards
-> one read_wb_runtime.tcl --raw
-> STOP
```

Do not run formal 120-second F4L in this round.

## Required direct gate

```text
Master spll_main_limits = 00320032
Slave  spll_main_limits = 00320014
DE5A_F4L_MAIN_PHASE_DIAG = 1 on both identities
```

Runtime must also show Helper locked, Main enabled, PHY link usable, PSTAT link
valid, and stable generation/reset/SI-drop/RXERR fields.  If the threshold or
diagnostic owner is wrong, classify implementation as failed and stop.  If the
fresh image is healthy, classify the gate as pass and stop; the next round may
run the formal threshold20 F4L comparison.

