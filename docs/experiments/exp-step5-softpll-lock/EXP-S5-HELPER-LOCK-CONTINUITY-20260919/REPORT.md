# EXP-S5-HELPER-LOCK-CONTINUITY-20260919

## Verdict

```text
HELPER_LOCK_ACQUIRED_AND_HELD = CONFIRMED_BY_DIRECT_RUNTIME
DCO_TRANSACTION_PATH_ACTIVE   = YES
HELPER_ACQUISITION_OUT_OF_BAND_CONTINUOUS = NO
MAIN_START                    = CONFIRMED
MAIN_FREQUENCY_LOCK           = CONFIRMED
MAIN_PHASE_LOCK               = NO
F4L_SHORT_SCHEMA_SMOKE        = ALLOWED_NEXT
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

## Interpretation

The previous F4L smoke stopped before a valid Main frame because Helper was not
yet locked at its sampled boundary.  This follow-up shows a later in-band,
locked Helper tail rather than a persistent lower-rail/out-of-band condition.
Because the first four Slave samples were lost by the local PTY-output
truncation, the correlation continuity claim is intentionally limited to the
visible tail.  The direct runtime confirmation is complete and independently
preserved.

## Next authorized read-only boundary

Per the current advisor instruction, the direct runtime gate is now satisfied.
The next action is one short F4L schema smoke in the same session, without
reprogramming:

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 10000 30000 f4l
```

Stop after the short smoke according to the existing F4L stop rules.  Do not
extend it to formal 120 seconds unless all three pages are observed with
coherent, same-generation frames.  This report still does not claim Step5
pass.
