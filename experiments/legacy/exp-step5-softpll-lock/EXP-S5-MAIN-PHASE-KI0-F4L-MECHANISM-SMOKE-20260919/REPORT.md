# EXP-S5-MAIN-PHASE-KI0-F4L-MECHANISM-SMOKE-20260919

## Verdict

```text
F4L_SCHEMA_SMOKE                 = PASS
PHASE_KI0_IMPLEMENTATION         = PASS (formal evidence)
PHASE_KI0_DIRECTION               = MIXED_NEAR_BASELINE
PHASE_KI0_CAUSAL_HYPOTHESIS      = INCONCLUSIVE
MAIN_PHASE_LOCK_OBSERVED         = NO
FRESH_TERMINAL_EDGE              = 0
CONTROL_RESULT                    = VALID_FORMAL_NO_LOCK
FORMAL_120S                       = COMPLETE (diagnostic pass)
STEP5_RESULT                      = NO
STOP_REASON                       = TARGET_REACHED_120S
```

The phase-Ki=0 mechanism behaved as intended in the formal page-1 telemetry, but the 120-second capture did not observe phase lock. Three normalized residual metrics improved slightly versus the frozen baseline, while the phase in-band ratio decreased slightly; therefore the directional result is mixed and the causal hypothesis remains inconclusive. This is not a Step5 pass.

## Provenance

```text
experiment                         EXP-S5-MAIN-PHASE-KI0-F4L-MECHANISM-SMOKE-20260919
source commit                      db7e0be12fcf1268059b916be6a21437da286fdd
prior direct-gate report commit    a4b36b53
session                            same freshly programmed Ki=0 session
Slave SOF SHA256                   fa5de2430152190f61eb54c63506103a7ce7f676b0e0945f02a1957baa65ae60
Master SOF SHA256                  7e5ef99bc74d9f8e65d147a68d28a2c47985800d7422e84eb224632034b32dee
smoke command                      read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 10000 30000 f4l
formal command                     read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 120000 130000 f4l
formal raw SHA256                  571A1795535967AE74B546A57A0E5B3AFB793D344FA33BC327338182B85A966E
formal raw                         raw/f4l_formal_ki0_120s_20260919.log
formal analysis                    analysis/f4l_formal_analysis.json
remote smoke start/end             2026-09-19 22:42:10 / 22:42:20+ (Pain)
remote formal duration             120501 ms (Pain)
```

The observer's printed `STEP5_F4L_CONFIG` retains its historical internal experiment label; this report folder is the authoritative name for this run.

## Runtime and schema result

```text
SMOKE: session_elapsed_ms         = 10214
SMOKE: valid / unique             = 11 / 6
FORMAL: session_elapsed_ms       = 120501
FORMAL: target / hard             = 120000 / 130000
FORMAL: valid / unique            = 127 / 64
FORMAL: page0/page1/page2        = 43 / 42 / 42
FORMAL: main_progress_intervals  = 63
FORMAL: valid_time_bins_10s       = 13
FORMAL: run_end_reason            = TARGET_REACHED
FORMAL: stop_reason               = NONE
FORMAL: semantic_problems         = []
```

All three F4L pages appeared throughout the formal capture, so this was a valid formal diagnostic run rather than a missing-page/schema stop. The formal analyzer classified it `DIAGNOSTIC_COMPLETE` with `diagnostic_pass=true`; the Slave Helper remained valid whenever Main telemetry was valid, with `helper_unlocked_with_main_valid=0`, and the capture showed `PHY_LINK_USABLE=1`, `PSTAT_LINK=1`, reset/generation stability, and `TERMINAL_FRESH_EDGE=0`. The historical `WR_FAILURE_REASON=3` remained an accepted session-edge baseline and did not create a fresh terminal.

## Ki=0 mechanism evidence

The formal page-1 telemetry showed sustained phase updates and the following deltas:

```text
phase_updates_delta          = 433712
phase_actual_i_sum_delta     = 0
phase_ki_x_sum_delta         = 0
frequency_updates_delta      = 0
frequency_actual_i_sum_delta = 0
frequency_ki_x_sum_delta     = 0
clamp_event_count_delta      = 0
anti_windup_event_count_delta= 0
actual_delta_mismatch_delta  = 0
```

The page-1 branch carried nonzero phase updates throughout the formal window. The frequency branch had no updates in this already-frequency-locked window, so its accounting is a zero-to-zero equality rather than evidence of nonzero frequency integration. The observed zero phase integrator terms with nonzero phase updates are the expected causal signature of the candidate: phase correction continues, but the phase branch no longer accumulates its integrator term. Therefore `PHASE_KI0_IMPLEMENTATION=PASS` at formal scope.

## Control result

The formal capture did not observe closed-loop phase lock:

```text
PSTAT_LOCKED     = 0
MAIN_PHASE_LOCKED= 0 in the direct/runtime state associated with this session
```

The formal normalized comparison against the frozen baseline is:

```text
metric                         baseline       Ki=0 candidate       result
mean phase freq error          +43.9898        +43.0381            improved 2.16%
mean phase drift magnitude      43.9854         43.0342            improved 2.16%
boundary crossing rate           0.26850%        0.26263%            improved 2.19%
phase in-band ratio             13.4393%        13.4219%            decreased 0.0174 pp
```

The first three metrics move in the desired direction, but the in-band ratio moves slightly in the undesired direction. The result is therefore `PHASE_KI0_DIRECTION=MIXED_NEAR_BASELINE`, not consistent directional support. Full arithmetic is preserved in `analysis/normalized-comparison.md` and the machine-readable analyzer output.

## Safety/stop checks

```text
Helper locked                 = 1
PHY/link                      = stable
BOOT_GENERATION delta         = 0
CPU_RESET_COUNT delta         = 0
WR_CORE_RESET_COUNT delta     = 0
SI_CONFIG_DROP_COUNT delta    = 0
fresh terminal edge           = 0
observer STOP_REASON          = NONE
```

The formal capture was allowed by the advisor and completed once in the same freshly programmed session. No reprogramming, parameter change, or automatic follow-up run occurred.

## Formal raw capture and analysis

The 120-second command was run once in the existing Pain session with stdout redirected to the Pain-side log, then copied back to this folder. The complete raw log is `raw/f4l_formal_ki0_120s_20260919.log`; its SHA256 is recorded above. The offline analyzer output is `analysis/f4l_formal_analysis.json`.

## Next action gate

Report this formal result to the phase-lock advisor and wait at least 10 minutes for his decision. Do not start a new experiment, sweep Ki, or change Kp/gain/threshold/timeout until that reply is read.
