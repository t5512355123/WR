# EXP-S5-FUNCTIONAL-MILESTONE-PSTAT-LOCK-REVALIDATION-20260920

## 判定

**Step 5 functional revalidation：FAIL。**

本輪依 GitHub → Pain → firmware build → Quartus build → JTAG programming → read-only observer 重跑既有 Step5 milestone。兩個 candidate 都沒有取得可宣稱的完整 lock chain，因此本輪不修改 Step5 pass 門檻，也不 merge 到 `main`。

本輪要求的正式 gate 是：

```text
Helper lock = 1
Main frequency lock = 1
Main phase lock = 1
PSTAT.locked = 1
```

四項必須在同一份有效觀測的 final state 同時成立；本輪沒有成立。

## Candidate A：功能 baseline `17f20ad`

### Source / image identity

```text
Source commit = 17f20ad32c619212133e6134205cf017212d7dd8
QSF/SDC/MIF identity = matches the historical 2026-09-12 build metadata
Master SOF SHA256 = 3f02bb15ad5cc23130790e1974bf875bd2d1aa9fe8905866b849c51b9287388d
Slave SOF SHA256  = 687f975ee8667b5cf4946328a3272a965d22b680ec1cbfe18e09c8bb8bbec632
TIMING_CLOSED = NO
Master worst setup slack = -0.058 ns
Slave worst setup slack  = -0.001 ns
```

Historical build metadata recorded different SOF hashes (`d588…` / `3cda…`) even though the QSF/SDC/MIF identities match. The historical SOF binaries were not available on Pain for direct recovery, so this run used a fresh Quartus fit from the same source inputs.

### Programming / preflight

Master (`DE5 [1-11.1]`) and Slave (`DE5 [1-11.2]`) programming both succeeded with zero errors and zero warnings.

Preflight was transport-trusted and upstream-ready:

```text
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
STEP4A_RESULT = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
```

### 3600-sample coherent observer

Observer:

```text
read_step5_coherent_closed_loop_trajectory_audit.tcl 3600 100 "DE5 [1-11.2]"
```

The observer completed all 3600 samples with coherent measurement accounting, but the control chain did not lock:

```text
COHERENT_MEASUREMENT_SNAPSHOTS = 3600
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_INVARIANT_FAILS = 36
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_MAX_SECONDS = 0.000
STEP5_CHAIN_RESULT = NOT_COMPLETE
RESET_STABLE = PASS
```

The Helper actuator reached both rails and ended at the low rail; this is classified as `NO_LOCK_CLASSIFICATION`, not as a threshold or timing-only pass.

## Candidate B：latest branch `4e993ea5`

This branch contains the latest protocolled RX2SYS hold SDC candidate. It was compiled and programmed as a separate comparison without any further experiment-time edits; no PI, firmware control, detector, timeout, or RTL change was introduced during this comparison.

```text
Source commit = 4e993ea5afea476c679aa7d757188236b193826c
Master SOF SHA256 = d671da076dd0f2ffea4382abf6742fb849e7d0593939761cc54616ad4839ca64
Slave SOF SHA256  = 11545b4d489f5969edea82bd7301f38be3b472205fd5251cad1dcb32e9c96281
TIMING_CLOSED = NO
Master worst setup slack = -0.094 ns
Slave worst setup slack  = -0.376 ns
```

Both programmers again reported configuration success with zero errors and zero warnings. The post-program preflight was transport-trusted, but the upstream WR/Step3 gate was not usable for Step5:

```text
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
STEP4A_RESULT = PASS
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP3
STEP5_RESULT = UPSTREAM_NOT_READY
```

Per the stopping rule, no Step5 observer was run on Candidate B because the Step4B prerequisite was not established.

## Conclusion / next action

```text
PSTAT_LOCK_REVALIDATION = FAIL
STEP5_PASS_GATE_UPDATE = NOT_APPLIED
README_STATUS_UPDATE = NOT_APPLIED
MERGE_TO_MAIN = NOT_APPLIED
```

The historical documentation remains historical evidence only. This fresh hardware revalidation does not reproduce the required four-lock state, so it is not valid to rewrite the gate or merge this branch to `main` as a new Step5 pass milestone.

Raw evidence and build identities are stored under `raw/baseline-17f20/` and `raw/latest-4e993/`.
