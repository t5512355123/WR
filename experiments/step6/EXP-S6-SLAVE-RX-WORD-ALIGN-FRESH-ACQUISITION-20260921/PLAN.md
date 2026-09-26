# EXP-S6-SLAVE-RX-WORD-ALIGN-FRESH-ACQUISITION-20260921

## Purpose

Determine whether a fresh configuration of the exact Step6A Slave image can
acquire the Arria-10 RX word alignment while the continuously-running Master
is left untouched.  This is the boundary between recovered RX activity and
8b/10b/simple-aligner qualification; it is not an S_LOCK or Global Time
experiment.

## Fixed image and hardware

- Source image: `ec1f25e81e0eb8c2caee796d13a225eaae81e5f2` (`ec1f25e8`).
- Exact Slave SOF SHA-256:
  `7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e`.
- Master remains programmed and continuously transmitting.
- Only `DE5 [1-11.2]` is reprogrammed.

## Explicitly forbidden

No full compile, firmware build, Master programming, power cycle, manual PHY
reset, PTP restart, mode command, fiber/QSFP operation, polarity change,
autonegotiation change, SI5340 change, MDIO write, SoftPLL/PI/timeout/gain
change, RTL change, or vendor-IP change.

## Phase A: Master TX precondition

Before programming the Slave, collect five valid consecutive samples from
`DE5 [1-11.1]`.  Require:

```text
SI_CONFIG_DONE=1
WR_READY=1
TX_READY=1
CPU_RESET_N=1
PHY_RST=0
PHY_TX_DISABLE=0
PTP_STATE=6
```

Reset/generation counters and transport must remain stable.  `CORE_LINK_OK`
and `CORE_TM_LINK_UP` are recorded but are not gates before Slave programming.
If this phase fails, do not program the Slave.

## Phase B: Slave-only fresh programming

Program the exact Slave SOF and record start/end times, programmer output,
configured-device count, and image SHA-256.  Do not program the Master.

## Phase C: local-ready gate

Immediately after Slave programming, sample the Slave at a nominal 100 ms
cadence.  Require three consecutive valid samples with:

```text
SI_CONFIG_DONE=1
WR_READY=1
RX_READY=1
TX_READY=1
CPU_RESET_N=1
PHY_RST=0
PHY_TX_DISABLE=0
```

The local-ready window is at most 10 seconds after program completion.  The
first local-ready pass establishes fresh baselines for sticky counters 45–48.

## Phase D: word-align acquisition

For at most 10 seconds after the local-ready baseline, record instance 0,
corrected instance-7 RX activity `[47:32]`, and Slave sticky counters 45–48.
Counter decisions use deltas from the fresh baseline; RX activity is evidence
of raw-value change only because it is a 16-bit wrapping counter.

PASS requires five consecutive valid samples with:

```text
RX_LOCKED_TO_DATA=1
RX activity changed
RX_SYNCSTATUS=1
RX_PATTERN_READY=1
RX_ENC_ERR=0
RX_DISPERR=0
RX_ERRDETECT=0
ENC_ERR_DELTA=DISPERR_DELTA=ERRDETECT_DELTA=0
```

`RX_PATTERNDETECT` is recorded but is not required to remain high.

## Stop conditions

- Master precondition fail: `INCONCLUSIVE_MASTER_TX_PRECONDITION` or
  `FAIL_MASTER_TX_PRECONDITION`; Slave is not programmed.
- Local-ready timeout: `FAIL_SLAVE_PHY_LOCAL_READY`.
- RX data lock or activity absent for five consecutive post-baseline samples:
  `FAIL_RX_CDR_OR_RECOVERED_CLOCK_REGRESSION`.
- Alignment was seen and then lost with new error evidence:
  `FAIL_RX_WORD_ALIGNMENT_LOSS`.
- Full window with no sync/pattern acquisition and positive 8b/10b deltas:
  `FAIL_RX_WORD_ALIGNMENT_WITH_8B10B_ERRORS`.
- Transport error, reset/generation change, SOF mismatch, or invalid fresh
  baseline: `INCONCLUSIVE`.
- PASS stops immediately at the fifth consecutive valid alignment sample.

This experiment does not claim Step6A Global Time PASS, Step6B trigger PASS,
S_LOCK PASS, or Step5 changes.
