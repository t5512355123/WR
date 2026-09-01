# EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS225-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-BRACKET-600S-20260902

## Purpose

Run the branch5-directed proportional-gain upper-bracket experiment at the
established bootstrap operating point. The only intended control change from
the previous `kp=-150` baseline was:

```text
kp: -150 -> -225
```

The hardware PI coefficient and the read-only observer expectation were both
updated to `-225`, then the JTAG runtime image was freshly built and
programmed onto both boards.

## Configuration and provenance

```text
branch       = exp/step5-softpll-lock
source HEAD  = 901129e
board        = DE5 [1-11.2]
lane         = QSFPA lane 2
bootstrap    = 6208
code_step    = 128
kp           = -225
ki           = -1
shift        = 12
bias         = 5
y_min        = 5
y_max        = 65531
threshold    = 200
lock_samples = 10000
samples      = 600
sample_gap   = 1000 ms
window       = 599 s
transport    = trusted preload-then-toggle-commit
snapshot     = one atomic frozen snapshot per sample
quartus_stp  = Intel Quartus Prime 17.0
```

The source and observer changes are confined to the proportional-gain
experiment. Both JTAG images were built from the same source HEAD and
fresh-programmed Slave first, then Master:

```text
Master SOF SHA256 = 35ca5554b60f56ef74ee3c1b02618ab816ca6cff2ef19a3ba380206442a076d5
Slave SOF SHA256  = 7c059d7fdceb1bfacef01928466cbfa6c2572d052ca632bb54d0a8271dc24386
FITTER_STATUS     = Successful
TIMING_CLOSED     = NO
```

`TIMING_CLOSED=NO` remains an implementation caveat; it is unchanged from the
previous experiment and is not being treated as a functional Step5 result.

## Trusted preflight gate

The settled trusted preflight passed before the long run:

```text
Master Step1/Step2/Step4A = PASS
Slave  Step1/Step2/Step3/Step4B = PASS
STEP1_REGRESSION          = PASS
STEP2_REGRESSION          = PASS
STEP3_REGRESSION          = PASS
STEP4B_ALLOWED            = YES
STEP4B_RESULT             = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH   = TRUSTED
```

The preflight also showed positive Slave DMTD/TAG/TRR/IRQ/helper activity,
`SPLL_MODE=3`, `SPLL_SEQ_STATE=4`, `SPLL_INIT_COUNT=1`, and no reset or RXERR
delta. Therefore this run is a valid Step5 observation window rather than a
transport or startup diagnostic failure.

## Trusted 600-second result

The complete window finished with valid, coherent atomic snapshots:

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
HELPER_ERROR_MEAN              = 74000.0885
HELPER_ERROR_RMS               = 105361.517264
HELPER_ERROR_MAX_ABS           = 150000
FRACTION_ABS_ERROR_LE_200      = 4.66666666667%
RAW_ERROR_MEAN                 = 219322987.767
RAW_ERROR_MIN                  = -3186
RAW_ERROR_MAX                  = 888297585
RAW_ERROR_POSITIVE_FRACTION    = 73.5%
UNCLAMPED_BELOW_MIN_SAMPLES    = 296
LOW_RAIL_SAMPLES               = 296 (49.333%)
HIGH_RAIL_SAMPLES              = 0 (0.000%)
NO_RAIL_FRACTION               = 50.667%
ERROR_BAND_EXIT_EVENTS         = 24
FREQ_ERROR_MEAN                = 235.39
FREQ_ERROR_RMS                 = 335.18087067173
FREQ_ERROR_MAX_ABS             = 505
FREQ_ERROR_ZERO_CROSSINGS      = 74
RAIL_TO_RAIL_CYCLE_COMPLETE    = 0
DYNAMICS_CANDIDATE             = UNDERDAMPED_OR_OVERAGGRESSIVE_CANDIDATE
LOW_RAIL_SATURATION             = NO
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = NOT_CONFIRMED
CAUSALITY_CASE                 = B
```

The run entered low-rail saturation during the window. At the end of the
window, `HELPER_OUTPUT=5`, `HELPER_ERROR=150000`, and the PI output remained
clamped at the lower limit. This is a control-dynamics failure, not a JTAG
observer failure.

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
```

The runtime remained alive and did not restart:

```text
SPLL_INIT_COUNT first/final     = 1 / 1
POST_INITIAL_SPLL_INIT_DELTA    = 0
CLEAR_DACS_COUNT first/final    = 1 / 1
CLEAR_DACS_DELTA                = 0
SPLL_DELOCK_COUNT first/final   = 0 / 0
BOOTSTRAP_COMPLETED_FINAL       = 6208
BOOTSTRAP_COMPLETED_DELTA       = 0
BOOTSTRAP_DONE_FINAL            = 1
BOOT_GENERATION delta            = 0
CPU reset delta                  = 0
WR-core reset delta              = 0
SI_CONFIG drop delta             = 0
RXERR delta                      = 0
RESET_STABLE                     = PASS
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
EPOCH_CHANGED_DURING_READ       = 0
ATOMIC_SNAPSHOT_TRANSPORT_V3    = PASS
```

The frozen-bank audit also reported 600 valid transactions, 600 valid PI math
checks, no word-for-word or math mismatch, and
`FROZEN_BANK_READ_STABILITY=PASS`.

## Comparison with the prior 6208/128 runs

```text
metric                         kp=-150          kp=-75           kp=-225
HELPER_ERROR_MEAN              76983.1866667    137509.3301667   74000.0885
HELPER_ERROR_RMS               107480.886829    143619.859481    105361.517264
NO_RAIL_FRACTION               48.667%          8.333%           50.667%
LOW_RAIL_FRACTION              51.333%          91.667%          49.333%
FRACTION_ABS_ERROR_LE_200      3.5%             0.0%             4.667%
FREQ_ERROR_ZERO_CROSSINGS      75               14               74
HELPER_LOCK_COUNT_MAX          0                0                0
```

`kp=-225` is effective as a hardware change—the observer sees the matching
coefficient and the dynamics differ—but it does not produce Helper lock or
main lock. The long-run data therefore do not satisfy the Step5 completion
criteria.

## Milestone status pending branch5 review

```text
STEP4B_COMPLETE                    = YES
STEP4B_REVALIDATED                 = YES
PROPORTIONAL_GAIN_KP_MINUS225_EFFECTIVE = YES
STEP5_COMPLETE                     = NO (provisional, no lock observed)
MERGE_APPROVED                     = NO
```

The branch must not be merged until branch5 explicitly returns both
`STEP5_COMPLETE=YES` and `MERGE_APPROVED=YES`.

## Evidence

```text
remote preflight log:
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS225-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-BRACKET-600S-20260902-PREFLIGHT-TRUSTED-RETRY1.log

remote 600-second log:
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS225-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-BRACKET-600S-20260902.log
```
