# EXP-S5-F4J-PRODUCER-AUDIT-FREQ-COUNT-20260920

## Verdict

```text
F4J_OBSERVER_FRESHNESS_FIX          = HARDWARE_EFFECTIVE
F4J_30S_PRODUCER_AUDIT              = VALID_TARGET_REACHED
F4J_TERMINAL_FRESHNESS_MODE         = SESSION_EDGE
HISTORICAL_TERMINAL_SUPPRESSED     = YES
PRODUCER_COHERENCE                  = PASS
HELPER_RUNTIME_GUARD                = PASS
PHY_LINK_RUNTIME_GUARD              = PASS
RESET_GENERATION_GUARD              = PASS
MAIN_FREQUENCY_BRANCH_REENTRY      = NOT_OBSERVED
POLICY_CAUSAL_RESULT                = INCONCLUSIVE_CAPTURE_LOSS
STEP5_RESULT                        = NO
STOP_REASON                         = TARGET_REACHED
```

This is not a Step5 pass. The audit reached its bounded target, but the complete
stdout was not redirected to a raw file during execution. The retained terminal
summary and representative coherent frames are sufficient to establish runtime
validity and the absence of a new frequency-branch re-entry, but are not enough
to count every unique frame's `FREQ_ERROR` versus `FREQ_COUNT_BEFORE/AFTER` pair.
Therefore no acceptance-policy-versus-hysteresis causal claim is made.

## Provenance and execution

```text
FPGA_IMAGE_SOURCE_COMMIT       = 63bf952a3ea46dd0231f12d6d3e9b86d816ed953
OBSERVER_SOURCE_COMMIT         = b4ca04ac
PAIN_CHECKED_OUT_COMMIT        = eee68028
REPROGRAM                       = NO
CONTROL_CHANGE                  = NONE
TARGET_DURATION_MS              = 30000
HARD_DURATION_MS                = 40000
SESSION_ELAPSED_MS              = 31087
RUN_END_REASON                  = TARGET_REACHED
STOP_REASON                     = NONE
```

The first attempt at 01:03:03 used Pain's stale `63bf952a` observer and stopped
at the historical sticky failure with `TERMINAL_FRESHNESS_MODE=LEGACY`. It is
excluded from inference. The corrected attempt started at 01:06:21 after Pain
was fast-forwarded to `eee68028`.

## Corrected runtime result: Slave

```text
HELPER_LOCKED                   = 1
HELPER_LOCK_COUNT               = 1000
HELPER_UPDATE_COUNT             = advancing
CORE_TM_LINK_UP                 = 1
CORE_LINK_OK                    = 1
PHY_LINK_USABLE                 = 1
PSTAT_LINK                      = 1
BOOT_GENERATION                 = 1 (stable)
WR_CORE_RESET_COUNT             = 0 (stable)
SI_CONFIG_DROP_COUNT            = 0 (stable)
SPLL_DELOCK_COUNT               = 0
PRODUCER_VALID                  = 33
PRODUCER_UNIQUE                = 17
PRODUCER_DUPLICATES             = 16
UPDATE_PROGRESS                = 16
SAMPLE_PROGRESS                = 16
BRANCH_BINS                     = 2
FREQ_BRANCH_FRAMES              = 0
PHASE_BRANCH_FRAMES             = 33
PHASE_DETECTOR_CALLS            = 33
PHASE_IN_BAND                   = 8
PHASE_OUT_BAND                  = 25
TERMINAL                        = 0
TERMINAL_CANDIDATE              = 1 (historical sticky state)
TERMINAL_FRESH_EDGE             = 0
TERMINAL_FRESHNESS_MODE         = SESSION_EDGE
WR_FAILURE_REASON               = 3 (historical, not a fresh edge)
STOP_REASON                     = NONE
```

The observer freshness fix behaved as intended: the historical sticky failure
remained a baseline (`candidate=1`) and did not end the session (`terminal=0`,
`fresh_edge=0`). No link, helper, reset, or generation invalidation occurred.

## Representative coherent producer frames

The retained console excerpt contains these valid examples:

```text
frame 1:  FREQ_ERROR=+39  BRANCH_ID=PHASE  FREQ_COUNT 50 -> 50
frame 32: FREQ_ERROR=+35  BRANCH_ID=PHASE  FREQ_COUNT 50 -> 50
frame 33: FREQ_ERROR=+22  BRANCH_ID=PHASE  FREQ_COUNT 50 -> 50
```

All observed frames were phase-branch frames, but the complete 17-frame pair set
was not preserved as a raw artifact. In particular, the summary `8` in-band and
`25` out-of-band counters cannot by itself prove how each corresponding
frequency-count transition behaved. The correct conclusion is therefore
`INCONCLUSIVE_CAPTURE_LOSS`, not a guessed policy root cause.

## Required next boundary

The runtime audit itself is valid and the freshness blocker is cleared. Before
designing an acceptance/handoff candidate, repeat the same bounded audit only if
the observer output is redirected and checksumed from the start, so every unique
coherent producer frame is retained. Until that evidence exists:

```text
MAIN_FREQ_ACCEPTANCE_POLICY_BOUNDARY = NOT_CLOSED
MAIN_FREQ_HYSTERESIS_BOUNDARY        = NOT_CLOSED
STEP5                                = NO
```
