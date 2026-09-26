# EXP-S6-GLOBAL-TIME-RECOVERED-LINK-REVALIDATION-20260922

## Purpose

Revalidate Step6A-1 Global-Time observability in the current Master/Slave
session after the separately proven link reacquisition. This experiment does
not test same-PPS cross-board agreement and does not implement or test the
Step6B scheduled trigger.

## Hardware contract

The current hardware state is preserved:

```text
Master = current ec1f25e8-source rebuild image
Slave  = current running image/state
```

No compile, firmware build, programming, power cycle, PHY reset, PTP
restart, mode command, fiber/QSFP change, polarity/bitslip change,
autonegotiation change, SI5340 change, or MDIO write is allowed.

Only observer scripts, offline analysis, tests, and this experiment's
documentation may change. No VHDL, QSF, SDC, MIF, vendor core, or firmware
control source is modified.

## Phase A — paired link precondition

Collect five paired read-only samples. Both boards must remain locally ready,
link-up, and reset-stable. The Slave additionally requires
`RX_LOCKED_TO_DATA=1`, `RX_PATTERN_READY=1`, and changing RX activity.

Failure stops the run as `INCONCLUSIVE_LINK_PRECONDITION`; no Global-Time
verdict is made and no recovery action is attempted.

## Phase B — Global-Time observation

After the gate passes, collect paired read-only samples for a wall-clock
window of 8 seconds with a nominal 250 ms gap. Each board records status,
probe 62/63 PPS snapshot, probe 64 live time, `PTP_STATE`, `PTP_META`, and
reset/generation/configuration counters.

For each board, Step6A-1 local PASS requires:

1. Five consecutive valid samples with `time_valid=1`.
2. Valid `pps_valid` and `snapshot_valid`, with `SNAPSHOT_COUNT` increasing
   by at least two during the window.
3. Reconstructed snapshot cycles in `0..124999999`.
4. Live `TAI-low * 125000000 + cycles` strictly increasing.

If both boards pass, record `STEP6A_1=PASS` and
`STEP6A_GLOBAL_TIME=PARTIAL_PASS_STEP6A1`; same-PPS comparison remains
`NOT_EVALUATED` and Step6B remains `NOT_RUN`.

## Stop conditions

`FAIL_SLAVE_GLOBAL_TIME_NOT_VALID_AFTER_LINK_RECOVERY` is used when the
Slave remains link-up but does not produce valid time/snapshot evidence for
the whole window. If its metadata is `PTP_STATE=9`, `PD_STATE=4`,
`EXT_STATE=2`, `WRC_MODE=3`, add
`FAIL_GLOBAL_TIME_BLOCKED_BY_WR_EXTENSION_PTP_FALLBACK`.

Stale snapshots, non-monotonic live time, link/reset/generation/configuration
changes, transport errors, or impossible decoded fields stop immediately as
the appropriate FAIL or `INCONCLUSIVE_RUNTIME_STATE_CHANGED`. No retry by
programming or reset is allowed in this experiment.
