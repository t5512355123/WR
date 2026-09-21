# EXP-S6-MASTER-LAST-EC1F25E8-REBUILD-POSTMORTEM-RECOVERY-ATTRIBUTION-20260922

## Purpose

Re-evaluate the already-completed Master-last `ec1f25e8` rebuild without
changing the hardware state. The previous recovery observer stopped before
its first sample because its baseline parser required a `ROLE=SLAVE` token
that the actual `REBUILD_BASELINE_PAIR` records do not contain.

## Fixed contract

This is read-only. No Master or Slave compile/program, firmware build,
power-cycle, PHY reset, PTP restart, mode command, QSFP/fiber change,
polarity/bitslip change, autonegotiation change, SI5340 write, or MDIO write
is permitted.

The current Master rebuild image remains the programmed image:

`c5de071d88fff6e4bf2b0e38dccebd7100daadd2629834589a2eb64e17834969`

The Slave remains untouched. Use the prior PASS pre-program baseline from
`EXP-S6-MASTER-LAST-EC1F25E8-REBUILD-RECOVERY-ATTRIBUTION-20260921`.

## Capture

Run ten paired Master/Slave read-only samples with a 250 ms gap. Do not use
the failed observer's 120-second recovery window as a substitute for this
postmortem. Preserve the complete raw log and analyzer JSON.

## Formal interpretation

The postmortem is a PASS only when both conditions hold:

1. Current Slave sticky `LINK_DROP_COUNT` or `TM_LINK_DROP_COUNT` is greater
   than its pre-program baseline.
2. Five consecutive valid current paired samples show Master local readiness
   and Slave `RX_LOCKED_TO_DATA`, changing RX activity,
   `RX_PATTERN_READY`, `CORE_LINK_OK`, and `CORE_TM_LINK_UP`, with reset,
   generation, and configuration counters stable.

SYNC/LOCK counter deltas without a LINK_DROP/TM_LINK_DROP delta are
inconclusive, not formal proof of link interruption. `S_LOCK` remains outside
this postmortem; Step6A and Step6B are not evaluated in this experiment.
