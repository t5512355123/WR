# EXP-S6-SLAVE-RX-WORD-ALIGN-FRESH-ACQUISITION-V3-20260921

## Formal verdict

```text
MASTER_TX_PRECONDITION        = PASS (5/5)
SLAVE_EXACT_PROGRAM           = PASS
PROGRAM_TO_OBSERVER_START    = 3 ms
PROGRAM_TO_FIRST_VALID       = 140 ms (PASS, <= 5000 ms)
SLAVE_LOCAL_READY             = PASS (3 consecutive)
RECOVERED_RX_CLOCK_ACTIVITY   = PRESENT
RX_LOCKED_TO_DATA              = 1 throughout the formal window
RX_SYNCSTATUS                  = 0 throughout the formal window
RX_PATTERN_READY               = 0 throughout the formal window
ALIGNMENT_STREAK               = 0
8B10B_ERROR_DELTA              = 0 after the fresh local-ready baseline

WORD_ALIGN_WINDOW              = COMPLETE (10072 ms of 10000 ms)
FORMAL_RESULT                  = FAIL_RX_WORD_ALIGNMENT_EARLY_LOSS_WITH_8B10B_ERRORS
WORD_ALIGN_ACQUISITION         = FAIL
WORD_ALIGN_STABILITY           = FAIL
STEP6A_GLOBAL_TIME              = NOT_PASS
STEP6B_SCHEDULED_TRIGGER        = NOT_RUN
S_LOCK                          = NOT_REACHED
```

This is the first complete corrected-observer word-align window.  It is not a
Step6A Global Time pass: the prerequisite Slave RX word alignment never
reached the five-sample stable PASS gate.

The formal early-loss classification follows the predeclared V3 rule because
the fresh-session sticky history already contained `FIRST_SYNC_LOSS_COUNT=1`
and `FIRST_LOCK_LOSS_COUNT=3`, and the completed window never produced a
stable alignment.  The raw data also shows an important limitation: after the
local-ready baseline, `ENC_ERR_DELTA`, `DISPERR_DELTA`, and
`ERRDETECT_DELTA` remained zero.  Therefore this report does not claim that a
new 8b/10b error event occurred during the formal window; it records the
classification and the evidence boundary separately.

## Provenance and fixed variables

- Branch: `exp/step6-Global-Time-Testing`
- Pain source commit: `cd8c672e5f176904a34d0fbe0a72d95e3771057f`
- Exact image source: `ec1f25e8`
- Slave SOF SHA-256:
  `7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e`
- Master cable: `DE5 [1-11.1]` (not reprogrammed)
- Slave cable: `DE5 [1-11.2]`
- No compile, firmware build, power cycle, PHY reset, PTP restart, mode
  command, fiber/QSFP operation, polarity/bitslip change, autonegotiation
  change, SI5340 change, or MDIO write.

## Phase A: Master TX precondition

Five valid Master samples passed with stable reset/configuration state:

```text
SI_CONFIG_DONE=1
WR_READY=1
RX_READY=1
TX_READY=1
CPU_RESET_N=1
PHY_RST=0
PHY_TX_DISABLE=0
PTP_STATE=6
BOOT_GENERATION stable
CPU_RESET_COUNT stable
WR_CORE_RESET_COUNT stable
SI_CONFIG_DROP_COUNT stable
```

`CORE_TM_LINK_UP` and `CORE_LINK_OK` were recorded but deliberately were not
used as the Master TX precondition gate.

## Phase B: automatic Slave program-to-observer sequence

The V3 runner verified the exact SOF, programmed only the Slave, and launched
the read-only observer without a human delay:

```text
SLAVE_PROGRAM_RC=0
configured devices=1
program errors=0
program warnings=0
PROGRAM_DONE_TO_OBSERVER_START_MS=3
PROGRAM_DONE_TO_FIRST_VALID_SAMPLE_MS=140
```

## Phase C: local-ready and fresh baseline

The third consecutive local-ready sample occurred at observer elapsed
`1196 ms`, and the formal word-align window started at that point.  Across
the capture:

```text
sample_count=74
valid_samples=74
transport_errors=0
reset_changes=0
max_local_ready_streak=69
```

The first fresh absolute sticky values were:

```text
FIRST_ENC_ERR_COUNT    = 10219875
FIRST_DISPERR_COUNT    = 10219875
FIRST_ERRDETECT_COUNT  = 10219875
FIRST_SYNC_LOSS_COUNT  = 1
FIRST_LOCK_LOSS_COUNT  = 3
FIRST_LINK_DROP_COUNT  = 0
```

At the first local-ready baseline the direct state was:

```text
RX_LOCKED_TO_DATA = 1
RX_CLOCK_ACTIVITY_CHANGED = 1
RX_SYNCSTATUS = 0
RX_PATTERN_READY = 0
```

## Phase D: complete word-align window

The recovered RX activity changed in 67 distinct values during the formal
window, and `RX_LOCKED_TO_DATA` remained 1.  However:

```text
RX_SYNCSTATUS    = 0 for every formal sample
RX_PATTERN_READY = 0 for every formal sample
ALIGNMENT_STREAK = 0
SYNC_SEEN        = 0
PATTERN_SEEN     = 0
```

The final formal sample was:

```text
WORD_ALIGN_ELAPSED_MS = 10072
RX_LOCKED_TO_DATA     = 1
RX_CLOCK_ACTIVITY_CHANGED = 1
RX_SYNCSTATUS         = 0
RX_PATTERN_READY      = 0
ENC_ERR_DELTA         = 0
DISPERR_DELTA         = 0
ERRDETECT_DELTA       = 0
SYNC_LOSS_COUNT       = 1
LOCK_LOSS_COUNT       = 4
STOP_CANDIDATE        = FAIL_RX_WORD_ALIGNMENT_EARLY_LOSS_WITH_8B10B_ERRORS
```

Thus the captured boundary is:

```text
Slave local reset/ready       PASS
Recovered RX clock            PRESENT
RX data lock                  PRESENT
Word synchronization          NOT ESTABLISHED
Pattern-ready acquisition     NOT ESTABLISHED
WR endpoint link               NOT REACHED
```

## Scope and next decision boundary

This V3 result closes the repeated fresh-observer question.  It does not
justify changing polarity, bitslip, autonegotiation, SI5340, PHY RTL, PTP,
SoftPLL, or Global Time logic in this same experiment.  The next experiment,
if any, must target the now-bounded RX word-alignment/PCS boundary and must be
chosen after the adviser reviews this complete capture.  No same-session retry
was performed.

## Raw evidence

```text
BA83A310A8875EFA0EB114E5C00F5367D0EA2C2DADF08C65AF7786C33E37E047  raw/preflight/master-tx-precondition.log
6CC2DBD3D790015A5496AE8108662624D5544508642273E184BCD98EC58C3229  raw/program/metadata.txt
9D60EAA661AADE763C444855EFC7A1D4BFA0C9BA4B2610FE2AFF56FB41D1AB2B  raw/program/sequence-times.log
67862A68079EEE2801F572DE59350495F63B119346994F71D9B73E7E3C187E27  raw/program/slave-program.log
D4625A0C2393755A510F7A678EFCD7F668C2F6A6ECB2BAE25011BAE6E2CEED4D  raw/program/sof-sha256.txt
559C539646824D68528352A2721C0E2081B5DC330C63294ABE85332E5413BDE0  raw/word-align/slave-word-align.log
```
