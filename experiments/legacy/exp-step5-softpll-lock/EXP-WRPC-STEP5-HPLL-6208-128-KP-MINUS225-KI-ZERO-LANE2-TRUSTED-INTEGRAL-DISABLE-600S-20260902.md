# EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS225-KI-ZERO-LANE2-TRUSTED-INTEGRAL-DISABLE-600S-20260902

## Purpose

Run the branch5-directed integral-gain experiment at the established
bootstrap operating point. The only intended control change from the prior
`kp=-225, ki=-1` run was:

```text
ki: -1 -> 0
```

The observer was also corrected to compare the raw-error expression using the
same signed 32-bit wrap semantics as the firmware. That correction is
observability-only and does not change the hardware controller.

## Configuration and provenance

```text
branch             = exp/step5-softpll-lock
firmware source    = 42c6933
observer fix       = db627a2
board              = DE5 [1-11.2]
lane               = QSFPA lane 2
bootstrap          = 6208
code_step          = 128
kp                 = -225
ki                 = 0
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

The only firmware control change was `ki=-1 -> 0`; bootstrap, code step, kp,
PI limits, lane, and runtime procedure were held fixed. The signed-32-bit
observer correction was required because Tcl integer arithmetic is unbounded
while the firmware raw-error calculation wraps at 32 bits.

Both JTAG images were freshly built and programmed onto Slave first, then
Master:

```text
Master SOF SHA256 = 35ca5554b60f56ef74ee3c1b02618ab816ca6cff2ef19a3ba380206442a076d5
Slave SOF SHA256  = 7c059d7fdceb1bfacef01928466cbfa6c2572d052ca632bb54d0a8271dc24386
FITTER_STATUS     = Successful
TIMING_CLOSED     = NO
```

`TIMING_CLOSED=NO` remains an implementation caveat and is not being treated
as a functional Step5 result.

## Trusted preflight gate

The settled trusted preflight passed before the long run. The first post-
program preflight briefly observed Slave PTP as uncalibrated; after the
required startup settling interval, the trusted retry passed and is the gate
used for this experiment:

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
```

The retry also showed positive Slave DMTD/TAG/TRR/IRQ/helper activity,
`SPLL_MODE=3`, stable `SPLL_INIT_COUNT`, and no reset or RXERR delta. This is
therefore a valid Step5 observation window rather than a startup or transport
failure.

## Trusted 600-second result

The corrected rerun completed with valid, coherent atomic snapshots:

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
HELPER_ERROR_MEAN              = 84000.0
HELPER_ERROR_RMS               = 150000.0
HELPER_ERROR_MAX_ABS           = 150000
FRACTION_ABS_ERROR_LE_200      = 0.0%
RAW_ERROR_MEAN                 = 701862807.782
RAW_ERROR_MIN                  = -2145879395
RAW_ERROR_MAX                  = 2145873654
RAW_ERROR_POSITIVE_FRACTION    = 78.0%
UNCLAMPED_BELOW_MIN_SAMPLES    = 468
LOW_RAIL_SAMPLES               = 468 (78.000%)
HIGH_RAIL_SAMPLES              = 0 (0.000%)
NO_RAIL_FRACTION               = 22.000%
ERROR_BAND_EXIT_EVENTS         = 0
FREQ_ERROR_MEAN                = 472.803333333
FREQ_ERROR_RMS                 = 474.620016434
FREQ_ERROR_MAX_ABS             = 550
FREQ_ERROR_ZERO_CROSSINGS      = 0
RAIL_TO_RAIL_CYCLE_COMPLETE    = 0
DYNAMICS_CANDIDATE             = NO_LOCK_DYNAMIC_SIGNATURE
LOW_RAIL_SATURATION             = NO
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = NOT_CONFIRMED
CAUSALITY_CASE                 = B
```

With `ki=0`, the integral state stayed at zero and the output spent most of
the window at the lower rail. The final controller state was:

```text
PI_INTEGRATOR_BEFORE_FINAL     = 0
PI_I_NEW_FINAL                 = 0
PI_INTEGRATOR_AFTER_FINAL      = 0
PI_UNCLAMPED_FINAL             = 8245
PI_CLAMPED_FINAL               = 8245
PI_CLAMP_SIDE_FINAL            = 0
HELPER_ERROR_FINAL             = -150000
HELPER_OUTPUT_FINAL            = 8245
TARGET_FINAL                   = 8245
APPLIED_FINAL                  = 8197
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

The runtime did not show a SoftPLL restart or receiver error:

```text
SPLL_INIT_COUNT_FIRST/FINAL     = 1 / 1
POST_INITIAL_SPLL_INIT_DELTA    = 0
CLEAR_DACS_COUNT_FIRST/FINAL   = 1 / 1
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

The first ki=0 run is retained as diagnostic evidence only: it reported
`VALID_FRAMES=553`, `INVALID_FRAMES=47` because the pre-fix Tcl observer did
not apply firmware-equivalent signed 32-bit wrapping to `PI_RAW_ERROR`. The
corrected rerun above reported `VALID_FRAMES=600` and zero rejects, so the
Step5 conclusion is based only on the corrected run.

## Comparison with the prior 6208/128 runs

```text
metric                         kp=-150,ki=-1   kp=-75,ki=-1   kp=-225,ki=-1  kp=-225,ki=0
HELPER_ERROR_MEAN              76983.1867      137509.3302     74000.0885      84000.0
HELPER_ERROR_RMS               107480.8868     143619.8595     105361.5173     150000.0
NO_RAIL_FRACTION               48.667%         8.333%          50.667%         22.000%
LOW_RAIL_FRACTION              51.333%         91.667%         49.333%         78.000%
FRACTION_ABS_ERROR_LE_200      3.5%            0.0%            4.667%          0.0%
FREQ_ERROR_ZERO_CROSSINGS      75              14              74              0
HELPER_LOCK_COUNT_MAX          0               0               0               0
```

`ki=0` is effective as a hardware control change—the integral state remains
zero and the observed dynamics change—but it does not produce Helper lock or
main lock. The long-run data therefore do not satisfy the Step5 completion
criteria.

## Milestone status pending branch5 review

```text
STEP4B_COMPLETE                         = YES
STEP4B_REVALIDATED                      = YES
INTEGRAL_DISABLE_KI_ZERO_EFFECTIVE     = YES
STEP5_COMPLETE                          = NO (provisional, no lock observed)
MERGE_APPROVED                          = NO
```

The branch must not be merged until branch5 explicitly returns both
`STEP5_COMPLETE=YES` and `MERGE_APPROVED=YES`.

## Evidence

```text
trusted preflight log:
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS225-KI-ZERO-LANE2-TRUSTED-INTEGRAL-DISABLE-600S-20260902-PREFLIGHT-TRUSTED-RETRY2.log

corrected trusted 600-second rerun:
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS225-KI-ZERO-LANE2-TRUSTED-INTEGRAL-DISABLE-600S-20260902-RERUN1.log

diagnostic first run (observer arithmetic bug; excluded from verdict):
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS225-KI-ZERO-LANE2-TRUSTED-INTEGRAL-DISABLE-600S-20260902.log
```
