# EXP-WRPC-STEP5-LANE2-JTAG-WB-PRELOAD-PROTOCOL-STEP4B-PREFLIGHT-REVALIDATION-3X-20260901

## Purpose and scope

This experiment revalidates the Step4B runtime observer after the generic
JTAG/Wishbone read-path audit established that a preload-then-toggle-commit
protocol removes the previous-address response replay. The only functional
change in this experiment is observer transport: every Wishbone read now
preloads the address/data bundle with the existing completion toggle, waits
2 ms, and then commits the identical bundle by changing only the toggle.
Completion is accepted only after three identical full 64-bit probe reads.

No RTL, firmware, PI equation, control parameter, build output, or FPGA
programming image was changed. No V4 snapshot smoke was run.

Branch:

```text
exp/step5-softpll-lock
```

Observer commit used on pain:

```text
41455ed
```

Hardware and controls:

```text
Master = DE5 [1-11.1]
Slave  = DE5 [1-11.2]
QSFPA lane = 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

Raw logs captured on pain:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-LANE2-JTAG-WB-PRELOAD-PROTOCOL-STEP4B-PREFLIGHT-REVALIDATION-3X-20260901-PREFLIGHT-1.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-LANE2-JTAG-WB-PRELOAD-PROTOCOL-STEP4B-PREFLIGHT-REVALIDATION-3X-20260901-PREFLIGHT-2.log
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-LANE2-JTAG-WB-PRELOAD-PROTOCOL-STEP4B-PREFLIGHT-REVALIDATION-3X-20260901-PREFLIGHT-3.log
```

## Transport result

All three preflights produced the same transport-health result:

```text
WB_TRANSPORT_PROTOCOL = PRELOAD_THEN_TOGGLE_COMMIT
WB_REQUEST_COUNT = 352
PRELOAD_COUNT = 352
COMMIT_COUNT = 352
WB_PROBE_READ_COUNT = 1760
PRELOAD_UNEXPECTED_TRIGGER_COUNT = 0
PROBE_3WAY_MATCH_COUNT = 352
STABLE_RESPONSE_WRONG_COUNT = 0
ADDRESS_CROSS_CONTAMINATION_COUNT = 0
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
STALE_A5A5_COUNT = 0
UNSTABLE_TRANSACTION_COUNT = 0
DMTD_REF_DECREASE_COUNT = 0
DMTD_FB_DECREASE_COUNT = 0
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

The 352 transactions cover the complete Master and Slave before/after
runtime snapshots. The three preflight runs were performed on the same live
image with a short interval between runs and no intervening programming.

## Preflight 1

```text
Master: Step1 PASS, Step2 PASS, Step4A PASS
Slave:  Step1 PASS, Step2 PASS, Step3 PASS, Step4B PASS

Slave DMTD_REF delta = +22792
Slave DMTD_FB delta  = +24233
Slave DMTD_ACCEPT delta = +47025
Slave TAG delta = +47033
Slave TRR_WRITE delta = +47037
Slave TRR_POP delta = +47357
Slave IRQ delta = +46388
Slave HELPER_UPDATE delta = +22576

BOOT_GENERATION delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
SI_CONFIG_DROP_COUNT delta = 0

Step5: NEVER_LOCKED; first inactive boundary = HELPER_LOCK
```

## Preflight 2

```text
Master: Step1 PASS, Step2 PASS, Step4A PASS
Slave:  Step1 PASS, Step2 PASS, Step3 PASS, Step4B PASS

Slave DMTD_REF delta = +22799
Slave DMTD_FB delta  = +24243
Slave DMTD_ACCEPT delta = +47042
Slave TAG delta = +47058
Slave TRR_WRITE delta = +47061
Slave TRR_POP delta = +47352
Slave IRQ delta = +46392
Slave HELPER_UPDATE delta = +22951

BOOT_GENERATION delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
SI_CONFIG_DROP_COUNT delta = 0

Step5: NEVER_LOCKED; first inactive boundary = HELPER_LOCK
```

## Preflight 3

```text
Master: Step1 PASS, Step2 PASS, Step4A PASS
Slave:  Step1 PASS, Step2 PASS, Step3 PASS, Step4B PASS

Slave DMTD_REF delta = +22675
Slave DMTD_FB delta  = +24113
Slave DMTD_ACCEPT delta = +46788
Slave TAG delta = +46790
Slave TRR_WRITE delta = +46791
Slave TRR_POP delta = +46586
Slave IRQ delta = +45619
Slave HELPER_UPDATE delta = +22578

BOOT_GENERATION delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
SI_CONFIG_DROP_COUNT delta = 0

Step5: NEVER_LOCKED; first inactive boundary = HELPER_LOCK
```

## Formal interpretation

The three read-only preflights consistently show a healthy upstream and
Step4B startup/event-processing path:

```text
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
STEP4B_RUNTIME_REVALIDATION = PASS (3/3)
STEP4B_REVALIDATED = YES
```

This resolves the earlier contradictory Step3 and DMTD readings as a
diagnostic transport problem. The previous screenshot-style cascade
(`Step1 error -> Step4 error`) is not reproduced by the corrected observer;
the current Slave result is Step1–4B pass.

The run does not establish closed-loop lock. In all three windows:

```text
HELPER_LOCKED = 0
PSTAT_LOCKED = 0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

This is the actual remaining Step5 blocker, not evidence that Step4B failed.

## Milestone and merge status

```text
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED_BY_LATEST_RUN = YES
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
V4_SMOKE = NOT_RUN
```

Per the branch5 handoff, stop at this preflight revalidation. The next
controlled experiment is the V4 exclusive PI-bank 100-sample double-read
smoke using this trusted transport, still without changing the image or
Step5 control parameters. No merge is authorized by this record.
