# EXP-S6-SLAVE-RX-WORD-ALIGN-FRESH-ACQUISITION-V2-20260921

## Formal verdict

```text
MASTER_TX_PRECONDITION        = PASS (5/5)
SLAVE_EXACT_PROGRAM           = PASS
PROGRAM_TO_FIRST_VALID        = 147 ms (PASS, <= 5000 ms)
SLAVE_LOCAL_READY             = PASS (3 consecutive samples)
RECOVERED_RX_CLOCK_ACTIVITY   = PRESENT
RX_LOCKED_TO_DATA              = 1 throughout the capture
FIRST_SYNC_LOSS_COUNT          = 1
FIRST_LOCK_LOSS_COUNT          = 3
RX_SYNCSTATUS                  = 0 in the captured samples
RX_PATTERN_READY               = 0 in the captured samples
8B10B_ERROR_DELTA              = PRESENT and increasing

WORD_ALIGN_WINDOW              = INCOMPLETE (1679 ms of 10000 ms)
FORMAL_RESULT                  = INCONCLUSIVE_COUNTER_BASELINE
PRELIMINARY_BOUNDARY           = EARLY_SYNC_LOSS_WITH_8B10B_ERRORS
STEP6A_GLOBAL_TIME              = NOT_PASS
STEP6B_SCHEDULED_TRIGGER        = NOT_RUN
S_LOCK                          = NOT_REACHED
```

This is not a formal word-align FAIL or PASS.  The run reached the fresh
startup boundary with valid timing, but the observer stopped early because of
an observer-side numeric counter-delta bug before the required 10-second
window completed.

## Provenance and fixed variables

- Branch: `exp/step6-Global-Time-Testing`
- V2 observer/runner source commit: `663837c1`
- Exact image source: `ec1f25e81e0eb8c2caee796d13a225eaae81e5f2`
  (`ec1f25e8`)
- Slave SOF SHA-256:
  `7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e`
- Master cable: `DE5 [1-11.1]` (not reprogrammed)
- Slave cable: `DE5 [1-11.2]`
- No compile, firmware build, power cycle, PHY reset, PTP restart, mode
  command, fiber/QSFP operation, polarity/bitslip change, autonegotiation
  change, SI5340 change, or MDIO write.

## Phase A: Master TX precondition

Five valid Master samples passed with:

```text
SI_CONFIG_DONE=1
WR_READY=1
RX_READY=1
TX_READY=1
CPU_RESET_N=1
PHY_RST=0
PHY_TX_DISABLE=0
PTP_STATE=6
```

Boot/reset/configuration counters and transport were stable.  Peer-dependent
link bits were recorded but were not used as the pre-Slave gate.

## Phase B: automatic program-to-observer sequence

The host runner verified the exact SOF, programmed only the Slave, and launched
the observer in the same process without a human delay:

```text
SLAVE_PROGRAM_DONE_TO_OBSERVER_START_MS = 2
SLAVE_PROGRAM_DONE_TO_FIRST_VALID_MS    = 147
```

Quartus configured one device successfully with zero errors and zero warnings.

## Phase C/D observations

The first valid Slave sample preserved fresh absolute sticky history:

```text
FIRST_ENC_ERR_COUNT    = 9049604
FIRST_DISPERR_COUNT    = 4271488
FIRST_ERRDETECT_COUNT  = 9049604
FIRST_SYNC_LOSS_COUNT  = 1
FIRST_LOCK_LOSS_COUNT  = 3
FIRST_LINK_DROP_COUNT  = 0
```

Three consecutive local-ready samples completed at observer time about
`1204 ms`, and the word-align window began there.  During the valid portion of
the capture:

```text
RX_LOCKED_TO_DATA = 1
RX activity        = changing
RX_SYNCSTATUS      = 0
RX_PATTERN_READY   = 0
RX_BITSLIDE        = 15
CORE_TM_LINK_UP    = 0
CORE_LINK_OK       = 0
```

The fresh absolute counters and deltas show a stream with recovered activity
but persistent encoding/disparity/errdetect evidence.  The nonzero first
`SYNC_LOSS_COUNT` and `LOCK_LOSS_COUNT` are preliminary evidence that sync was
acquired and lost during the interval before/around the first valid sample;
they are not by themselves a completed 10-second formal verdict.

## Why the formal result is inconclusive

The observer stopped at approximately `1679 ms` after the local-ready window
start with `INCONCLUSIVE_COUNTER_BASELINE`.  The cause was in the observer:
the decoded sticky-counter values were numeric Tcl values, but the delta helper
sent them through a transport helper that interpreted decimal strings as
hexadecimal words.  It falsely produced `DECREASED` and ended the capture.

The offline fix is to calculate deltas directly on already-decoded numeric
values.  No hardware retry is performed in this same run.  A future valid
repeat must use the corrected observer and complete the entire 10000-ms
word-align window, unless an explicitly valid five-sample alignment PASS or a
live early-loss/CDR stop occurs first.

## Raw evidence

```text
5C518245649A8F9CDECBF6B787D253AB7F1D167266412E0B9C796529B222204F  raw/preflight/master-tx-precondition.log
32F1961F256A5624763CE194E0F59BC800FC7F05A7B251B05C52F590BD690E92  raw/program/metadata.txt
D4625A0C2393755A510F7A678EFCD7F668C2F6A6ECB2BAE25011BAE6E2CEED4D  raw/program/sof-sha256.txt
B8D49D38305458017DA169B4952256D80BF63C691B5D0633B5641641A74E19D7  raw/program/slave-program.log
261621C94625450A33450C06605E559BA2218DE38C2CD9A92953E7521830FA0F  raw/program/sequence-times.log
7E0393F9D2E6E61C499B72A1FF2E260080932AFB7E5D49DFCC7DBD23E3B7BFD4  raw/word-align/slave-word-align.log
```
