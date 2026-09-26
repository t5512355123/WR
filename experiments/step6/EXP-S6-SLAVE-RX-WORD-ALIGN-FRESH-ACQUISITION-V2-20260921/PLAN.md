# EXP-S6-SLAVE-RX-WORD-ALIGN-FRESH-ACQUISITION-V2-20260921

## Purpose

Repeat the same Slave fresh-start boundary with a valid acquisition window.
The experiment distinguishes:

```text
never acquired word sync
        vs.
acquired transiently and then lost
        vs.
stable word-align PASS
```

## Fixed image and hardware

- Source image: `ec1f25e81e0eb8c2caee796d13a225eaae81e5f2` (`ec1f25e8`).
- Slave SOF SHA-256:
  `7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e`.
- Keep the current continuously-running Master; do not program it.
- Program the exact Slave SOF once on `DE5 [1-11.2]`.

## Forbidden changes

No compile, firmware build, power cycle, manual PHY reset, PTP restart, mode
command, fiber/QSFP operation, polarity/bitslip change, autonegotiation
change, SI5340 change, MDIO write, SoftPLL/PI/timeout/gain change, RTL change,
vendor-IP change, or second Slave program in this run.

## Phase A: Master precondition

Before the Slave-only runner starts, capture five valid Master samples and
require:

```text
SI_CONFIG_DONE=1
WR_READY=1
TX_READY=1
CPU_RESET_N=1
PHY_RST=0
PHY_TX_DISABLE=0
PTP_STATE=6
```

Reset/generation counters and transport must remain stable.  Peer-dependent
link bits are recorded but are not this pre-Slave gate.

## Phase B: automatic Slave program and observer

Use `scripts/experiment/run_step6_slave_rx_word_align_fresh_acquisition_v2.sh`
to hash-check, program the Slave, record epoch-millisecond timestamps, and
launch the observer without a human-inserted delay.  Formal validity requires:

```text
PROGRAM_DONE_TO_FIRST_VALID_SAMPLE_MS <= 5000
```

If this is exceeded, stop as `INCONCLUSIVE_OBSERVER_START_LATE` and do not
program again.

## Phase C: local-ready and fresh history

The observer requires three consecutive valid local-ready samples within 10 s
of the program/observer start.  At the first valid sample, preserve the
absolute values of:

```text
ENC_ERR_COUNT
DISPERR_COUNT
ERRDETECT_COUNT
SYNC_LOSS_COUNT
LOCK_LOSS_COUNT
LINK_DROP_COUNT
```

At the third local-ready sample it establishes delta baselines and records:

```text
LOCAL_READY_PASS_TIMESTAMP_MS
WORD_ALIGN_WINDOW_START_MS
WORD_ALIGN_ELAPSED_MS
```

## Phase D: full word-align window

Observe for a full 10,000 ms measured from `WORD_ALIGN_WINDOW_START_MS`, not
from process start and not from the sample-count cap.  The safety cap may only
produce an inconclusive result.

PASS stops immediately after five consecutive valid samples with:

```text
RX_LOCKED_TO_DATA=1
RX activity changing
RX_SYNCSTATUS=1
RX_PATTERN_READY=1
RX_ENC_ERR=0
RX_DISPERR=0
RX_ERRDETECT=0
post-baseline error deltas all zero
```

## Formal failure classes

- `FAIL_RX_WORD_ALIGNMENT_NEVER_ACQUIRED_WITH_8B10B_ERRORS`: full 10 s,
  no sync/pattern ever seen, first and final sync-loss history are zero, and
  encoding/disparity/errdetect evidence increases.
- `FAIL_RX_WORD_ALIGNMENT_EARLY_LOSS_WITH_8B10B_ERRORS`: fresh absolute
  `FIRST_SYNC_LOSS_COUNT > 0`, or live sync/pattern was seen and later lost
  with new error evidence.
- `FAIL_RX_CDR_OR_RECOVERED_CLOCK_REGRESSION`: five consecutive post-baseline
  samples lose RX data lock or recovered activity.
- `PASS_WORD_ALIGN_ACQUISITION`: five consecutive stable alignment samples.
- Any late observer, transport/reset/generation change, incomplete 10-second
  window, or safety-cap stop is `INCONCLUSIVE`.

This experiment does not claim Step6A Global Time PASS, Step6B trigger PASS,
S_LOCK PASS, or Step5 changes.
