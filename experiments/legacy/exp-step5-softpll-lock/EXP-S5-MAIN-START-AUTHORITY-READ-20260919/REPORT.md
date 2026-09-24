# EXP-S5-MAIN-START-AUTHORITY-READ-20260919

## Verdict

```text
READ_WB_RUNTIME             = PASS
JTAG_WB_TRANSPORT           = TRUSTED
QSFP_A_LANE0_LINK           = PASS
HELPER_ACQUISITION          = PASS
MAIN_START                  = PASS
MAIN_FREQUENCY_ACQUISITION  = ACTIVE
MAIN_PHASE_LOCK             = NOT_LOCKED
STEP5                       = NOT_PASS
```

This read establishes the missing Main-start fact. It does not establish
closed-loop phase lock.

## Procedure and provenance

The capture was run on the already programmed QSFP-A lane-0 session. No new
SOF was programmed; the c7311648 build artifacts were not used. The existing
read-only dashboard was executed from the Pain worktree:

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
source/observer worktree = EXP-S5-HELPER-STARTUP-RAIL-DIAGNOSTIC-LANE0-20260919
quartus_stp rc            = 0
WB requests               = 352
WB 3-way coherent matches = 352
WB timeouts/invalids      = 0/0
```

Raw artifact SHA-256:

```text
d7460a21425e6033d5ecc651c0f6894c03e29bda3ce24ae9e315a80bf303c0d7
```

## Slave direct state: DE5 [1-11.2]

The upstream and Step4B gates were active:

```text
CORE_TM_LINK_UP       = 1
CORE_LINK_OK          = 1
WR_RX_READY           = 1
WR_TX_READY           = 1
PHY_LINK_USABLE       = 1
PSTAT_LINK            = 1
STEP4B_ALLOWED        = YES
STEP4B_RESULT         = PASS
```

The direct SoftPLL state was:

```text
SPLL_SEQ_STATE         = 6 (SEQ_WAIT_MAIN)
HELPER locked          = 1
HELPER lock count      = 1000/1000
HELPER threshold       = 2000
HELPER lock samples    = 1000
MAIN enabled           = 1
MAIN locked            = 0
MAIN frequency locked  = 1
MAIN phase locked      = 0
MAIN frequency count   = 49..50/50
MAIN phase count       = 100/1000
PSTAT locked           = 0
```

The same session remained stable during the dashboard window:

```text
BOOT_GENERATION Δ      = 0
CPU_RESET_COUNT Δ      = 0
WR_CORE_RESET_COUNT Δ  = 0
SI_CONFIG_DROP_COUNT Δ = 0
RXERR Δ                = 0
```

Therefore the previous Helper/DCO boundary is closed and the current
boundary is Main phase acquisition. The observer's final dashboard line is
`STEP5_RESULT = NEVER_LOCKED` with `STEP5_FIRST_INACTIVE_BOUNDARY =
MAIN_PHASE_LOCK`; this is the correct result for a single diagnostic window,
not a Step5 failure classification beyond the observed phase-lock state.

## Master direct state: DE5 [1-11.1]

Master link and transport checks passed. Step5 lock-detector fields are not
applicable to the Master endpoint in this image; the dashboard reported
`STEP5_RESULT = NOT_APPLICABLE_MASTER`.

## Next action allowed by the diagnostic boundary

Because Helper is locked, Main is enabled, link is usable, and reset/generation
are stable, the next action was a short passive F4L schema smoke in the same
session. Its result is recorded separately in
`EXP-S5-F4L-SHORT-SCHEMA-SMOKE-MAIN-ENABLED-20260919`.

Step5 is not pass.
