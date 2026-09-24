# EXP-WRPC-STEP5-UPSTREAM-QSFPA-LANE2-PHY-VALIDATION-600S-20260901

Date: 2026-09-01 (Asia/Taipei)  
Branch: `exp/step5-softpll-lock`  
Commit: `4eeb128`  
Experiment status: `LANE2_LINK_AND_PHY_ATTRIBUTION_PASS; STEP5_LOCK_PENDING`

## Purpose

Run branch5's prescribed upstream lane-2 experiment after the QSFP-A lane-1
link gate failed. The experiment first validates the lane-2 compile and link,
then checks the Slave PHY/MiniNIC error source under a 300-second quiet window
and a 300-second normal dashboard-observation window.

## Scope and unchanged controls

The only functional experiment change was routing the WR transceiver data path
from QSFP-A lane 1 to lane 2 on both Master and Slave:

```text
pad_txp_o => QSFPA_TX_p(2)
pad_rxp_i => QSFPA_RX_p(2)
RX pin = PIN_BA3
TX pin = PIN_BB1
```

Lane 2 received the existing HSSI differential I/O, 100-ohm termination, and
pre-emphasis assignment. Lane 1 and unused lane 3 pre-emphasis assignments
were removed so the inactive channels did not affect fitting. The following
controls were unchanged:

```text
bootstrap=6176
code_per_physical_step=64
kp=-150
ki=-1
threshold=200
lock_samples=10000
```

No PI equation, SoftPLL FSM, DMTD, tracker, FINC/FDEC, manual DCO, reset tree,
or Step 2 RXERR gate was changed.

## Compile and program

Both projects completed full compilation and fitting successfully with
Quartus 17.0:

| Image | Result | SOF SHA-256 | Worst setup slack |
|---|---|---|---:|
| Master | Full compilation successful | `695e2d2aeb2cd583560f31bd946494d02a41e79c020a300a7d821e683492b5c8` | `-0.050 ns` |
| Slave | Full compilation successful | `2896255cc2ad76f78643a543d90ae400b9958363baaaa0c68b792e7145431a33` | `-0.211 ns` |

`TIMING_CLOSED=NO` remains an implementation caveat, not a lane-gate failure.
Both images were programmed successfully:

```text
DE5 [1-11.1] Master: 0 errors, 0 warnings
DE5 [1-11.2] Slave:  0 errors, 0 warnings
```

## Link gate

The lane-2 link gate passed on both boards:

```text
Master: core_tm_link_up=1, core_link_ok=1, wr_rx_ready=1,
        wr_tx_ready=1, wr_rx_enc_err=0, PTP=MASTER
Slave:  core_tm_link_up=1, core_link_ok=1, wr_rx_ready=1,
        wr_tx_ready=1, wr_rx_enc_err=0, PTP=SLAVE after recovery
```

Immediately after programming, the Slave was temporarily
`PTP=UNCALIBRATED`, so the first attribution precondition check was correctly
rejected before timing began. A later read-only preflight recovered to:

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

The same preflight observed the expected Slave startup chain:

```text
LOCK_ENABLE_COUNT = 4
SPLL_MODE = 3 (SPLL_MODE_SLAVE)
SPLL_SEQ_STATE = 4 (SEQ_WAIT_HELPER)
SPLL_STATE_VISIT_MASK = 0x00000618
SPLL_INIT_COUNT = 1
RCER = 0x00000001
OCER = 0xCA7FE001
```

## Phase A: quiet 300 seconds

The formal phase started only after `PTP=SLAVE`, `core_link_ok=1`, and
`core_tm_link_up=1` were all true. It completed successfully:

```text
rxerr_delta=0
phy_enc_delta=0
phy_disperr_delta=0
phy_errdetect_delta=0
phy_sync_loss_delta=0
phy_lock_loss_delta=0
core_link_drop_delta=0
core_tm_link_drop_delta=0
PTP=SLAVE at both endpoints
ATTRIBUTION_COMPLETE=YES
```

## Phase B: dashboard load 300 seconds

The normal five-second read-only dashboard cadence also completed successfully:

```text
rxerr_delta=0
phy_enc_delta=0
phy_disperr_delta=0
phy_errdetect_delta=0
phy_sync_loss_delta=0
phy_lock_loss_delta=0
core_link_drop_delta=0
core_tm_link_drop_delta=0
PTP=SLAVE at both endpoints
ATTRIBUTION_COMPLETE=YES
```

The dashboard observation load therefore did not reproduce the earlier lane-1
RXERR/PHY failure. No evidence supports a lane-2 PHY error increment or a
dashboard-induced perturbation in these two windows.

## Formal result

```text
LANE2_COMPILE_VALID              = YES
LANE2_LINK_AVAILABLE             = YES
QSFPA_LANE2_PHY_VALIDATION       = PASS
RXERR_UPSTREAM_PRECONDITION      = PASS (after PTP recovery)
STEP1_REGRESSION                 = PASS
STEP2_REGRESSION                 = PASS
STEP3_REGRESSION                 = PASS
STEP4B_COMPLETE                  = YES
STEP4B_REVALIDATED_BY_THIS_RUN  = YES
STEP5_COMPLETE                   = NO
STEP5_RESULT                    = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY   = HELPER_LOCK
MERGE_APPROVED                  = NO
```

## Conclusion and handoff

The earlier `Step 1 PHY / Link error` was the lane-1 result. With lane 2,
Step 1, Step 2, Step 3, and Step 4B are now passing, and the two 300-second
attribution windows are clean. The remaining failure boundary is the actual
Step 5 closed-loop helper lock (`PSTAT.locked=0`), not the upstream PHY/link
gate.

This report does not claim Step 5 completion and does not authorize a merge.
The next Step 5 experiment must be selected by branch5; lane 3 and controller
parameter changes are not selected automatically.

Raw logs on pain:

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-STEP5-UPSTREAM-QSFPA-LANE2-PHY-VALIDATION-600S-20260901/
```
