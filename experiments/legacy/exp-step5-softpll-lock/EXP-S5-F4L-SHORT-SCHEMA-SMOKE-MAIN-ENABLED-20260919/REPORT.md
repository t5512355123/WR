# EXP-S5-F4L-SHORT-SCHEMA-SMOKE-MAIN-ENABLED-20260919

## Verdict

```text
F4L_OBSERVER_START        = PASS
F4L_PAGE0                 = 1 valid frame
F4L_PAGE1                 = 0
F4L_PAGE2                 = 0
F4L_SCHEMA_SMOKE          = FAIL_STOPPED
STOP_REASON               = WR_SESSION_ENDED
STEP5                     = NOT_PASS
```

The smoke reached the Main diagnostic frame, but the WR session became
terminal before the required three-page schema could rotate. No phase-drift,
integrator, or formal lock conclusion may be drawn from this one page.

## Procedure and provenance

The smoke was started immediately after the direct runtime read in the same
Pain SSH session and without reprogramming:

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
  2400 100 "" 10000 30000 f4l
```

The F4L observer applied its fixed 10-second smoke contract and the 130-second
hard ceiling. It stopped earlier at `session_elapsed_ms=1163` because the WR
core reported terminal/session end. No control write was issued.

Raw artifact SHA-256:

```text
f9446418ce1894d48be28cc9f6f854edc29525a146343a55b4214c03e4b1dccb
```

## Evidence before the stop

The Slave produced one coherent valid page-0 frame:

```text
MAIN_F4L_VALID         = 1
TRANSPORT_COHERENT     = 1
PAGE                   = 0 (SUMMARY)
PUBLICATION_EPOCH      = 20076
SOURCE_EPOCH           = 24199166
UPDATE_ID              = 12099581
TOTAL_UPDATES          = 12099581
FREQUENCY_UPDATES      = 301033
PHASE_UPDATES          = 11798548
BRANCH_ERROR           = -5580
FREQ_ERROR             = 43
PI_OUTPUT              = 16194
```

The F4L context still showed:

```text
HELPER_LOCKED          = 1
HELPER_LOCK_COUNT      = 1000
HELPER_NORMAL_REQUEST  = 8604
HELPER_NORMAL_COMPLETED= 8604
BOOTSTRAP_DONE         = 1
PHY_LINK_USABLE        = 1
PSTAT_LINK             = 1
```

However, the WR-core context at the stop reported:

```text
TERMINAL                = 1
TERMINAL_STREAK         = 1
WR_FAILURE_REASON       = 3
WR_DISABLE_VALID        = 1
STOP_REASON             = NONE (observer-side; core terminal was the gate)
BOOT_GENERATION         = 1
CPU_RESET_COUNT         = 1
WR_CORE_RESET_COUNT     = 0
SI_CONFIG_DROP_COUNT    = 0
```

The observer therefore emitted:

```text
STEP5_F4L_ROLE_SUMMARY role=SLAVE diag_valid=1 diag_unique=1 page0=1 page1=0 page2=0
STEP5_F4L_DONE session_elapsed_ms=1163 smoke_ok=0 run_end_reason=STOP_WR_SESSION_ENDED
```

The Master had no F4L sample before the terminal stop.

## Interpretation and stop boundary

This is not evidence that the F4L page scheduler is broken: page 0 was
coherent and valid. It is also not evidence of phase lock: page 1 and page 2
were never observed, and `PSTAT_LOCKED` remained 0. The strongest supported
classification is:

```text
MAIN_F4L_PAGE0_SCHEMA       = PROVEN
F4L_PAGE_ROTATION            = NOT_OBSERVED
WR_SESSION_TERMINAL          = REPRODUCED_IN_THIS_SMOKE
PHASE_DIAGNOSTIC             = INCONCLUSIVE
```

The experiment stops here. Do not extend the smoke, rerun indefinitely, or
change PI/gain/threshold/timeout to bypass `WR_SESSION_ENDED`. The next
decision must diagnose the WR session terminal/failure-reason boundary before
another F4L formal capture.

Step5 is not pass and no merge is approved.
