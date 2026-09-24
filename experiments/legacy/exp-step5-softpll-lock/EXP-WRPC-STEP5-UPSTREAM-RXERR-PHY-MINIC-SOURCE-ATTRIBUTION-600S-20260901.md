# EXP-WRPC-STEP5-UPSTREAM-RXERR-PHY-MINIC-SOURCE-ATTRIBUTION-600S-20260901

Date: 2026-09-01 (Asia/Taipei)
Branch: `exp/step5-softpll-lock`
Instrumentation commit: `c280cec`
Experiment status: `UPSTREAM_PHY_LINK_ERROR_CONFIRMED`

## Purpose

Identify whether the intermittent `WDIAGS_RXERR` gate is caused by the
physical/PHY path, the Endpoint/MiniNIC frame-status path, or JTAG/dashboard
observation load. The control baseline remains the branch5-approved
`bootstrap=6176`, `kp=-150`, `ki=-1`, `threshold=200`, and `lock_samples=10000`.

## Instrumentation and programming

Only read-only attribution instrumentation was added to the Slave JTAG top:

- PHY RX encoding-error event count
- PHY disparity-error event count
- PHY errdetect event count
- PHY sync-loss transition count
- PHY lock-to-data-loss transition count
- WR core-link-ok drop count
- WR core timing-link-up drop count

The counters are saturating diagnostic counters and are not connected to the
WR control, reset tree, SoftPLL, or DAC path. The firmware MIF was unchanged
from the approved `ki=-1` image.

```text
GIT_COMMIT      = c280cec5b9b4990f8f5b6cac94f32b178c771e81
MIF_SHA256      = b47636ba74f1abe3a20c2cfdd29bff4bc0eed635dcd454efddb1e578dc3495ad
SOF_SHA256      = 8e58c5cd33faf03a2cbfde7a05f35180b3a8de988b2be85e8579c37eb763bd02
FULL_COMPILE    = successful
PROGRAM         = PASS (DE5 [1-11.2], 0 errors, 0 warnings)
```

## Preconditions

Before each formal phase the Slave was required to be `PTP=SLAVE`,
`core_link_ok=1`, and `core_tm_link_up=1`. The formal quiet phase began with:

```text
PTP              = 9 SLAVE
core_link_ok     = 1
core_tm_link_up  = 1
```

After Phase A the board temporarily returned to `PPS_UNCALIBRATED` and the
first Phase B attempt stopped before applying load. No data from that aborted
attempt is used as a result. After waiting for recovery, Phase B started with
the required SLAVE/link precondition.

## Phase A: JTAG quiet, 300 seconds

Raw evidence:

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-UPSTREAM-RXERR-PHY-MINIC-SOURCE-ATTRIBUTION-600S-20260901/phase-a-quiet-300s.log`

```text
MINIC_RXERR                 0x00000020 -> 0x0000008F   delta=111
PHY_RX_ENC_ERR_COUNT        0x00000006 -> 0x00000009   delta=3
PHY_RX_DISPERR_COUNT        0x00000008 -> 0x00000008   delta=0
PHY_RX_ERRDETECT_COUNT      0x00000006 -> 0x00000009   delta=3
PHY_RX_SYNC_LOSS_COUNT      0x00000004 -> 0x00000007   delta=3
PHY_RX_LOCK_TO_DATA_LOSS    0x00000004 -> 0x00000004   delta=0
CORE_LINK_OK_DROP_COUNT     0x00000003 -> 0x00000003   delta=0
CORE_TM_LINK_UP_DROP_COUNT  0x00000003 -> 0x00000003   delta=0
PTP                          9 SLAVE -> 9 SLAVE
```

## Phase B: dashboard load, 300 seconds

Raw evidence:

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-UPSTREAM-RXERR-PHY-MINIC-SOURCE-ATTRIBUTION-600S-20260901/phase-b-dashboard-300s-retry.log`

The load consisted only of periodic read-only Wishbone/JTAG accesses at the
normal five-second cadence. It did not write control registers.

```text
MINIC_RXERR                 0x000000C6 -> 0x00000137   delta=113
PHY_RX_ENC_ERR_COUNT        0x00000010 -> 0x00000013   delta=3
PHY_RX_DISPERR_COUNT        0x00000008 -> 0x00000008   delta=0
PHY_RX_ERRDETECT_COUNT      0x00000010 -> 0x00000013   delta=3
PHY_RX_SYNC_LOSS_COUNT      0x00000008 -> 0x00000011   delta=9
PHY_RX_LOCK_TO_DATA_LOSS    0x00000004 -> 0x00000004   delta=0
CORE_LINK_OK_DROP_COUNT     0x00000003 -> 0x00000003   delta=0
CORE_TM_LINK_UP_DROP_COUNT  0x00000003 -> 0x00000003   delta=0
PTP                          9 SLAVE -> 9 SLAVE
```

## Formal classification

Both phases show real MiniNIC RX errors together with nonzero PHY-side
encoding/errdetect/sync-loss events, while neither core link-drop counter
changes. This meets branch5 Case A:

```text
MINIC_RX_ERROR_INCREMENT              = CONFIRMED
RXERR_SOURCE_CLASS                    = PHY_OR_PHYSICAL_LINK
DASHBOARD_DISPLAY_ARTIFACT             = NOT_SUPPORTED
DASHBOARD_OR_WB_PERTURBATION_SUSPECTED = NO
```

The intermittent `PPS_UNCALIBRATED` and the later RXERR increments prevent a
clean Step2/Step4B preflight set, so the atomic Step5 smoke was not run.

```text
STEP4B_COMPLETE                   = YES (previous valid milestone)
STEP4B_REVALIDATED_BY_THIS_RUN   = NO
KI_REDUCTION_DIRECTION_EFFECTIVE  = NOT_ADJUDICATED
STEP5_COMPLETE                    = NO
MERGE_APPROVED                    = NO
```

## Required next action

Pause Step5. Inspect and correct the physical path first: optical fiber,
SFP/transceiver seating and compatibility, and the link partner. Do not change
PI, bootstrap, FINC/FDEC, tracker, or relax the Step2 RXERR gate. After the
physical path is clean, reprogram the same image, obtain three clean
preflight dashboards, then resume the branch5 sequence:

```text
3 clean dashboards
-> atomic snapshot 100-sample smoke
-> smoke PASS
-> ki=-1 1800-second observer
```
