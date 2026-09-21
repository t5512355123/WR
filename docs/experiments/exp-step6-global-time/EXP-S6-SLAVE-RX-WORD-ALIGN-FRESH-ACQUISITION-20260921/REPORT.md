# EXP-S6-SLAVE-RX-WORD-ALIGN-FRESH-ACQUISITION-20260921

## Formal verdict

```text
MASTER_TX_PRECONDITION       = PASS (5/5)
SLAVE_EXACT_PROGRAM          = PASS
SLAVE_LOCAL_READY             = PASS (3 consecutive samples)
RECOVERED_RX_CLOCK_ACTIVITY  = PRESENT
RX_LOCKED_TO_DATA             = 1 for all 10 samples
RX_SYNCSTATUS                 = 0 for all 10 samples
RX_PATTERN_READY              = 0 for all 10 samples
8B10B_ERROR_DELTA             = PRESENT and increasing

FORMAL_RESULT                 = INCONCLUSIVE_OBSERVATION_WINDOW_SHORT
PRELIMINARY_BOUNDARY          = FAIL_RX_WORD_ALIGNMENT_WITH_8B10B_ERRORS
WORD_ALIGN_ACQUISITION        = INCONCLUSIVE
STEP6A_GLOBAL_TIME             = NOT_PASS
STEP6B_SCHEDULED_TRIGGER       = NOT_RUN
S_LOCK                         = NOT_REACHED
```

The preliminary boundary is strongly suggestive, but this run is not a valid
formal `FAIL_RX_WORD_ALIGNMENT_WITH_8B10B_ERRORS` verdict because the required
fresh 10-second acquisition window was not captured.

## Provenance and fixed variables

- Branch: `exp/step6-Global-Time-Testing`
- Laptop/Pain observer commit used: `6ff35f69`
- Exact image source: `ec1f25e81e0eb8c2caee796d13a225eaae81e5f2`
  (`ec1f25e8`)
- Slave SOF SHA-256:
  `7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e`
- Slave cable: `DE5 [1-11.2]`
- Master was not reprogrammed.
- Full compile, firmware build, power cycle, PHY reset, PTP restart, mode
  command, fiber/QSFP operation, polarity change, autonegotiation change,
  SI5340 change, and MDIO write were not performed.

## Phase A: Master TX precondition

Five valid samples were captured from `DE5 [1-11.1]` before programming the
Slave.  All five had:

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

`BOOT_GENERATION`, `CPU_RESET_COUNT`, `WR_CORE_RESET_COUNT`, and
`SI_CONFIG_DROP_COUNT` remained stable.  `WDIAGS_TX` and `PTP_TX` were active.
The peer-dependent `CORE_TM_LINK_UP` and `CORE_LINK_OK` bits were recorded as
0 and were intentionally not used as this pre-Slave gate.

## Phase B: Slave programming

The exact existing `ec1f25e8` Slave SOF was hash-checked before programming:

```text
EXPECTED_SOF_SHA256 = 7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e
ACTUAL_SOF_SHA256   = 7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e
```

Quartus configured one device successfully with zero errors and zero warnings.
The Master was left untouched.

## Phase C/D observations

The Slave observer saw three consecutive local-ready samples and established
fresh sticky-counter baselines.  Across the captured word-align samples:

```text
RX_LOCKED_TO_DATA = 1
RX activity        = changed every sample
RX_SYNCSTATUS      = 0
RX_PATTERN_READY   = 0
RX_PATTERNDETECT   = 0
RX_BITSLIDE        = 15
CORE_TM_LINK_UP    = 0
CORE_LINK_OK       = 0
```

After the fresh baseline, `ENC_ERR_DELTA`, `DISPERR_DELTA`, and
`ERRDETECT_DELTA` were positive and grew.  This is consistent with data
arriving and recovered RX activity being present, while the simple word
aligner never reported qualified synchronization.

## Why the formal result is inconclusive

The programming operation completed at approximately `12:45:34 +08:00`; the
observer started at approximately `12:46:07 +08:00`, about 33 seconds later.
It therefore did not sample the immediate fresh-start acquisition boundary.
Furthermore, the observer invocation used a 14-sample cap at a nominal
100-ms gap.  JTAG transaction time produced 10 samples over only `1502 ms`,
and the observer stopped at its sample cap after `1.555 s`, not after the
required 10-second word-align window.

Therefore this run must not be reported as a definitive word-align failure.
The raw evidence remains valuable as preliminary evidence, but no second
Slave programming or retry is performed in this run because the adviser’s
stop contract forbids supplementing the same session with another program.

The observer was corrected after this run to enforce a wall-clock
`MAX_DURATION_MS=10000` deadline and the offline analyzer now reports the
short-window condition explicitly.  That correction is not a new hardware
result.

## Raw evidence

```text
5114AF11A75E1CE1A810798E8F622B4DF3DF5A65B8638B01BF30060396B29DDD  raw/preflight/master-tx-precondition.log
9B9D5EA1E134E59413D6D4C7D1138ACBED82235A388E9E1A1F9946710D439C47  raw/program/sof-sha256.txt
987235CFA61397D9EB3C38AA2B7D760E899A4ABF2261820C27C1265089D603B3  raw/program/slave-program.log
828216E7A56D186E7E9C97F77BA551D9DD6587FDD82D3ACFAB22A131B6086D81  raw/program/sequence-times.log
0E59824DB7949CB9F36EEAE6D9B4D1CB09D4DDA7423E8B770FDC30F1EF10D1DC  raw/word-align/slave-word-align.log
```

