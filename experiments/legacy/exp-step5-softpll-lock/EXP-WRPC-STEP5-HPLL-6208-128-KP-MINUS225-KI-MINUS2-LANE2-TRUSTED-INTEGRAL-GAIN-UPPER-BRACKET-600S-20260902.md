# EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS225-KI-MINUS2-LANE2-TRUSTED-INTEGRAL-GAIN-UPPER-BRACKET-600S-20260902

## Purpose

Run the branch5-directed integral-gain upper-bracket experiment at the
established operating point. The only intended control change from the prior
`kp=-225, ki=-1` run was:

```text
ki: -1 -> -2
```

The signed-32-bit raw-error observer correction from `db627a2` was retained.
No observer arithmetic or transport behavior was changed for this run.

## Configuration and provenance

```text
branch             = exp/step5-softpll-lock
build/source HEAD  = 2087069
control change     = 4bb9cc3
observer baseline  = db627a2
board              = DE5 [1-11.2]
lane               = QSFPA lane 2
bootstrap          = 6208
code_step          = 128
kp                 = -225
ki                 = -2
shift              = 12
bias               = 5
y_min              = 5
y_max              = 65531
threshold          = 200
lock_samples       = 10000
samples            = 600
sample_gap         = 1000 ms
window             = 599 s
transport          = trusted preload-then-toggle-commit
snapshot           = one atomic frozen snapshot per sample
quartus_stp        = Intel Quartus Prime 17.0
```

The only firmware control change was `ki=-1 -> -2`; bootstrap, code step, kp,
PI limits, lane, and runtime procedure were held fixed. Both JTAG images were
freshly built and programmed onto Slave first, then Master:

```text
Master SOF SHA256 = bcc31a2343eb403cfcf3dd51ea99b153f3c6cee2d84a50de0fdcc3330d11e5e9
Slave  SOF SHA256 = daf0ddbe502c18bcc2dc2f5983dbc256e106b5ce7b08f4356e74247e8ae4d093
FITTER_STATUS     = Successful
TIMING_CLOSED     = NO
```

`TIMING_CLOSED=NO` remains an implementation caveat and is not being treated
as a functional Step5 result.

## Trusted preflight gate

The first immediate post-program preflight briefly reported the familiar
Slave upstream startup transient (`STEP4B_ALLOWED=NO`, Step2 invalid). After
startup settling, the trusted retry passed and is the gate used for this
experiment:

```text
Master Step1/Step2/Step4A       = PASS
Slave  Step1/Step2/Step3/Step4B = PASS
STEP1_REGRESSION                = PASS
STEP2_REGRESSION                = PASS
STEP3_REGRESSION                = PASS
STEP4B_ALLOWED                  = YES
STEP4B_RESULT                   = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY  = ACTIVE
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH        = TRUSTED
DMTD_REF_DECREASE_COUNT        = 0
DMTD_FB_DECREASE_COUNT         = 0
WDIAGS_RXERR delta              = 0
```

The settled retry showed positive DMTD/TAG/TRR/IRQ/helper activity, stable
SoftPLL initialization, and no reset or RXERR delta. The initial transient is
retained in the raw evidence but is not used for the long-run verdict.

## Trusted 600-second result

The run completed with valid, coherent atomic snapshots:

```text
SAMPLES                         = 600
VALID_FRAMES                   = 600
INVALID_FRAMES                 = 0
WINDOW_SECONDS                 = 599.000
PI_TRACE_PRESENT               = 600
PI_TRACE_FRACTION              = 100.000%
PI_SNAPSHOT_REJECTS            = 0
PI_ACCOUNTING_FAILS            = 0
PI_OUTPUT_MISMATCH_FAILS       = 0
ANTI_WINDUP_VIOLATIONS         = 0
POSITION_CONTEXT_FAILS         = 0
MEASUREMENT_COHERENCE          = PASS
POSITION_ACCOUNTING            = PASS
TRANSACTION_ACCOUNTING         = PASS
```

The controller dynamics were:

```text
HELPER_ERROR_SAMPLES           = 600
HELPER_ERROR_MEAN              = -41500.0
HELPER_ERROR_RMS               = 150000.0
HELPER_ERROR_MAX_ABS           = 150000
FRACTION_ABS_ERROR_LE_200      = 0.0%
RAW_ERROR_MEAN                 = -81664075.09
RAW_ERROR_MIN                  = -342912384
RAW_ERROR_MAX                  = 170323271
RAW_ERROR_POSITIVE_FRACTION    = 36.1666666667%
UNCLAMPED_BELOW_MIN_SAMPLES    = 217
LOW_RAIL_SAMPLES               = 217 (36.167%)
HIGH_RAIL_SAMPLES              = 383 (63.833%)
NO_RAIL_FRACTION               = 0.000%
ERROR_BAND_EXIT_EVENTS         = 0
FREQ_ERROR_MEAN                = 28.7316666667
FREQ_ERROR_RMS                 = 249.895408121
FREQ_ERROR_MAX_ABS             = 442
FREQ_ERROR_ZERO_CROSSINGS      = 0
RAIL_TO_RAIL_CYCLE_COMPLETE    = 0
DYNAMICS_CANDIDATE             = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT_CANDIDATE
LOW_RAIL_SATURATION             = NO
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = NOT_CONFIRMED
CAUSALITY_CASE                 = B
```

The run initially reached the high rail, later crossed to the low rail, and
finished at the low rail. The final controller state was:

```text
TARGET_FINAL                   = 5
APPLIED_FINAL                  = 5
HELPER_ERROR_FINAL             = 150000
HELPER_OUTPUT_FINAL            = 5
PI_INTEGRATOR_BEFORE_FINAL     = 33991888
PI_I_NEW_FINAL                 = 33691888
PI_INTEGRATOR_AFTER_FINAL      = 33991888
PI_UNCLAMPED_FINAL             = -9
PI_CLAMPED_FINAL               = 5
PI_CLAMP_SIDE_FINAL            = -1
```

## Lock and runtime stability

No Helper or main lock was observed:

```text
HELPER_LOCKED_EVER              = 0
HELPER_LOCKED_FINAL             = 0
HELPER_LOCK_COUNT_MAX           = 0
HELPER_LOCK_COUNT_FINAL         = 0
MAIN_ENABLED_EVER               = 0
MAIN_FREQ_LOCKED_EVER           = 0
MAIN_PHASE_LOCKED_EVER          = 0
MAIN_LOCKED_EVER                = 0
PSTAT_LOCKED_EVER               = 0
PSTAT_LOCKED_FINAL              = 0
```

The runtime remained alive without SoftPLL restart or receiver errors:

```text
SPLL_INIT_COUNT_FIRST/FINAL     = 1 / 1
SPLL_INIT_DELTA                 = 0
CLEAR_DACS_DELTA                = 0
SPLL_DELOCK_COUNT_FIRST/FINAL   = 0 / 0
BOOTSTRAP_COMPLETED_FINAL       = 6208
BOOTSTRAP_COMPLETED_DELTA       = 0
BOOTSTRAP_DONE_FINAL            = 1
BOOT_GENERATION_DELTA           = 0
CPU_RESET_DELTA                 = 0
WR_CORE_RESET_DELTA             = 0
SI_CONFIG_DROP_DELTA            = 0
RXERR_DELTA                     = 0
RESET_STABLE                    = PASS
```

## Trusted transport result

```text
SNAPSHOT_REQ_COUNT              = 600
SNAPSHOT_BANK_COMMIT_COUNT      = 600
SNAPSHOT_ACK_COUNT              = 600
SNAPSHOT_OVERWRITE_COUNT        = 0
SNAPSHOT_REQ_DELTA              = 599
SNAPSHOT_BANK_COMMIT_DELTA      = 599
SNAPSHOT_ACK_DELTA              = 599
ACK_TIMEOUT                     = 0
ACK_MISMATCH                    = 0
EPOCH_GENERATION_MISMATCH       = 0
EPOCH_CHANGED_DURING_READ      = 0
ATOMIC_SNAPSHOT_TRANSPORT_V3    = PASS
FROZEN_BANK_READ_STABILITY      = PASS
```

## Comparison with the prior integral bracket

```text
metric                         ki=0            ki=-1           ki=-2
HELPER_ERROR_MEAN              84000.0         74000.0885      -41500.0
HELPER_ERROR_RMS               150000.0        105361.5173     150000.0
NO_RAIL_FRACTION               22.000%         50.667%         0.000%
LOW_RAIL_FRACTION              78.000%         49.333%         36.167%
HIGH_RAIL_FRACTION             0.000%          0.000%          63.833%
FRACTION_ABS_ERROR_LE_200      0.0%            4.667%          0.0%
FREQ_ERROR_ZERO_CROSSINGS      0               74              0
HELPER_LOCK_COUNT_MAX          0               0               0
```

`ki=-2` was effectively applied and changed the dynamics, but it produced
rail-to-rail saturation behavior without any Helper, Main, or PSTAT lock.
Therefore it does not satisfy the Step5 completion gate.

## Milestone status pending branch5 review

```text
STEP4B_COMPLETE                         = YES
STEP4B_REVALIDATED                      = YES
INTEGRAL_GAIN_KI_MINUS2_EFFECTIVE       = NO (no lock progress)
STEP5_COMPLETE                          = NO (provisional, no lock observed)
MERGE_APPROVED                          = NO
```

The branch must not be merged until branch5 explicitly returns both
`STEP5_COMPLETE=YES` and `MERGE_APPROVED=YES`.

## Evidence

```text
trusted preflight log:
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS225-KI-MINUS2-LANE2-TRUSTED-INTEGRAL-GAIN-UPPER-BRACKET-600S-20260902-PREFLIGHT-TRUSTED-RETRY1.log

trusted 600-second run:
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS225-KI-MINUS2-LANE2-TRUSTED-INTEGRAL-GAIN-UPPER-BRACKET-600S-20260902-RUN1.log

initial transient preflight (excluded from verdict):
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS225-KI-MINUS2-LANE2-TRUSTED-INTEGRAL-GAIN-UPPER-BRACKET-600S-20260902-PREFLIGHT.log
```
