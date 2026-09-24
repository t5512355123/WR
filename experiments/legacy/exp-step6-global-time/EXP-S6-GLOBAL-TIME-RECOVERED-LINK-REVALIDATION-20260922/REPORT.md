# EXP-S6-GLOBAL-TIME-RECOVERED-LINK-REVALIDATION-20260922

## Verdict

```text
GLOBAL_TIME_GATE                         = PASS
MASTER_GLOBAL_TIME_COUNTER              = PASS
SLAVE_GLOBAL_TIME_COUNTER               = FAIL

RESULT                                   = FAIL_SLAVE_GLOBAL_TIME_NOT_VALID_AFTER_LINK_RECOVERY
FAILURE_CLASS                            = FAIL_GLOBAL_TIME_BLOCKED_BY_WR_EXTENSION_PTP_FALLBACK

STEP6A_1                                 = FAIL
STEP6A_GLOBAL_TIME                       = NOT_PASS
MASTER_SLAVE_SAME_PPS                    = NOT_EVALUATED
STEP6B_SCHEDULED_TRIGGER                 = NOT_RUN
```

The recovered link is healthy on both boards, but the Slave still does not
produce a valid WR Global-Time snapshot. This is a Step6A-1 failure, not a
PHY/link failure and not a reason to start Step6B.

## Hardware contract

This experiment was read-only. There was no compile, firmware build,
programming, reset, PTP restart, power cycle, mode command, fiber/QSFP
change, polarity/bitslip change, autonegotiation change, SI5340 change, or
MDIO write.

The current hardware state was preserved:

```text
Master = existing ec1f25e8-source rebuild image
Slave  = existing running image/state
```

Laptop/GitHub source commit for the observer and analysis was `391f0cb6`.
Only files under `scripts/jtag/`, `scripts/analysis/`, `scripts/experiment/`,
`scripts/tests/`, and this experiment directory were changed.

## Phase A — paired link precondition

Five paired samples passed. Every pair had valid transport, both boards
locally ready and link-up, and no reset change:

```text
MASTER_PRECONDITION = 1       5 / 5
SLAVE_PRECONDITION  = 1       5 / 5
MASTER_ACTIVITY_CHANGED       5 / 5
SLAVE_ACTIVITY_CHANGED        5 / 5
MASTER_LINK_HEALTHY            5 / 5
SLAVE_LINK_HEALTHY             5 / 5
RESET_CHANGED                  0
```

The Slave also held:

```text
RX_LOCKED_TO_DATA = 1
RX_PATTERN_READY  = 1
CORE_LINK_OK      = 1
CORE_TM_LINK_UP   = 1
```

Therefore the Global-Time observation phase was valid to evaluate.

## Phase B — Global-Time capture

The paired observer ran for 8181 ms with a nominal 250 ms gap and collected
14 samples per board. All 28 board records were valid, stable, link-healthy,
and reset-stable:

```text
READ_VALID       = 28 / 28
STABLE           = 28 / 28
LINK_HEALTHY     = 28 / 28
RESET_CHANGED    = 0
CAPTURE_RESULT   = PASS_CAPTURE
```

### Master

The Master passed all local Global-Time criteria:

```text
TIME_VALID samples            = 14 / 14
PPS_VALID samples             = 14 / 14
SNAPSHOT_VALID samples        = 14 / 14
SNAPSHOT_COUNT                = 2922 -> 2929
SNAPSHOT_COUNT advances       = 7
SNAPSHOT cycles               = 123289344 (valid)
LIVE counter samples          = 14
LIVE non-monotonic steps      = 0
MASTER_GLOBAL_TIME_COUNTER   = PASS
```

### Slave

The Slave remained link-up and physically active, but its WR Global-Time
validity never became true:

```text
TIME_VALID samples            = 0 / 14
SNAPSHOT_TIME_VALID            = 0 / 14
SNAPSHOT_VALID                 = 0 / 14
SNAPSHOT_COUNT                 = 0 throughout
RX_LOCKED_TO_DATA              = 1 throughout
RX_PATTERN_READY               = 1 throughout
CORE_LINK_OK                   = 1 throughout
CORE_TM_LINK_UP                = 1 throughout
```

The Slave live cycle field changed, but it is not valid Global-Time evidence
without `time_valid` and a valid PPS snapshot. It was therefore not used to
claim a Slave counter pass.

## PTP metadata attribution

The Slave `PTP_META` was consistently:

```text
PTP_META = 0x03020409
PTP_STATE = 9
PD_STATE  = 4 (FAILURE)
EXT_STATE = 2 (PTP)
WRC_MODE  = 3 (SLAVE)
```

This is the requested attribution for:

```text
FAIL_GLOBAL_TIME_BLOCKED_BY_WR_EXTENSION_PTP_FALLBACK
```

The evidence boundary is therefore:

```text
PHY/link recovered
        ↓
Endpoint link is UP
        ↓
WR extension did not establish valid Slave Global Time
        ↓
Slave remains in PTP fallback/failure state
        ↓
time_valid and PPS snapshot remain unavailable
```

## Interpretation and next boundary

This experiment proves that the prior link-recovery postmortem was not
enough to make Step6A pass. The failure is now localized above the PHY/link
gate, at WR-extension/handshake state on the Slave. Same-PPS Master/Slave
comparison is not meaningful until the Slave first produces valid snapshots.

No Step6B trigger work was started. The next experiment must be selected by
the Global-Time adviser; no programming or reset was attempted as a
post-run remedy.

## Artifacts

```text
PLAN.md
raw/observe/revalidation.log
raw/protocol.txt
raw/program/stop.txt
analysis/summary.json
analysis/analyzer.txt
```
