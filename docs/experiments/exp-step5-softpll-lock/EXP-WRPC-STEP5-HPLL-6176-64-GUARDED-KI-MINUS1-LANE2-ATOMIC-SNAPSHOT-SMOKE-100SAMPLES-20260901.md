# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-ATOMIC-SNAPSHOT-SMOKE-100SAMPLES-20260901

Date: 2026-09-01 (Asia/Taipei)  
Branch: `exp/step5-softpll-lock`  
Lane source commit: `4eeb128`  
Report follows lane2 validation commit: `5d0adf7`  
Experiment status: `ATOMIC_SNAPSHOT_SMOKE_FAIL`

## Purpose

Run branch5's next prescribed experiment on the already validated QSFPA lane 2
path. The functional settings remain `bootstrap=6176`,
`code_per_physical_step=64`, `kp=-150`, `ki=-1`, `threshold=200`, and
`lock_samples=10000`. The purpose of this run is only to establish whether the
diagnostic-only atomic PI snapshot transport is reliable enough for a
100-sample smoke; it is not a Step5 lock claim.

## Functional and physical baseline

The WR data path remained on QSFPA lane 2 for both boards:

```text
pad_txp_o => QSFPA_TX_p(2)
pad_rxp_i => QSFPA_RX_p(2)
QSFPA_RX_p[2] = PIN_BA3
QSFPA_TX_p[2] = PIN_BB1
```

No lane, PI, DMTD, tracker, reference-clock, FINC/FDEC, manual-DCO,
sequencer, reset-tree, or RXERR-gate change was made in this experiment.

## Fresh programming and preflight

The existing lane2 Master and Slave images were fresh-programmed successfully:

```text
DE5 [1-11.1] Master: 0 errors, 0 warnings
DE5 [1-11.2] Slave:  0 errors, 0 warnings
```

The first post-program dashboard was not counted because the Slave was still
`PTP=UNCALIBRATED`. The next two dashboards passed with link up, RXERR delta 0,
and Slave `PTP=SLAVE`, including:

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
```

The required three clean post-program dashboard sequence was not completed
before the smoke was started; therefore this run is not considered a valid
Step5 dynamics experiment even aside from the smoke failure.

## Atomic PI snapshot smoke

Command parameters were 100 samples, 100 ms gap, Slave board filter. The
observer completed without a Quartus/JTAG process error, but the data failed
the branch5 acceptance thresholds:

```text
SAMPLES                       = 100
VALID_FRAMES                  = 55
INVALID_FRAMES                = 45
PI_TRACE_PRESENT              = 55
PI_TRACE_FRACTION             = 55.000%
PI_SNAPSHOT_REJECTS           = 45

SNAPSHOT_REQ_COUNT            = 95
SNAPSHOT_ACK_COUNT            = 95
SNAPSHOT_REQ_DELTA            = 94
SNAPSHOT_ACK_DELTA            = 94
ACK_MISMATCH                  = 7
```

The required smoke thresholds were therefore not met:

```text
VALID_FRAMES >= 99        : FAIL
PI_TRACE_PRESENT >= 99    : FAIL
ACK_MISMATCH = 0          : FAIL
SNAPSHOT_REQ_COUNT = 100  : FAIL
SNAPSHOT_ACK_COUNT = 100  : FAIL
```

For the accepted frames, the observer reported:

```text
MEASUREMENT_COHERENCE      = PASS
POSITION_ACCOUNTING        = PASS
TRANSACTION_ACCOUNTING    = PASS
PI_ACCOUNTING_FAILS        = 0
PI_OUTPUT_MISMATCH_FAILS   = 0
ANTI_WINDUP_VIOLATIONS     = 0
POSITION_CONTEXT_FAILS     = 0
```

However, these accepted-frame checks cannot compensate for the 45 invalid
frames and seven acknowledgement mismatches. The log also contains repeated
`PI_MATH_REJECT` records for constants, raw-error, and state comparisons. The
smoke is consequently a transport/observer validity failure, not evidence that
the closed loop has or has not locked.

Runtime stability during the sampled window was otherwise preserved:

```text
SPLL_INIT_COUNT_FIRST       = 1
SPLL_INIT_COUNT_FINAL       = 1
POST_INITIAL_SPLL_INIT_DELTA= 0
SPLL_DELOCK_COUNT_DELTA     = 0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA             = 0
RESET_WR_CORE_DELTA         = 0
RESET_SI_CONFIG_DELTA       = 0
RESET_STABLE                = PASS
HELPER_LOCKED_FINAL         = 0
HELPER_LOCK_COUNT_FINAL     = 0
PSTAT_LOCKED_FINAL          = 0
```

## Formal result

```text
LANE2_COMPILE_VALID                 = YES (prior lane2 validation)
LANE2_LINK_AVAILABLE                = YES (prior lane2 validation)
QSFPA_LANE2_PHY_VALIDATION          = PASS (prior 600-second validation)
ATOMIC_SNAPSHOT_SMOKE               = FAIL
RUNTIME_OBSERVER_PREFLIGHT          = FAIL
EXPERIMENT_VALID_FOR_STEP5          = NO
MEASUREMENT_COHERENCE               = NOT_ACCEPTED_FOR_SMOKE
KI_REDUCTION_DIRECTION_EFFECTIVE    = NOT_ADJUDICATED
STEP4B_COMPLETE                     = YES (prior valid lane2 milestone)
STEP4B_REVALIDATED_BY_THIS_RUN     = NO
STEP5_COMPLETE                      = NO
STEP5_RESULT                        = NOT_ADJUDICATED_FROM_INVALID_SMOKE
MERGE_APPROVED                      = NO
```

The 1800-second observer was intentionally not run. No control parameter was
changed in response, and no merge is authorized.

## Raw evidence

Raw logs are on pain under:

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-ATOMIC-SNAPSHOT-SMOKE-100SAMPLES-20260901/
```

The primary log is:

```text
atomic-snapshot-smoke-100.log
```

## Handoff to branch5

The next action must be selected by branch5. This run must not be used to
adjudicate `ki=-1` dynamics or Step5 lock. The immediate boundary is that the
diagnostic atomic request/ack smoke is not yet sufficiently reliable for formal
Step5 observation.
