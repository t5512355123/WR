# EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS301-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902

## Scope

Single actuator experiment requested after the `kp=-302` trusted no-lock result.
Only the proportional gain was changed from `-302` to `-301`; `ki` and all
observer/transport parameters were held constant.

## Reproducibility

- Branch: `exp/step5-softpll-lock`
- Source commit: `d0314a2e87e5b5674bbe8ebcf7626afbb2591c0a`
- `kp=-301`, `ki=-1`
- Bootstrap completed: `6208`
- Code per physical step: `128`
- Shift: `12`
- Bias: `5`
- Output range: `5..65531`
- Lock threshold: `200`
- Lock samples: `10000`
- Lane: `2`
- Target: `DE5 [1-11.2]` (Slave)

## Build and programming provenance

Both firmware MIFs and both JTAG SOFs were rebuilt from `d0314a2` and
programmed successfully after the source change. The programming operations
reported zero errors and zero warnings.

| Artifact | SHA-256 |
|---|---|
| Slave MIF | `46ab0bc2360121d356c671267dbcbd7a68bf700ed9a39451ed7f87cb89c3a20b` |
| Master MIF | `72d8c94e64f56e3128cc855b71662b01e99ed905cc8ee53045e51f8f3fd9984f` |
| Slave SOF | `53f3585b0fc28cdbd86d2f7f5d2256fd5e3757c075a9136d9b69143c3e2e13af` |
| Master SOF | `da8a40496021e7401b1a8be7288b3f5b690f79e0d72a67bde57e11d7051d030f` |

Quartus full compilation passed for both images, but timing was not closed:

- Slave WNS: `-0.266 ns`
- Master WNS: `-0.050 ns`
- `TIMING_CLOSED=NO`

## Preflight

Raw logs are preserved on pain under
`docs/experiments/exp-step5-softpll-lock/raw/`:

- `EXP-WRPC-STEP5-KP-MINUS301-PREFLIGHT-INITIAL-20260902.log`
- `EXP-WRPC-STEP5-KP-MINUS301-PREFLIGHT-RETRY1-20260902.log`
- `EXP-WRPC-STEP5-KP-MINUS301-PREFLIGHT-RETRY2-20260902.log`
- `EXP-WRPC-STEP5-KP-MINUS301-PREFLIGHT-RETRY3-20260902.log`

The Master side consistently passed PHY/link and Step4A event-chain checks.
The Slave side did not reach the Step4B authorization gate in these fresh
program/revalidation windows:

- Step1 PHY/link: `PASS`
- Step2: transiently `INVALID`/`ERROR` on the Master because `WDIAGS_RXERR`
  increased during the measurement; settled Slave Step2 was `PASS`.
- Slave Step3: `NA`, with `WR_RX_SIGNAL_DEBUG` count `0` and `LOCK_ENABLE=0`.
- `STEP4B_ALLOWED=NO`
- `STEP4B_RESULT=BLOCKED_BY_STEP2` or `BLOCKED_BY_STEP3`
- `DMTD_REF_DECREASE_COUNT=0`
- `DMTD_FB_DECREASE_COUNT=0`
- `PRELOAD_PROTOCOL_RUNTIME_REVALIDATION=PASS`
- `JTAG_WB_DIAGNOSTIC_PATH=TRUSTED`

This means the preflight does not certify a fresh Step4B run for this
programming window. It is an upstream startup/gate observation, not evidence
that changing `kp` fixed or caused the Step3 condition.

## Observer smoke

Raw log:
`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-KP-MINUS301-OBSERVER-SMOKE-2SAMPLES-20260902.log`

- Valid frames: `2/2`
- PI snapshot rejects: `0`
- `kp=-301`, `ki=-1`
- `SPLL_INIT_COUNT=1`
- `CLEAR_DACS_COUNT=1`
- `BOOTSTRAP_COMPLETED=6208`
- `LOCK_COUNT=0`
- PI transport/accounting: pass

## Trusted 600-second observer run

Raw log:
`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS301-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-BRACKET-REFINEMENT-600S-20260902-RUN1-OBSERVER-FIXED.log`

The fixed observer completed the full window:

```text
SAMPLES=600
VALID_FRAMES=600
INVALID_FRAMES=0
WINDOW_SECONDS=599.000
PI_TRACE_PRESENT=600
PI_TRACE_FRACTION=100.000%
PI_SNAPSHOT_REJECTS=0
PI_ACCOUNTING_FAILS=0
PI_OUTPUT_MISMATCH_FAILS=0
ANTI_WINDUP_VIOLATIONS=0
HELPER_ERROR_MEAN=-29500.0
HELPER_ERROR_RMS=150000.0
RAW_ERROR_POSITIVE_FRACTION=40.1666666667%
LOW_RAIL_SAMPLES=240
LOW_RAIL_FRACTION=40.000%
HIGH_RAIL_SAMPLES=359
HIGH_RAIL_FRACTION=59.833%
NO_RAIL_FRACTION=0.167%
LOCK_COUNT_MAX=0
LOCK_COUNT_FINAL=0
ERROR_BAND_EXIT_EVENTS=0
RAIL_TO_RAIL_CYCLE_COMPLETE=0
MEASUREMENT_COHERENCE=PASS
POSITION_ACCOUNTING=PASS
TRANSACTION_ACCOUNTING=PASS
SPLL_INIT_COUNT_FIRST=1
SPLL_INIT_COUNT_FINAL=1
NORMAL_REQ_DELTA=1533
NORMAL_COMPLETED_DELTA=1533
DCO_STEP_DELTA=1533
BOOTSTRAP_COMPLETED_FINAL=6208
MAIN_ENABLED_FINAL=0
MAIN_FREQ_LOCKED_FINAL=0
MAIN_PHASE_LOCKED_FINAL=0
MAIN_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
HELPER_LOCKED_FINAL=0
SPLL_DELOCK_COUNT_DELTA=0
RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
RESET_STABLE=PASS
ATOMIC_SNAPSHOT_TRANSPORT_V3=PASS
FROZEN_BANK_READ_STABILITY=PASS
REJECT_ATTRIBUTION_COVERAGE=100.0%
```

The controller therefore ran and produced valid DCO transactions, but stayed
outside the lock band and spent most of the window at the rails. The hard
Step5 gate is `HELPER_LOCK_COUNT_MAX > 0`; that gate was not met.

## Verdict

```text
STEP4B_COMPLETE=YES                  # historical/revalidated milestone from prior trusted run
STEP4B_REVALIDATED=NO                # this fresh-program preflight was blocked upstream
KP_MINUS301_DYNAMICS_VERDICT=TRUSTED_NO_LOCK
STEP5_COMPLETE=NO
MERGE_APPROVED=NO
```

That initial window explains why the user-visible diagnostic could show Step4
as `error`/`NA`; it was an upstream startup gate failure, not a `kp` result.
The recovery and revalidation below supersede that initial gate result.

## Step4B recovery and revalidated 600-second run

Following the review of this report, the exact same programmed `kp=-301`
image was retained. No controller parameter was changed. The boards were
reprogrammed with the same SOFs, then three consecutive settled preflight
windows were collected:

- `EXP-WRPC-STEP5-KP-MINUS301-STEP4B-RECOVERY-PREFLIGHT-POSTPROGRAM2-20260902.log`
- `EXP-WRPC-STEP5-KP-MINUS301-STEP4B-RECOVERY-PREFLIGHT-POSTPROGRAM3-20260902.log`
- `EXP-WRPC-STEP5-KP-MINUS301-STEP4B-RECOVERY-PREFLIGHT-POSTPROGRAM4-20260902.log`

All three showed:

```text
Master Step1/Step2/Step4A = PASS
Slave Step1/Step2/Step3 = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
Master RXERR_DELTA = 0
Slave RXERR_DELTA = 0
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
DMTD_REF_DECREASE_COUNT = 0
DMTD_FB_DECREASE_COUNT = 0
```

The subsequent same-image 600-second run is preserved at:

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS301-KI-MINUS1-LANE2-STEP4B-RECOVERED-TRUSTED-600S-20260902-RUN2-OBSERVER-FIXED.log`

Its complete summary is:

```text
SAMPLES=600
VALID_FRAMES=600
INVALID_FRAMES=0
WINDOW_SECONDS=599.000
PI_TRACE_PRESENT=600
PI_TRACE_FRACTION=100.000%
PI_SNAPSHOT_REJECTS=0
PI_ACCOUNTING_FAILS=0
PI_OUTPUT_MISMATCH_FAILS=0
ANTI_WINDUP_VIOLATIONS=0
HELPER_ERROR_MEAN=150000.0
HELPER_ERROR_RMS=150000.0
FRACTION_ABS_ERROR_LE_200=0.0%
LOW_RAIL_SAMPLES=600
LOW_RAIL_FRACTION=100.000%
HIGH_RAIL_SAMPLES=0
NO_RAIL_FRACTION=0.000%
LOCK_COUNT_MAX=0
LOCK_COUNT_FINAL=0
ERROR_BAND_EXIT_EVENTS=0
RAIL_TO_RAIL_CYCLE_COMPLETE=0
LOW_RAIL_SATURATION=CONFIRMED
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY=CONFIRMED
FREQ_ERROR_MEAN=269.29
FREQ_ERROR_RMS=388.7668853
FREQ_ERROR_MAX_ABS=522
FREQ_ZERO_CROSSINGS=0
MEASUREMENT_COHERENCE=PASS
POSITION_ACCOUNTING=PASS
TRANSACTION_ACCOUNTING=PASS
SPLL_INIT_COUNT_FIRST=1
SPLL_INIT_COUNT_FINAL=1
NORMAL_REQ_DELTA=0
NORMAL_COMPLETED_DELTA=0
DCO_STEP_DELTA=0
FORCED_COMPLETED_DELTA=0
BOOTSTRAP_COMPLETED_FINAL=6208
MAIN_ENABLED_FINAL=0
MAIN_FREQ_LOCKED_FINAL=0
MAIN_PHASE_LOCKED_FINAL=0
MAIN_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
HELPER_LOCKED_FINAL=0
HELPER_LOCK_COUNT_FINAL=0
SPLL_DELOCK_COUNT_DELTA=0
RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
RESET_STABLE=PASS
ATOMIC_SNAPSHOT_TRANSPORT_V3=PASS
FROZEN_BANK_READ_STABILITY=PASS
REJECT_ATTRIBUTION_COVERAGE=100.0%
```

This is the milestone-valid `kp=-301` result: Step4B was revalidated, the
observer was trusted, and the controller still never entered the lock band.

The superseding verdict is:

```text
STEP4B_COMPLETE=YES
STEP4B_REVALIDATED=YES
KP_MINUS301_DYNAMICS_VERDICT=TRUSTED_NO_LOCK
STEP5_COMPLETE=NO
MERGE_APPROVED=NO
```
