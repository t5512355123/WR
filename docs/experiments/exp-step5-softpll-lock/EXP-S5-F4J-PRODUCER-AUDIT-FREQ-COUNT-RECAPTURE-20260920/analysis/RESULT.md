# Full F4J Producer Audit Analysis

## Capture integrity

```text
QUARTUS_EXIT                 = 0
RUN_END_REASON               = TARGET_REACHED
STOP_REASON                  = NONE
SESSION_ELAPSED_MS           = 31246
TARGET_DURATION_MS           = 30000
HARD_DURATION_MS             = 40000
RAW_SHA256                   = 0807261EA9231E284D86003F1070580BEF859CE9AFCF735CAC185FAC4710DA35
RAW_SIZE_BYTES               = 265449
```

## Runtime validity

```text
HELPER_LOCKED                = 1
HELPER_LOCK_COUNT            = 1000
PHY_LINK_USABLE              = 1
PSTAT_LINK                   = 1
BOOT_GENERATION              = stable
CPU_RESET_COUNT              = stable
WR_CORE_RESET_COUNT          = stable
SI_CONFIG_DROP_COUNT         = stable
SPLL_DELOCK_COUNT            = 0
TERMINAL                     = 0
TERMINAL_CANDIDATE           = 1 (historical sticky state)
TERMINAL_FRESH_EDGE          = 0
TERMINAL_FRESHNESS_MODE      = SESSION_EDGE
WR_FAILURE_REASON            = 3 (historical)
```

The historical sticky failure was correctly treated as the session baseline.
It did not produce a fresh edge or end the audit.

## Unique producer-frame evidence

The Slave produced 33 valid frames, of which 17 had unique `UPDATE_ID` values.
All 17 unique frames were coherent and had `BRANCH_ID=2` (phase). There were
zero unique frequency-branch frames.

```text
unique_frames                 = 17
phase_branch_frames           = 17
frequency_branch_frames       = 0
acceptance frames             = 12
acceptance recovery frames    = 3
out-of-band decrement events  = 2
```

The 15 acceptance/recovery frames were:

```text
|FREQ_ERROR| <= 50
counter stayed at 50 or recovered 49 -> 50
```

The only two out-of-band events were:

```text
FREQ_ERROR=+52: 50 -> 49
FREQ_ERROR=+60: 50 -> 49
```

The full per-frame table is in `analysis/unique_frames.tsv` and is derived
from the checksumed raw log.

The cumulative producer transition counters were stable throughout the audit:

```text
FREQ_TO_PHASE = 2
PHASE_TO_FREQ = 1
LAST_TRANSITION = 258
```

## Causal classification

```text
MAIN_FREQ_ACCEPTANCE_POLICY_BOUNDARY = SUPPORTED
HYSTERESIS_AS_PRIMARY_CAUSE          = NOT_SUPPORTED
MAIN_FREQUENCY_BRANCH_REENTRY        = NOT_OBSERVED
FREQ_ACCEPTANCE_VS_HYSTERESIS        = ACCEPTANCE_MARGIN_DOMINANT
```

The evidence closes the current diagnostic boundary:

```text
residual frequency error mostly +18..+49
        -> accepted by the +/-50 window
        -> frequency counter remains/reaches 50
        -> Main remains in phase branch
        -> no frequency-branch re-entry in the unique frames
        -> residual error continues to drive phase ramp
```

The two `+52/+60` decrements are real out-of-band events, but they are
sporadic relative to the 15 acceptance/recovery frames and do not support
hysteresis retention as the primary cause in this bounded window.

## Final verdict

```text
F4J_RECAPTURE                  = PASS
F4J_PRODUCER_CAUSAL_CORRELATION= PASS
MAIN_FREQ_ACCEPTANCE_CAUSE     = SUPPORTED
HYSTERESIS_PRIMARY_CAUSE       = NOT_SUPPORTED
STEP5                          = NO
CONTROL_CANDIDATE_EXECUTED     = NO
```

This result justifies designing one acceptance/handoff causal candidate next.
It does not authorize changing the threshold or any other control parameter in
this experiment, and it is not a Step5 lock pass.
