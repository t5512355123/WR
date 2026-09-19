# EXP-S5-QSFPA-F4H-EXACT-SOF-LINK-STABILITY-20260919

## Purpose

Reprogram the exact QSFP-A Master/Slave images from the last documented
successful QSFP-A WR-link session and determine whether the link gate remains
stable after a fresh programming event.

This is an upstream link-stability test only. It is not a Step 4B, F4S, or
Step 5 lock experiment.

## Frozen provenance

```text
source_commit = 898b041afa2fcd6ca48a84eb7326eebc419ac4a3
master_sof_sha256 = fe73fe54e702e974ed4452e517751ebf8a1cbcd93d7a19207839ed13a9bed7
slave_sof_sha256  = 30c78989caa9496b5a34bc771f4c0a238ebd9c271045f55c6a7d4963c13df7bc
master_target = DE5 [1-11.1]
slave_target = DE5 [1-11.2]
topology = original QSFP-A path
```

The exact source/image identity is taken from
`EXP-S5-F4H-PHY-STATUS-SOURCE-FIX-RETEST-20260916/REPORT.md`, whose formal
window had `PSTAT_LINK=1` and a valid direct-PHY gate on every recorded row.

## Allowed actions

- Recreate the exact 898b041 F4H images if the binary artifacts are not still
  available on Pain.
- Program only the two original QSFP-A images.
- Perform read-only startup/link and clock-activity observations.

## Prohibited actions

- No source or production-control changes.
- No PI/gain/threshold/timeout/bootstrap changes.
- No QSFP-B/C/D remapping.
- No F4S/F4L/Step 5 observer.
- No mode/control writes and no additional power cycle.

## Observation gate

For both boards, record repeated read-only samples of:

```text
SI_CONFIG_DONE
CPU_RESET_N
WR_RX_READY
WR_TX_READY
CORE_TM_LINK_UP
CORE_LINK_OK
PSTAT_LINK
PHY_LINK_USABLE
TERMINAL
```

Also record reference/DMTD/RX clock activity and RX-data lock. The link is
classified as stable only if the required gate remains true throughout the
specified observation window with no terminal/reset/generation regression.

Stop immediately on image mismatch, programming failure, transport failure,
reset/generation change, terminal state, or a failed required link bit.
