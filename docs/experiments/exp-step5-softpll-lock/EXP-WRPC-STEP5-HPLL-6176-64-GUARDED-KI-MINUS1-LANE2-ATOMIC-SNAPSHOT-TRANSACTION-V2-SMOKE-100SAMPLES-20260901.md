# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-ATOMIC-SNAPSHOT-TRANSACTION-V2-SMOKE-100SAMPLES-20260901

Date: 2026-09-01

Branch: `exp/step5-softpll-lock`

HEAD: `65ff11b` (`exp: serialize atomic PI snapshot transport v2`)

Board: `DE5 [1-11.2]` (Slave)

## Purpose

Validate the diagnostic-only V2 transport proposed by branch5 after the
previous atomic snapshot smoke failed.  The V2 transaction is intended to be

```text
REQ_SEQ=N -> frozen PI bank -> BANK_SEQ=N -> ACK_SEQ=N
```

The firmware changes add request, bank-commit, ACK, overwrite, and sequence
breadcrumbs.  The JTAG observer permits only one outstanding request and
accepts a frame only when the request, bank, and ACK generations agree before
and after the complete payload read.

The existing lane-2 routing and all Step5 control parameters were retained:

```text
bootstrap_steps       = 6176
code_per_physical_step= 64
kp                    = -150
ki                    = -1
threshold             = 200
lock_samples          = 10000
```

No PI, DMTD, tracker, P_SETPOINT, Finc/Fdec, manual DCO, Main PLL,
sequencer, reset, or functional VUART changes were made.

## Build and program

Both fresh JTAG images built successfully on pain:

```text
Master: DE5a_wr_master_jtag.sof, timing_closed=NO
Slave : DE5a_wr_slave_jtag.sof,  timing_closed=NO
```

Both devices were programmed successfully with Quartus Programmer, with
`0 errors, 0 warnings` and `1 device(s) configured` for each cable.

## Fresh-program preflight

The first post-program dashboard was not counted because the Slave was still
`WDIAGS_PTP=8 UNCALIBRATED`, so Step2/Step4B were correctly reported as NA.
Another intermediate dashboard also showed the Step4B event-processing
counter boundary as not proven.  After the board settled, three consecutive
clean dashboards were obtained (preflight runs 5, 6, and 7):

```text
DE5 [1-11.2] WDIAGS_PTP          = 9 SLAVE
Step 1                           = pass
Step 2                           = pass
Step 3                           = pass
STEP4B_RESULT                    = PASS
DMTD_ACCEPT / TAG / TRR / IRQ   = increasing
WDIAGS_HELPER_UPDATE_COUNT      = increasing
BOOT/CPU/WR/SI reset deltas      = 0 / 0 / 0 / 0
```

## V2 100-sample smoke result

Command:

```text
quartus_stp -t scripts/jtag/read_step5_helper_pi_state_rail_audit.tcl 100 100 "DE5 [1-11.2]"
```

Observed summary:

```text
SAMPLES                         = 100
VALID_FRAMES                    = 64
INVALID_FRAMES                  = 36
PI_TRACE_PRESENT                = 64
PI_SNAPSHOT_REJECTS             = 36
ACK_MISMATCH                    = 12

SNAPSHOT_REQ_COUNT              = 92
SNAPSHOT_BANK_COMMIT_COUNT      = 92
SNAPSHOT_ACK_COUNT              = 100
SNAPSHOT_OVERWRITE_COUNT        = 0
SNAPSHOT_REQ_DELTA              = 91
SNAPSHOT_BANK_COMMIT_DELTA      = 91
SNAPSHOT_ACK_DELTA              = 99
SNAPSHOT_OVERWRITE_DELTA        = 0
LAST_REQ_SEQ                    = 100
LAST_BANK_SEQ                   = 10092
LAST_ACK_SEQ                    = 100
ATOMIC_SNAPSHOT_TRANSPORT_V2    = FAIL
```

The accepted frames themselves retained the expected passive evidence:

```text
MEASUREMENT_COHERENCE            = PASS
POSITION_ACCOUNTING              = PASS
TRANSACTION_ACCOUNTING           = PASS
POST_INITIAL_SPLL_INIT_DELTA     = 0
CLEAR_DACS_DELTA                 = 0
RESET_STABLE                     = PASS
```

However, the transport acceptance requirements were not met: valid frames are
below 99, ACK mismatch is nonzero, request and bank-commit deltas are below
100, and the final bank sequence is not equal to the final ACK/request
sequence.  The last sequence value is retained as observed evidence, not
interpreted as a valid frame.

## Formal status

```text
STEP4B_COMPLETE                  = YES (preflight gate only)
ATOMIC_SNAPSHOT_TRANSPORT_V2     = FAIL
ATOMIC_SNAPSHOT_SMOKE             = FAIL
RUNTIME_OBSERVER_PREFLIGHT        = PASS (three consecutive clean runs)
EXPERIMENT_VALID_FOR_STEP5        = NO
STEP5_COMPLETE                    = NO
MERGE_APPROVED                    = NO
```

No 1800-second Step5 run was started.  No merge was performed.

## Next decision boundary

Ask branch5 to inspect this V2 result and define the next diagnostic-only
transport correction.  Do not change the Step5 control law or merge `main`
until a later run satisfies the complete Step5 criteria and branch5 explicitly
sets `MERGE_APPROVED=YES`.
