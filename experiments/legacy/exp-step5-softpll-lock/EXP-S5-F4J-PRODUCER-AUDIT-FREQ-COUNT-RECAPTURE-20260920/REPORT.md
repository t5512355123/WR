# EXP-S5-F4J-PRODUCER-AUDIT-FREQ-COUNT-RECAPTURE-20260920

## Verdict

```text
F4J_RECAPTURE                         = PASS
FULL_RAW_CAPTURE                      = PASS
RAW_CHECKSUM                          = PASS
F4J_PRODUCER_CAUSAL_CORRELATION       = PASS
MAIN_FREQ_ACCEPTANCE_POLICY_BOUNDARY  = SUPPORTED
HYSTERESIS_AS_PRIMARY_CAUSE           = NOT_SUPPORTED
MAIN_FREQUENCY_BRANCH_REENTRY         = NOT_OBSERVED
STEP5_RESULT                          = NO
```

## Provenance

```text
FPGA_IMAGE_SOURCE_COMMIT              = 63bf952a3ea46dd0231f12d6d3e9b86d816ed953
OBSERVER_SOURCE_COMMIT                = b4ca04ac
PAIN_WORKTREE_COMMIT                   = eee6802806c689d7ddaac4838099674094c95214
REPROGRAM                              = NO
CONTROL_CHANGE                         = NONE
COMMAND                                = quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 30000 40000 f4j
```

## Runtime result

The corrected same-session recapture reached the bounded target:

```text
quartus_exit=0
session_elapsed_ms=31246
target_duration_ms=30000
hard_duration_ms=40000
run_end_reason=TARGET_REACHED
stop_reason=NONE
single_reader=PASS
```

Slave runtime guards remained valid: Helper locked with count 1000, PHY/link
usable, generation/reset/SI-drop stable, and no SoftPLL delock. The historical
`WR_FAILURE_REASON=3` remained `TERMINAL_CANDIDATE=1`, but the observer reported
`TERMINAL_FRESH_EDGE=0`, `TERMINAL=0`, and `TERMINAL_FRESHNESS_MODE=SESSION_EDGE`.

## Producer correlation

```text
producer_valid=33
producer_unique=17
producer_duplicates=16
update_progress=16
sample_progress=16
branch_bins=2
phase_branch=33 (17 unique)
frequency_branch=0
phase_in_band=6 (all samples)
phase_out_band=27 (all samples)
FREQ_TO_PHASE=2 (stable)
PHASE_TO_FREQ=1 (stable)
```

After deduplicating by `UPDATE_ID`, the complete 17-frame table shows:

- 15 frames with `|FREQ_ERROR| <= 50` and count held at 50 or recovered to 50.
- 2 frames with `+52: 50 -> 49` and `+60: 50 -> 49`.
- 17/17 unique frames remained in the phase branch.

Therefore the dominant behavior is acceptance of residual frequency error by
the `+/-50` frequency-lock window. The two out-of-band decrements are not the
dominant pattern in this capture and do not support hysteresis retention as the
primary cause.

## Scope boundary

This experiment only closes the diagnostic boundary. It does not change the
threshold, delock floor, Kp/Ki, timeout, detector, or control branch, and it
does not claim Step5 lock. The next step must be a single acceptance/handoff
causal candidate selected and reviewed before implementation.
