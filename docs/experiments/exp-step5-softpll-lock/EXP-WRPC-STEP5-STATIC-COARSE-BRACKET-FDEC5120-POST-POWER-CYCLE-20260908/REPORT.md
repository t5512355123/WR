# EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC5120-POST-POWER-CYCLE-20260908

## 結論

本輪在 Pain 實體 power-cycle 後重新 pull、compile、program 5120-step image，
用來確認上一輪 `FDEC5120` 的 upstream regression 是否只是未斷電造成。

結果仍無法通過 Step1：初次燒錄後兩次 preflight 都是
`core_tm_link_up=0`、`core_link_ok=0`，Slave `spll_init_count=0`，
`STEP4B=BLOCKED_BY_STEP1`。因此沒有執行有效的 5120 coarse observer；本輪不
能解讀為 5120 actuator 工作點結果。

```text
STEP1_TO_STEP3 = INVALID_UPSTREAM
STEP4B = INVALID_UPSTREAM
STEP5 = NOT_APPLICABLE
STEP5_RESULT = BLOCKED_BY_UPSTREAM_STEP1
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP1
OBSERVER_EXECUTED = NO
MERGE_APPROVED = NO
```

## 版本與目標設定

```text
branch = exp/step5-softpll-lock
source_commit = 3ff26f1708ec85fbfcd5c1ad4e9f9abc2bb90d2e
bootstrap_steps = 5120
bootstrap_direction = FDEC (STEP5_BOOTSTRAP_REVERSE=0)
code_per_physical_step = 16
normal_hpll_tracker = 0
```

本輪 source 沒有新增功能變更，只重新建置已推送的 5120 image；沒有修改
PI、lock threshold、DMTD、PTP、PHY 或 reset policy。

## Build 與 program

```text
SIMULATION_RC = 0
FIRMWARE_MASTER_RC = 0
FIRMWARE_SLAVE_RC = 0
COMPILE_MASTER_RC = 0
COMPILE_SLAVE_RC = 0
PROGRAM_MASTER_RC = 0
PROGRAM_SLAVE_RC = 0
```

SOF SHA-256：

```text
MASTER = d804edd4798de3d7fc8cceb8612cb2c1f6f063663815bbd762d7921840e54506
SLAVE  = 79a527b27a788e5bf0fd1c06c6a22dcf9340200cd376f5b09ab8360a3a8dfb01
```

## Preflight 結果

```text
PREFLIGHT_1 = STEP1 error / STEP4B BLOCKED_BY_STEP1
PREFLIGHT_2 = STEP1 error / STEP4B BLOCKED_BY_STEP1
core_tm_link_up = 0/1
core_link_ok = 0/1
SLAVE_SPLL_INIT_COUNT = 0
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

JTAG/WB transport 本身仍為 trusted，沒有 timeout、stale response 或 address
cross-contamination；失敗是在 White Rabbit upstream link/startup。由於 Step1
未通過，沒有執行 1200-sample Step5 observer，也沒有 5120 的 Helper error
或 lock 結果。

## 判讀與後續條件

實體 power-cycle 後仍重現同一 upstream failure，表示目前不能安全地把 5120
加入 4096～6144 的有效 coarse bracket。下一步不是再改 PI 或繼續二分，而是
先用已知可通過 Step1～4B 的 6144 image 做 recovery/control comparison，或
針對 5120/6144 parameter boundary 做 source/compiled-RTL audit。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

- [raw archive](raw/EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC5120-POST-POWER-CYCLE-20260908-UPSTREAM-REGRESSION.tar.gz)
- [archive SHA-256](raw/EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC5120-POST-POWER-CYCLE-20260908-UPSTREAM-REGRESSION.tar.gz.sha256)
- [preflight 1](raw/preflight-1.log)
- [preflight 2](raw/preflight-2.log)
