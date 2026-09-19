# EXP-S5-MAIN-PHASE-KI0-F4L-MECHANISM-SMOKE-20260919

## Verdict

```text
F4L_SCHEMA_SMOKE                 = PASS
PHASE_KI0_IMPLEMENTATION         = PASS (smoke-level evidence)
PHASE_KI0_DIRECTION               = INCONCLUSIVE
MAIN_PHASE_LOCK_OBSERVED         = NO
FRESH_TERMINAL_EDGE              = 0
CONTROL_RESULT                    = VALID_SMOKE_NO_LOCK
FORMAL_120S                       = NOT_RUN
STEP5_RESULT                      = NO
STOP_REASON                       = TARGET_REACHED_10S
```

The phase-Ki=0 mechanism behaved as intended in the valid page-1 telemetry, but the 10-second smoke did not observe phase lock. Directional improvement versus the formal baseline is not declared from this short capture alone; the next decision is deferred to the advisor.

## Provenance

```text
experiment                         EXP-S5-MAIN-PHASE-KI0-F4L-MECHANISM-SMOKE-20260919
source commit                      db7e0be12fcf1268059b916be6a21437da286fdd
prior direct-gate report commit    a4b36b53
session                            same freshly programmed Ki=0 session
Slave SOF SHA256                   fa5de2430152190f61eb54c63506103a7ce7f676b0e0945f02a1957baa65ae60
Master SOF SHA256                  7e5ef99bc74d9f8e65d147a68d28a2c47985800d7422e84eb224632034b32dee
command                            read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 10000 30000 f4l
remote start/end                   2026-09-19 22:42:10 / 22:42:20+ (Pain)
```

The observer's printed `STEP5_F4L_CONFIG` retains its historical internal experiment label; this report folder is the authoritative name for this run.

## Runtime and schema result

```text
STEP5_F4L_DONE session_elapsed_ms = 10214
target_duration_ms                = 10000
hard_duration_ms                  = 130000
slave_cycles                      = 11
master_samples                    = 3
smoke_ok                          = 1
diag_valid                        = 11
diag_unique                       = 6
diag_duplicates                   = 5
page0/page1/page2 valid           = 4 / 3 / 4
run_end_reason                    = TARGET_REACHED
stop_reason                       = NONE
```

All three F4L pages appeared, so this was a valid mechanism smoke rather than a missing-page/schema stop. The Slave Helper remained locked in the observed cycles, `PHY_LINK_USABLE=1`, `PSTAT_LINK=1`, `RESET_CHANGED=0`, and `TERMINAL_FRESH_EDGE=0`. The historical `WR_FAILURE_REASON=3` remained as an accepted session-edge baseline and did not create a fresh terminal.

## Ki=0 mechanism evidence

The three valid page-1 integrator frames had phase updates. The captured page-1 telemetry showed:

```text
phase_actual_i_sum       = 0
phase_ki_x_sum           = 0
frequency_actual_i_sum   = frequency_ki_x_sum
clamp_event_count        = 0
anti_windup_event_count  = 0
actual_delta_mismatch    = 0
```

The page-1 branch also carried nonzero phase updates (the final valid frame reported `PHASE_UPDATES=10437218`). This is the expected causal signature of the candidate: phase correction continues, but the phase branch no longer accumulates its integrator term. Therefore the smoke-level implementation check is classified PASS.

## Control result

The smoke did not observe closed-loop phase lock:

```text
PSTAT_LOCKED     = 0
MAIN_PHASE_LOCKED= 0 in the direct/runtime state associated with this session
```

This is not yet a causal negative for the hypothesis because the advisor requires a directional comparison before deciding whether a 120-second formal capture is allowed. The short frames showed frequency errors in the tens of counts, but this report does not claim a statistically sufficient reduction in residual frequency, phase slope, boundary crossings, or in-band ratio.

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

No 120-second formal capture was started automatically.

## Raw capture note

The command was run once interactively in the existing Pain session without stdout redirection. The desktop PTY returned a truncated transcript, so `raw/f4l-smoke-summary.md` records the complete final summary and the key page-1 fields visible in the transcript; it is not presented as a byte-for-byte raw dump. No second F4L run was made to compensate.

## Next action gate

Report this result to the phase-lock advisor and wait at least 10 minutes for his decision. Do not run the 120-second formal capture or change Ki/Kp/gain/threshold/timeout until that reply is read.
