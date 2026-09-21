# EXP-S6-SAME-PPS-GLOBAL-TIME-CONSISTENCY-20260922

## Purpose

Validate Step6A-2 by comparing the Master and Slave frozen Global-Time
snapshots using the shared `SNAPSHOT_TAI` label. This experiment tests digital
same-PPS timestamp consistency; it does not claim that the physical trigger
edge or phase difference is zero nanoseconds.

## Adviser contract

This is a fully read-only experiment. Do not compile, build, program, restart
PTP, issue a mode command, reset CPU/WR/PHY, power-cycle, change fiber/QSFP,
change polarity/autonegotiation/SI5340/MDIO, or modify any functional HDL,
firmware, QSF, SDC, MIF, or vendor source.

Only the observer and analysis scripts plus this experiment documentation may
change.

## Phase A: paired precondition gate

Collect three paired Master/Slave samples. Every pair must show:

- `SI_CONFIG=1`, WR ready, `CORE_LINK_OK=1`, `CORE_TM_LINK_UP=1`;
- `TIME_VALID=1`, `PPS_VALID=1` and a valid stable snapshot;
- `CPU_RESET_N=1`, `PHY_RST=0`, `PHY_TX_DISABLE=0`;
- stable reset signature (`BOOT_GENERATION=1`, `CPU_RESET_COUNT=1`,
  `WR_CORE_RESET_COUNT=1`, `SI_CONFIG_DROP_COUNT=1`);
- Slave RX lock/pattern readiness, SoftPLL sequence ready, PSTAT lock, and
  Main lock.

If the gate fails, stop immediately with
`INCONCLUSIVE_STEP6A2_PRECONDITION_CHANGED`. Do not attempt recovery.

## Phase B: same-PPS observation

For each read, the observer performs the narrow coherent sequence
`probe63-before -> probe62 -> probe63-after`, then reads the required health
and lock status. A snapshot is accepted only when the two probe63 values match,
all validity flags are set, and `SNAPSHOT_CYCLES` is in `0..124999999`.

Build independent maps `MASTER[SNAPSHOT_TAI] = SNAPSHOT_CYCLES` and
`SLAVE[SNAPSHOT_TAI] = SNAPSHOT_CYCLES`. Never pair by host sample index or by
snapshot count. Observe for at most 20 seconds, stopping early on a formal
pass, confirmed mismatch, same-board coherence violation, validity loss, or
runtime invalidity.

## Formal outcomes

Pass requires at least five distinct common TAI labels, valid flags on all
accepted rows, legal cycles, and exactly equal Master/Slave cycles for every
common label:

```text
RESULT=PASS_SAME_PPS_GLOBAL_TIME_CONSISTENCY
STEP6A_1=PASS
STEP6A_2=PASS
STEP6A_GLOBAL_TIME=PASS
STEP6B=NOT_RUN
MAX_ABS_DELTA_TICKS=0
MAX_ABS_DELTA_NS=0
```

Three mismatch labels confirm `FAIL_SAME_PPS_GLOBAL_TIME_OFFSET`. A fixed TAI
epoch offset without common labels is `FAIL_GLOBAL_TIME_TAI_EPOCH_OFFSET`.
Fewer than five common labels by the deadline is
`INCONCLUSIVE_INSUFFICIENT_COMMON_PPS_LABELS`. A repeated same-board TAI with
different cycles is `INCONCLUSIVE_SNAPSHOT_COHERENCE_VIOLATION`. Any loss of
time/snapshot validity is `FAIL_STEP6A1_STABILITY_REGRESSION_DURING_STEP6A2`;
link/reset/transport invalidity is `INCONCLUSIVE_RUNTIME_STATE_CHANGED`.

## Required evidence

Preserve the complete raw observer output, protocol/stop records, analyzer
output and JSON summary. Normalize only transport-added trailing whitespace
before hashing; do not rewrite measured fields. Record the exact source commit
and all raw/summary SHA-256 values in the final report.
