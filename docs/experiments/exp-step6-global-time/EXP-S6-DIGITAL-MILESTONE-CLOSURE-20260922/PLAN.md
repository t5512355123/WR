# EXP-S6-DIGITAL-MILESTONE-CLOSURE-20260922

## Purpose

Perform the adviser-approved, offline-only closure audit for the Step6 digital
Global-Time milestone.  This experiment consumes existing raw logs, machine
summaries, timing reports, and protocol records.  It does not add a hardware
run or alter the fitted design.

## Allowed changes

Only the offline audit under `scripts/analysis/`, its tests under
`scripts/tests/`, and this experiment's documentation and analysis outputs
may change.

## Forbidden actions

```text
HARDWARE_ACCESS       = NO
COMPILE               = NO
FIRMWARE_BUILD        = NO
PROGRAM               = NO
PTP_RESTART           = NO
CPU/WR/PHY_RESET      = NO
POWER_CYCLE           = NO
TARGET_WRITE          = NO
ARM_WRITE             = NO
SMA/FIBER/QSFP_CHANGE = NO
SI5340/MDIO_CHANGE    = NO
FITTED_DESIGN_CHANGE  = NO
```

## Evidence chain audited

1. `EXP-S6A-ACTIVE-EXTENSION-LATE-GLOBAL-TIME-TAIL-20260922`: Slave
   Global-Time/PPS validity and stable late tail.
2. `EXP-S6-SAME-PPS-GLOBAL-TIME-CONSISTENCY-20260922`: five common PPS
   timestamp labels with zero digital cycle-label delta.
3. `EXP-S6B-TIMING-QUERY-BOUNDARY-CORRECTION-20260922`: all required
   scheduler setup/hold path groups proven for both boards.
4. `EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-LIVE-SESSION-20260922`:
   first scheduled digital trigger.
5. `EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-REARM-REPEATABILITY-20260922`:
   clean second trigger in the same live session.

The earlier `EXP-S6-GLOBAL-TIME-OBSERVABILITY-20260920` Slave failure remains
historical evidence and is not used as a PASS input; the later active-extension
tail is the requalification evidence.

## Formal outcomes

```text
PASS_STEP6_DIGITAL_MILESTONE_CLOSURE
STEP6_DIGITAL_GLOBAL_TIME       = PASS
STEP6_DIGITAL_SAME_PPS          = PASS
STEP6_DIGITAL_SCHEDULED_TRIGGER = PASS
STEP6_DIGITAL_REARM             = PASS
PHYSICAL_PPS_BASELINE           = NOT_EVALUATED
PHYSICAL_SCHEDULED_TRIGGER_EDGE= NOT_EVALUATED
```

If raw evidence is missing, the audit must stop as
`INCONCLUSIVE_STEP6_DIGITAL_MILESTONE_EVIDENCE_INCOMPLETE`.  If a formal
summary contradicts its raw record, it must stop as
`FAIL_STEP6_DIGITAL_MILESTONE_EVIDENCE_CONTRADICTION`.
