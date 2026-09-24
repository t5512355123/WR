# EXP-S5-MAIN-FREQ-THRESH20-F4J-AUDIT-20260920

## Verdict

```text
F4J_THRESH20_AUDIT          = VALID
THRESH20_IMPLEMENTATION     = PASS
HELPER_LOCKED               = PASS
MAIN_ENABLED                = PASS
MAIN_FREQ_LOCKED            = 0
MAIN_PHASE_LOCKED           = 0
MAIN_FREQUENCY_BRANCH_REENTRY = NOT_OBSERVED
FREQ_ACCEPTANCE_VS_HYSTERESIS = MIXED
THRESH20_CAUSAL_RESULT      = NOT_YET_CLOSED
STEP5                       = NO
```

The threshold20 candidate reached a valid Main producer operating state and
the observer completed the full 30-second window.  The new acceptance boundary
was visible in the producer frames, but the bounded audit still showed only
phase-branch frames and no phase lock.  Therefore this is valid causal evidence
that threshold20 is being applied, not a Step5 pass and not sufficient evidence
to declare the root cause closed.

## Provenance and scope

```text
FPGA/control source commit = 165d25ae29eba4a8265c75b66d33a0c55ce2e2c4
experiment plan commit     = e6c30876
observer implementation    = b4ca04ac (SESSION_EDGE freshness)
observer worktree at run   = e6c3087664ecbe563893b316b3d43b5b4e6536f7
Slave SOF SHA256           = 964891814cead5b8d2ef67ad301826d1c5fdc586341cfd30a6f4500f39693328
Master SOF SHA256          = 7c7fa79ae41018c0ec65b871d58faad7c903401e43b40a2b968b4d50598477c1
```

No rebuild, reprogramming, production-control modification, parameter change,
or F4J control write was made for this audit.  The observer was read-only and
used one reader process.

## Capture validity

Command:

```text
read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 30000 40000 f4j
```

```text
quartus_exit                  = 0
target_duration_ms            = 30000
session_elapsed_ms            = 31085
run_end_reason                = TARGET_REACHED
stop_reason                   = NONE
producer_valid                = 33
producer_unique               = 17
producer_duplicates           = 16
update_progress               = 16
sample_progress               = 16
```

Raw file:

```text
raw/observe/f4j_threshold20_audit.log
SHA256 = 726e9b94b6aa7fd1f50ccd437120a5aad7624a66fc7d06bd7a451b6658b486b5
```

All validity guards remained good during the capture:

```text
MAIN_PRODUCER_VALID       = 1 for valid frames
PUBLICATION_COHERENT      = 1
HELPER_LOCKED             = 1
HELPER_LOCK_COUNT         = 1000
PHY_LINK_USABLE           = 1
PSTAT_LINK                = 1
PSTAT_LOCKED              = 0
TERMINAL                  = 0
TERMINAL_FRESH_EDGE       = 0
TERMINAL_FRESHNESS_MODE   = SESSION_EDGE
STOP_REASON               = NONE
BOOT_GENERATION           = 1, unchanged
CPU_RESET_COUNT           = 1, unchanged
WR_CORE_RESET_COUNT       = 0, unchanged
SI_CONFIG_DROP_COUNT      = 0, unchanged
RXERR                     = 0 delta
DCO_ERROR                 = 0 in observed service reads
```

The historical `WR_FAILURE_REASON=3` remained sticky, but no fresh terminal
edge occurred, so it did not invalidate this capture.

## Slave Main producer analysis

Only coherent unique Slave producer frames were analyzed.  The 17 unique
frames were:

```text
all BRANCH_ID = 2 (PHASE)
frequency branch = 0
phase branch     = 17
FREQ_TO_PHASE    = 6 (unchanged in the captured frames)
PHASE_TO_FREQ    = 5 (unchanged in the captured frames)
```

The exact unique-frame classification was:

| class | rule | count |
|---|---|---:|
| threshold20 in-band / accepted-like | `|FREQ_ERROR| <= 20` and counter held or recovered | 10 |
| threshold20 out-of-band decrement | `|FREQ_ERROR| > 20` and counter decreased | 7 |
| frequency-branch frames | `BRANCH_ID = FREQUENCY` | 0 |
| phase-branch frames | `BRANCH_ID = PHASE` | 17 |

Representative unique values included:

```text
 +8 : 50 -> 50
 +1 : 49 -> 50
 +27: 50 -> 49
 +21: 50 -> 49
 +28: 48 -> 47
 -25: 49 -> 48
 -17: 50 -> 50
  -3: 49 -> 50
  -9: 50 -> 50
 +23: 50 -> 49
 +17: 50 -> 50
  -8: 49 -> 50
```

The candidate therefore visibly applies the narrower acceptance boundary: errors
outside `+-20` produce counter decrements, while many errors inside `+-20`
remain accepted/recovering.  However, the branch decision stayed PHASE for all
17 unique frames, and no new frequency-branch reentry was observed during the
window.  `PSTAT_LOCKED` also remained 0.

## Interpretation

This result is best classified as:

```text
THRESH20_BOUNDARY_EFFECT       = OBSERVED
ACCEPTANCE_BEHAVIOR             = PRESENT (10/17)
OUT_OF_BAND_COUNTER_RESPONSE    = PRESENT (7/17)
ACCEPTANCE_VS_HYSTERESIS        = MIXED
MAIN_FREQUENCY_BRANCH_REENTRY   = NOT_OBSERVED
PHASE_LOCK                      = NOT_OBSERVED
```

Relative to the earlier threshold50 producer audit, threshold20 changes the
count response for the observed residual errors, but this bounded run does not
show that changing the acceptance threshold alone is sufficient to return the
controller to frequency acquisition or close phase.  Because this is a
different live window rather than a simultaneous A/B capture, the result is
not over-interpreted as a complete rejection of the wider acceptance-policy
hypothesis; it closes only the implementation and immediate operating-state
questions.

## Stop and next boundary

This single F4J capture is complete and must not be repeated in this round.
No Step5 pass is claimed.  No additional parameter, gain, timeout, detector,
or handoff change is authorized from this result alone.  The next action must
be selected after review of this report and the unique-frame evidence.

