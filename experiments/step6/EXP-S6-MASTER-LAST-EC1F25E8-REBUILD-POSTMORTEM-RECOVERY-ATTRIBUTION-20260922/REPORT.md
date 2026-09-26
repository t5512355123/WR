# EXP-S6-MASTER-LAST-EC1F25E8-REBUILD-POSTMORTEM-RECOVERY-ATTRIBUTION-20260922

## Verdict

```text
POSTMORTEM_RESULT                              = PASS_POSTMORTEM_DROP_AND_REACQUISITION
PREPROGRAM_SLAVE_LINK                          = UP
POSTPROGRAM_LINK_INTERRUPTION                  = OBSERVED_BY_STICKY_COUNTER
CURRENT_STABLE_REACQUISITION                   = PASS
EC1F25E8_SOURCE_REBUILD_MASTER_LAST_RECOVERY   = SUPPORTED_POSTMORTEM
STARTUP_ORDER_SENSITIVITY                      = SUPPORTED
RECOVERY_LATENCY                               = UNAVAILABLE_DUE_TO_ORIGINAL_OBSERVER_FAILURE

S_LOCK                                         = NOT_EVALUATED
STEP6A_GLOBAL_TIME_OBSERVABILITY               = NOT_PASS
STEP6B_GLOBAL_TIME_TRIGGER                     = NOT_RUN
```

The formal postmortem condition is satisfied: a current sticky link-drop
counter increased relative to the pre-program baseline, and there were at
least five consecutive valid paired samples showing stable recovery. This is
not a Step6A global-time pass; it is a recovery-attribution postmortem.

## Fixed hardware state and provenance

This was a read-only follow-up to the prior Master-last rebuild experiment.
There was no compile, firmware build, programming, reset, PTP restart, power
cycle, mode command, QSFP/fiber change, polarity/bitslip change,
autonegotiation/SI5340/MDIO change, or control-parameter change.

The Master remained the previously programmed rebuild image:

```text
MASTER_SOF_SHA256 = c5de071d88fff6e4bf2b0e38dccebd7100daadd2629834589a2eb64e17834969
SOURCE_REBUILD    = ec1f25e81e0eb8c2caee796d13a225eaae81e5f2
```

The Slave was not programmed and was kept in its existing state.

The preceding recovery observer had stopped before its first sample because
its baseline parser required a `ROLE=SLAVE` token that was absent from the
actual `REBUILD_BASELINE_PAIR` records. The parser was corrected on Laptop
and pushed in commit `71d91d53`; the corrected observer was then pulled to
Pain. Offline postmortem tests and Pain shell syntax validation passed.

## Baseline

The preserved pre-program baseline was a valid paired capture with five
healthy samples:

```text
BASELINE_RESULT              = PASS
BASELINE_SLAVE_LINK_MODE     = UP
BASELINE_SLAVE_LINK_UP_COUNT = 5 / 5
SLAVE_STICKY47_LINK_DROP     = 0
SLAVE_STICKY48_TM_LINK_DROP  = 0
SLAVE_STICKY46_SYNC_LOSS     = 34616
SLAVE_STICKY47_LOCK_LOSS     = 23652
```

## Read-only postmortem capture

The observer collected ten paired samples at a nominal 250 ms gap. All ten
were valid; the complete capture elapsed 6032 ms.

Master local readiness was true in all ten samples:

```text
SI_CONFIG_DONE = 1
WR_READY       = 1
RX_READY       = 1
TX_READY       = 1
CPU_RESET_N    = 1
PHY_RST        = 0
PHY_TX_DISABLE = 0
PTP_STATE      = 6
```

Slave link/recovery fields were valid in all ten samples:

```text
RX_LOCKED_TO_DATA = 1
RX_PATTERN_READY  = 1
CORE_LINK_OK      = 1
CORE_TM_LINK_UP   = 1
```

The first current sample is not counted as stable because it is the activity
observer's initial reference sample. Samples 1 through 9 then formed a
continuous stable-UP run of nine samples, exceeding the required five.

The current sticky deltas were:

```text
LINK_DROP_DELTA     = 1
TM_LINK_DROP_DELTA  = 1
SYNC_LOSS_DELTA     = 33219
LOCK_LOSS_DELTA     = 24761
```

The link-drop and TM-link-drop deltas are the formal interruption evidence.
The larger SYNC/LOCK deltas are retained as supporting diagnostics, but they
would not have been sufficient to declare this postmortem PASS by themselves.

## Stability and reset checks

```text
READ_VALID samples             = 10 / 10
RESET_CHANGED samples          = 0
MAX_STABLE_STREAK              = 9
MASTER_BOOT_GENERATION        = 00000001 throughout capture
SLAVE_BOOT_GENERATION         = 00000001 throughout capture
CPU/WR-core/SI-config counters = stable throughout capture
```

## Interpretation

The preserved baseline proves that the Slave was already linked before the
Master-last rebuild. The new sticky link-drop deltas prove that a link
interruption occurred after that baseline, while the nine-sample stable-UP
run proves that the current pair had reacquired and remained healthy during
the postmortem window. Therefore the postmortem supports the classification:

```text
EC1F25E8_SOURCE_REBUILD_MASTER_LAST_RECOVERY = SUPPORTED_POSTMORTEM
STARTUP_ORDER_SENSITIVITY                    = SUPPORTED
```

It does not provide recovery latency because the original observer failed
before its first sample. It also does not evaluate `S_LOCK`, global-time
validity, or scheduled triggering.

## Artifacts

- `PLAN.md` — fixed read-only contract and formal criteria.
- `raw/current/postmortem.log` — complete Pain observer output.
- `raw/protocol.txt` — no-program/no-reset protocol declaration.
- `raw/program/stop.txt` — observer completion and zero programming counts.
- `analysis/summary.json` — machine-readable verdict.
- `analysis/analyzer.txt` — analyzer output.
- Prior baseline: `../EXP-S6-MASTER-LAST-EC1F25E8-REBUILD-RECOVERY-ATTRIBUTION-20260921/raw/baseline/baseline.log`.
