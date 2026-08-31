# EXP-WRPC-STEP5-UPSTREAM-PHY-KNOWN-GOOD-FIBER-SWAP-VALIDATION-600S-20260901

## Status

This is a partial, explicitly non-pass validation record. The physical fiber
change required by branch5 was not independently confirmed, so this run must
not be used to claim that a known-good fiber swap was performed.

```text
BRANCH                         = exp/step5-softpll-lock
SOURCE_BASELINE                = 525a4cc33bc761c0c97175ca1bbb21aaf630d2f0
OBSERVABILITY_IMAGE            = c280cec5b9b4990f8f5b6cac94f32b178c771e81
PHYSICAL_CHANGE_CONFIRMED     = NO
KNOWN_GOOD_FIBER_SWAP          = UNVERIFIED
STEP5_COMPLETE                 = NO
MERGE_APPROVED                 = NO
```

The control parameters were not changed:

```text
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

No PI, SoftPLL, DMTD, tracker, FINC/FDEC, reset, or RXERR-gate changes were
made for this observation. No new source build or programming was performed;
the existing read-only PHY attribution image was used.

## Initial live preflight

A one-second read-only quiet preflight completed successfully before the
formal phase:

```text
PTP = SLAVE
core_link_ok = 1
core_tm_link_up = 1
MINIC_RXERR delta = 0
all PHY attribution deltas = 0
all link-drop deltas = 0
```

This only shows a temporarily clean instant; it does not establish a clean
300-second window.

## Phase A: JTAG quiet, 300 seconds

Raw output was saved on pain at:

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-UPSTREAM-PHY-KNOWN-GOOD-FIBER-SWAP-VALIDATION-600S-20260901/phase-a-quiet-300s.log
```

Start snapshot:

```text
PTP = 9 (SLAVE)
core_link_ok = 1
core_tm_link_up = 1
MINIC_RXERR = 0x000001EF
PHY_RX_ENC_ERR_COUNT = 0x00000019
PHY_RX_DISPERR_COUNT = 0x00000008
PHY_RX_ERRDETECT_COUNT = 0x00000019
PHY_RX_SYNC_LOSS_COUNT = 0x00000017
PHY_RX_LOCK_TO_DATA_LOSS = 0x00000004
CORE_LINK_OK_DROP_COUNT = 0x00000003
CORE_TM_LINK_UP_DROP_COUNT = 0x00000003
```

End snapshot and deltas:

```text
PTP = 8 (UNCALIBRATED)
core_link_ok = 1
core_tm_link_up = 1
MINIC_RXERR delta = +88
PHY_RX_ENC_ERR_COUNT delta = +7
PHY_RX_DISPERR_COUNT delta = +0
PHY_RX_ERRDETECT_COUNT delta = +7
PHY_RX_SYNC_LOSS_COUNT delta = +1
PHY_RX_LOCK_TO_DATA_LOSS delta = +0
CORE_LINK_OK_DROP_COUNT delta = +0
CORE_TM_LINK_UP_DROP_COUNT delta = +0
```

The read-only Quartus SignalTap script completed successfully with zero
errors and zero warnings. The nonzero MiniNIC RX error and PHY-side event
deltas show that the link was not clean for this 300-second window.

## Phase B

Phase B was not started. The formal Phase A ended in `PTP=UNCALIBRATED`, and
the required physical change was not confirmed. Starting a dashboard-load
phase under those conditions would not be the branch5-defined known-good-fiber
validation.

## Formal result

```text
MINIC_RX_ERROR_INCREMENT          = CONFIRMED (+88)
PHY_SIDE_ERROR_ACTIVITY           = CONFIRMED
PTP_STABILITY                     = FAIL (SLAVE -> UNCALIBRATED)
KNOWN_GOOD_FIBER_SWAP             = UNVERIFIED
RXERR_UPSTREAM_PRECONDITION       = NOT_PASS
STEP4B_COMPLETE                   = YES (previous valid milestone)
STEP4B_REVALIDATED_BY_THIS_RUN    = NO
STEP5_COMPLETE                    = NO
MERGE_APPROVED                    = NO
```

## Required next action

Confirm that the Master-to-Slave optical fiber was physically replaced with a
same-specification known-good fiber. If it was not replaced, replace only that
fiber and rerun the branch5 300-second quiet plus 300-second dashboard
validation. If it was replaced and this run used that fiber, classify the
fiber swap as no effect and move to the next single-variable SFP/transceiver
isolation. Do not change PI parameters, relax the RXERR gate, or merge to
`main`.
