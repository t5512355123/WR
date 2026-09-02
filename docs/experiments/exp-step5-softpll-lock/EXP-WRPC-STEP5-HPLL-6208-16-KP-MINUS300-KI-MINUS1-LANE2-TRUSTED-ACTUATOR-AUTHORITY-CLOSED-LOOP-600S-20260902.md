# EXP-WRPC-STEP5-HPLL-6208-16-KP-MINUS300-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-AUTHORITY-CLOSED-LOOP-600S-20260902

## 實驗目的

依分支 5 對 32-step 結果的最新建議，在相同的 trusted Step4B gate 與控制參數下，
只把 `code_per_physical_step` 由 `32` 改為 `16`，驗證是否能跨過 helper lock，並
在同一個 600 秒窗口內完成完整 Step5 lock chain。

本輪唯一 functional 變數是 `HPLL_TRACKER_CODE_PER_PHYSICAL_STEP=16`；沒有修改
`kp`、`ki`、bootstrap、SoftPLL event chain、VUART、reset tree 或 static-FSM fix。

## 版本與固定設定

- Git branch：`exp/step5-softpll-lock`
- FPGA source commit：`56a43b3e8b1f73369576c6542f63fb027652636c`
- `bootstrap=6208`
- `kp=-300`、`ki=-1`
- `code_per_physical_step=16`
- `shift=12`、`bias=5`、`threshold=200`
- `lock_samples=10000`
- QSFPA lane：2
- normal HPLL tracker：ON
- JTAG forced activity：OFF

## Build 與 programming

- Master Quartus build：PASS，`timing_closed=NO`
- Slave Quartus build：PASS，`timing_closed=NO`
- Master programming：PASS，1 device configured，0 errors、0 warnings
- Slave programming：PASS，1 device configured，0 errors、0 warnings
- Master SOF SHA-256：
  `1e6657401a21e648cdc6daa5129e2c39f369095758f1eb4c7fe16ec870511f48`
- Slave SOF SHA-256：
  `eb4a159f3b87b4f5979822c89fb3de9b6112cf5aab13a4ce3312e2b9a05f59b2`

## 啟動與 Step4B gate

燒錄後第一次 preflight 落在已知的 Slave startup transient：Slave 暫時仍為
`UNCALIBRATED`，所以該次不作為 Step4B 實驗 gate。等待後重跑 preflight，取得可信
gate：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
RXERR_DELTA = 0
RESET_DELTAS = 0
```

因此正式 600 秒觀測是在 Slave Step4B 已通過、WB transport trusted 的條件下進行。

## 600 秒閉迴路結果

正式觀測執行 6000 samples、約 599.9 秒：

```text
SAMPLES=6000
VALID_FRAMES=5906
INVALID_FRAMES=94
WINDOW_SECONDS=599.900
HELPER_LOCK_COUNT_MAX=10000
HELPER_LOCK_COUNT_FINAL=0
HELPER_LOCKED_SEEN=1649
HELPER_LOCKED_FINAL=0
FIRST_HELPER_LOCK_SAMPLE=1
LOCK_CHANGED_EVENTS=0
MAIN_ENABLED_FINAL=1
MAIN_LOCKED_FINAL=0
MAIN_FREQ_LOCKED_FINAL=0
MAIN_PHASE_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
SPLL_DELOCK_COUNT_FIRST=0
SPLL_DELOCK_COUNT_MAX=0
SPLL_DELOCK_COUNT_FINAL=0
NORMAL_REQ_DELTA=5352
NORMAL_COMPLETED_DELTA=5352
DCO_STEP_DELTA=5354
FORCED_ACTIVITY_DELTA=0
BOOTSTRAP_COMPLETED_DELTA=0
BOOTSTRAP_DONE_FINAL=1
NORMAL_TRANSACTION_ACCOUNTING=PASS
RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
```

16-step 確實讓 helper 多次到達 `HELPER_LOCKED=1` 與 `10000/10000`，但這些是
不連續的片段；之後會回到 invalid 或 `HELPER_STATE=0`/count 0。觀測窗口末段
helper 仍未 locked，且 main frequency/phase lock 與 PSTAT lock 從未成立。

## 判定

這次 16-step 實驗仍不是 Step5 pass。雖然 helper lock gate 曾被短暫跨過，但沒有
形成後續且連續至少 300 秒的 full-chain lock：

```text
STEP4B = PASS
STEP5_COMPLETE = NO
STEP5_FIRST_INACTIVE_BOUNDARY = MAIN_FREQUENCY_LOCK
MERGE_APPROVED = NO
```

本輪同時證明：

- 600 秒內沒有 SPLL delock、RX error 或任何 reset；
- normal tracker 的 request/completion accounting 通過；
- helper lock progress 已從 32-step 的 `6927` 提升到 `10000`，但維持性不足；
- `MAIN_FREQ_LOCKED`、`MAIN_PHASE_LOCKED`、`MAIN_LOCKED`、`PSTAT_LOCKED` 均為 0；
- 因此不能把短暫 helper lock 視為 Step5 完成，也不能 merge 到 `main`。

下一步交由分支 5 根據這份最新紀錄指定；在取得明確的
`STEP5_COMPLETE=YES` 且 `MERGE_APPROVED=YES` 前，維持不 merge。

## 原始紀錄

原始 build、program、preflight 與 600 秒觀測 log 位於：

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-16-KP-MINUS300-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-AUTHORITY-CLOSED-LOOP-600S-20260902/`
