# EXP-S6-WR-EXTENSION-FALLBACK-TERMINAL-LIVENESS-20260922

## Purpose

Determine whether the Slave's WR extension remains permanently in the known
fallback state after the recovered link is healthy, and whether the underlying
SoftPLL is already ready while the extension is disabled. This is a Step6A
diagnostic only; it is not a Global-Time pass and it does not start Step6B.

## Hardware contract

The currently programmed images and runtime state are preserved. This run does
not compile, build firmware, program, reset, restart PTP, issue a mode command,
power-cycle, change fiber/QSFP, change polarity/bitslip, change autonegotiation,
change SI5340, or write MDIO.

Only read-only observers, offline analysis/tests, and this report are changed.

## Gate

Take five paired read-only samples. The Master must remain local-ready/link-up
with stable generation/reset/config counters. The Slave must retain:

```text
CORE_LINK_OK=1
CORE_TM_LINK_UP=1
RX_LOCKED_TO_DATA=1
RX_PATTERN_READY=1
RX activity changing
PTP_STATE=9
PD_STATE=4
EXT_STATE=2
WRC_MODE=3
TIME_VALID=0
```

Any transport error, reset/config change, or failed fallback precondition stops
the run as `INCONCLUSIVE_FALLBACK_PRECONDITION_CHANGED`.

## Capture

After a passing gate, capture both boards for at most 15 seconds at a nominal
350 ms cadence. Preserve the raw diagnostic shadows for WR state/failure,
WR-disable metadata, lock result/counters, S_LOCK trace, SoftPLL state,
PSTAT, PTP counters, link/status, activity, and reset/generation counters.

Stop immediately if the Slave autonomously re-enters WR (`WR_STATE != WRS_IDLE`,
`EXT_STATE != 2`, WR lock poll/enable or S_LOCK trace sequence increases, or
`TIME_VALID` becomes 1). Also stop as inconclusive on link/pattern loss,
counter decrease, invalid transport, or reset/generation/config change.

## Verdicts

If the complete window remains in `WRS_IDLE/PTP_STATE=9/PD_STATE=4/EXT_STATE=2`
with stable WR lock poll/enable and S_LOCK sequence counters and
`TIME_VALID=0`, classify the fallback liveness as terminal. Then classify the
SoftPLL tail separately:

- `PASS_TERMINAL_WR_FALLBACK_WITH_PLL_READY` requires at least five consecutive
  Slave samples with `SPLL_SEQ_STATE=SEQ_READY`, `PSTAT_LOCKED=1`,
  `MAIN_ENABLED=1`, `MAIN_FREQ_LOCKED=1`, `MAIN_PHASE_LOCKED=1`, and
  `MAIN_LOCKED=1`.
- Otherwise classify
  `PASS_TERMINAL_WR_FALLBACK_WITH_PLL_NOT_READY`.
- Both outcomes keep `STEP6A=NOT_PASS` and `STEP6B=NOT_RUN`.
