# EXP-S5-HELPER-LOCK-CONTINUITY-20260919

## Verdict

```text
HELPER_LOCK_ACQUIRED_AND_HELD = SUPPORTED_BY_VISIBLE_TAIL
DCO_TRANSACTION_PATH_ACTIVE   = YES
HELPER_ACQUISITION_OUT_OF_BAND_CONTINUOUS = NO
MAIN_START                    = NOT_CONFIRMED
F4L                           = NOT_RUN
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

## Interpretation

The previous F4L smoke stopped before a valid Main frame because Helper was not
yet locked at its sampled boundary.  This follow-up shows a later in-band,
locked Helper tail rather than a persistent lower-rail/out-of-band condition.
Because the first four Slave samples were lost by the local PTY-output
truncation, the continuity claim is intentionally limited to the visible tail.

No F4L command was started after this run, and no Step5 pass evidence was
obtained.

## Next authorized read-only boundary

Per the current advisor instruction, the next action is one direct runtime
confirmation in the same session, without reprogramming:

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
```

Only if the Slave simultaneously confirms `HELPER_LOCKED=1`,
`MAIN_ENABLED=1`, `SPLL_SEQ_STATE=SEQ_WAIT_MAIN`, stable link/reset state, and
no new terminal may a short F4L schema smoke be considered.  This report does
not claim those conditions yet.
