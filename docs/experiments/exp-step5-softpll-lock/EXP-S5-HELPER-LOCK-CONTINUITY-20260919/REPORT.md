# EXP-S5-HELPER-LOCK-CONTINUITY-20260919

## Verdict

```text
HELPER_LOCK_ACQUIRED_AND_HELD = CONFIRMED_BY_DIRECT_RUNTIME
DCO_TRANSACTION_PATH_ACTIVE   = YES
HELPER_ACQUISITION_OUT_OF_BAND_CONTINUOUS = NO
MAIN_START                    = CONFIRMED
MAIN_FREQUENCY_LOCK           = CONFIRMED
MAIN_PHASE_LOCK               = NO
F4L_SHORT_SCHEMA_SMOKE        = PASS
F4L_FORMAL_CAPTURE            = ALLOWED_NEXT
STEP5                         = NO
```

The run reached the Helper lock state in the visible Slave tail, but the
transport wrapper truncated the streamed PTY output and the command did not
write a remote log.  The first four Slave samples are therefore not preserved
locally.  This report deliberately does not promote the result to an exact
20/20 continuity claim.

## Provenance

```text
branch                  = exp/step5-softpll-lock
programmed source       = 3a72c1992b8cea47c00abbd0f5fb9cbfd83a2987
reporting commit        = pending
path                    = QSFP-A lane0
session                 = same fresh-program session as EXP-S5-F4L-TERMINAL-FRESHNESS-20260919
reprogram in this run   = NO
reader                  = one JTAG reader
quartus                 = 17.0.0 Build 595
samples                 = 20
gap_ms                  = 500
quartus_exit            = 0
quartus_errors          = 0
quartus_warnings        = 0
direct_runtime_command  = read_wb_runtime.tcl --raw
direct_runtime_exit     = 0
direct_runtime_raw_sha256 = DDBC432EA47F5A6E17C8270EA8C32CA987BD5B2144CBDF6520003FC2FA2B803F
f4l_short_raw_sha256      = 98A4F2AE12391898398870DB3BD8F0CDAFB6488393D9B3AFF93FEC7E62F137DC
f4l_analysis_sha256       = D38465773D788665A4634B63AD8B43E57E9FBD69D8AD9DC80FCEF2D49F1D7202
```

## Observed evidence

### Master, DE5 [1-11.1]

This is not the active Helper service endpoint in this topology:

```text
LOCK_ENABLE       = 0
SPLL_STATE        = 00020004
HELPER_ERROR      = -150000
HELPER_OUTPUT     = 0x0000FFFB
STEP_DELTA        = 0 in the observed samples
BUSY              = 0 in the observed samples
ERROR             = 0 in the observed samples
```

### Slave, DE5 [1-11.2]

The visible tail (samples 5 through 20) repeatedly showed:

```text
LOCK_ENABLE       = 4
SPLL_STATE        = 00030006
HELPER_STATE      = 03E80001
HELPER_LOCKED     = 1
HELPER_LOCK_COUNT = 1000
|HELPER_ERROR|    = 14..176 in the visible tail
STEP_DELTA        = 549..589 in the visible tail
STEP_EVENT        = 1
BUSY              = 1
ERROR             = 0
```

The visible Helper errors are well inside the ±2000 lock band and the
completed-step counter continues to advance.  This is consistent with Helper
acquisition having recovered after the preceding smoke and with the DCO service
path remaining active.  It does not establish Main enabled or Main phase lock.

### Direct runtime confirmation, DE5 [1-11.2]

The subsequent one-shot direct runtime reader was run in the same session,
without reprogramming, and its complete raw output is preserved as
`raw/direct_runtime.log`:

```text
STEP1_PHY_LINK             = PASS
STEP2_ENDPOINT_PTP         = PASS
STEP3_WR_HANDSHAKE         = PASS
STEP4B_RESULT              = PASS
SPLL_STATE                 = 00030006 (SEQ_WAIT_MAIN)
HELPER_STATE              = 03E80001 (locked=1, count=1000)
HELPER_LIMITS             = 03E807D0 (threshold=2000, lock_samples=1000)
MAIN_STATE_RAW             = 06403205
MAIN_ENABLED               = 1
MAIN_LOCKED                = 0
MAIN_FREQUENCY_LOCKED     = 1
MAIN_PHASE_LOCKED         = 0
MAIN_FREQ_COUNT           = 50/50
MAIN_PHASE_COUNT          = 100/1000
PSTAT_LOCKED              = 0
BOOT_GENERATION_DELTA     = 0
CPU_RESET_COUNT_DELTA     = 0
WR_CORE_RESET_COUNT_DELTA = 0
SI_CONFIG_DROP_DELTA      = 0
WDIAGS_HELPER_UPDATE_DELTA= 23268
WDIAGS_PSTAT              = 0/1
```

This satisfies the advisor's gate for allowing a short F4L schema smoke:
Helper is locked, Main is enabled and in `SEQ_WAIT_MAIN`, frequency lock is
present, and reset/generation counters are stable.  It does **not** satisfy
Step5 because Main phase lock and PSTAT lock are still zero.

The direct reader also reports a historical WR failure-debug timeout counter
(`last_fail_state=WRS_S_LOCK`, `failure_count=35329`).  The preceding
freshness-corrected F4L smoke showed `TERMINAL=0` and no fresh terminal edge,
so this is retained as historical evidence, not treated as a new session-end
event.

### F4L short schema smoke

After the direct runtime gate, the corrected one-shot F4L command was run in
the same session without reprogramming.  The first invocation was rejected by
Tcl argument parsing before opening a reader because the remote shell lost the
empty board-filter argument; it took zero seconds and is not counted as a
hardware run.  The corrected invocation completed normally:

```text
command = read_step5_main_frequency_prelock_observability.tcl 2400 100 '' 10000 30000 f4l
quartus_exit = 0
STOP_REASON = NONE
RUN_END_REASON = TARGET_REACHED
SMOKE_OK = 1
SESSION_ELAPSED_MS = 10378
valid_frames = 11
unique_frames = 6
unique_span_ms = 9606
page0 = 3
page1 = 4
page2 = 4
schedule_valid = 0
schedule_fields = INVALID (not used for a causal claim)
TERMINAL = 0
TERMINAL_FRESH_EDGE = 0
RESET_CHANGED = 0
```

The offline analyzer completed without schema or semantic errors:

```text
classification = INCONCLUSIVE
diagnostic_pass = false
frame_count = 11
unique_count = 6
unique_span_ms = 9606
valid_time_bins_10s = 2
page_counts = {0: 3, 1: 4, 2: 4}
cycle_main_valid_count = 11
main_progress_intervals = 5
helper_unlocked_with_main_valid = 0
helper_residual_with_main_valid = 9
semantic_problems = []
step5_pass = false
```

Thus the short schema gate passed and all three pages were seen, but the
formal F4L diagnostic is not closed: its required long-window uniqueness and
time-span criteria were not met by a 10-second smoke.  The same frozen session
is eligible for the prescribed 120-second formal F4L capture; this smoke is not
Step5 evidence.

## Interpretation

The previous F4L smoke stopped before a valid Main frame because Helper was not
yet locked at its sampled boundary.  This follow-up shows a later in-band,
locked Helper tail rather than a persistent lower-rail/out-of-band condition.
Because the first four Slave samples were lost by the local PTY-output
truncation, the correlation continuity claim is intentionally limited to the
visible tail.  The direct runtime confirmation is complete and independently
preserved.

## Next authorized read-only boundary

Per the current advisor instruction, the direct runtime gate and short F4L
schema gate are now satisfied.  The next action is the prescribed formal F4L
capture in the same session, without reprogramming:

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 120000 130000 f4l
```

Stop at 120 seconds or the 130-second hard limit, and stop earlier for a
terminal freshness edge, generation/reset change, transport failure, identity
failure, or missing valid frames according to the F4L contract.  This report
still does not claim Step5 pass.
