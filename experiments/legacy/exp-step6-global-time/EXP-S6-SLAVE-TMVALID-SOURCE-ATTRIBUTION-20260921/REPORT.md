# EXP-S6-SLAVE-TMVALID-SOURCE-ATTRIBUTION-20260921

## Verdict

```text
TMVALID_ATTRIBUTION       = PASS
MASTER_REFERENCE          = PASS
SLAVE_FAILURE_CLASS       = FAIL_PTP_SERVO_NOT_COMPLETE
STEP6A_SLAVE_GLOBAL_TIME  = NOT_PASS
STEP6A_RESULT             = BLOCKED_BY_SLAVE_SERVO
STEP6B_SCHEDULED_TRIGGER  = NOT_RUN
POWER_CYCLE               = NOT_PERFORMED
FPGA_PROGRAMMING          = NOT_PERFORMED
```

This experiment intentionally preserved the already-programmed Step6A image
and the observed Slave failure state.  It was a read-only attribution run,
not a new FPGA build or programming run.

## Provenance

| Item | Value |
| --- | --- |
| Laptop/Pain observer commit | `7c704b23` |
| Existing programmed image | Step6A image from `ec1f25e8` |
| Branch | `exp/step6-Global-Time-Testing` |
| Quartus | Prime 17.0 Build 595 |
| Master cable | `DE5 [1-11.1]` |
| Slave cable | `DE5 [1-11.2]` |
| Capture | 1 Hz target, maximum 180 s; early-stop rules enabled |
| Raw SHA-256 | `218CB8564900374A125CCF8F8BF0990148D88A230A93DB3E7C4EE32A0AC9DE96` |
| Raw line count | 199 |

## What was measured

Every row correlated the two different validity layers in one read session:

```text
PPS_ESCR bit 3  = ESCR_TM_VALID
status bit 4    = STATUS_TIME_VALID
WDIAGS_PTP      = PTP state
WDIAGS_SSTAT    = servo state [11:8]
WDIAGS_UCNT     = servo/update activity
PSTAT / SoftPLL = existing Step5 context
boot/reset      = persistent reset evidence
TAI/cycles      = live and frozen Step6 evidence
```

The WB transport was trusted for the complete capture:

```text
TIMEOUT_COUNT    = 0
INVALID_COUNT    = 0
STALE_COUNT      = 0
UNSTABLE_COUNT   = 0
```

## Master result

Master `[1-11.1]` ran to the 180-second time limit with 153 valid sample
rows.  It remained link-healthy and showed:

```text
PTP_STATE                 = 6 (MASTER)
ESCR_TM_VALID             = 1
STATUS_TIME_VALID         = 1
STATUS_PPS_VALID          = 1
SNAPSHOT_COUNT delta      = 180
BOOT_CHANGED              = 0
RESET_CHANGED             = 0
```

This satisfies the Master reference condition for this attribution trace.
The Master's current SoftPLL diagnostic fields were not asserted in this
session; that is not used to turn this diagnostic into a Step5 or full Step6A
claim.

## Slave result

Slave `[1-11.2]` met the upstream link and existing Step5 context, but the
valid-time chain stopped before the timing-output valid bit:

```text
LINK_HEALTHY              = 1
PTP_STATE                 = 9 (SLAVE)
SERVO_STATE               = 0 (not TRACK_PHASE=4)
ESCR_TM_VALID             = 0
STATUS_TIME_VALID         = 0
STATUS_PPS_VALID          = 0 or 1 during polling
STEP5_LOCKED              = 1
BOOT_CHANGED              = 0
RESET_CHANGED             = 0
SNAPSHOT_COUNT delta      = 0
```

The observer reached ten consecutive samples with `PTP_STATE=9`, healthy
link, `ESCR_TM_VALID=0`, `STATUS_TIME_VALID=0`, and servo state not equal to
`TRACK_PHASE`.  It stopped with:

```text
STOP_CANDIDATE = FAIL_PTP_SERVO_NOT_COMPLETE
```

## Causal boundary

This run rules out the following explanations for the captured state:

- JTAG/Wishbone transport failure: all transport counters were zero.
- A simple exported-bit mapping mismatch: source `ESCR_TM_VALID` and exported
  `STATUS_TIME_VALID` were both zero.
- Reset/re-initialization during the observation: boot and reset evidence did
  not change.
- A Step5 lock loss on the Slave: the four existing lock context fields stayed
  asserted in the captured rows.

The strongest supported classification is therefore:

```text
SLAVE_WR_SERVO_NOT_TRACKING_PHASE
TM_VALID_NOT_ASSERTED_BECAUSE_SERVO_PROGRESS_NOT_COMPLETE
```

This is not yet evidence that `enable_timing_output(1)` is broken.  That
diagnostic branch is only eligible after the Slave reaches `SERVO_STATE=4`
with active `UCNT` and still leaves `ESCR_TM_VALID=0` for ten samples.

## Next boundary

Do not implement the Step6B trigger yet.  The next experiment must first
preserve the same control image and determine why the Slave remains at
`SERVO_STATE=0` despite `PTP_STATE=9`; no PI/gain/timeout/PHY/RTL change is
justified by this capture alone.

## Files

```text
PLAN.md
REPORT.md
analysis/summary.json
raw/tmvalid-180s.log
raw/SHA256SUMS.txt
```
