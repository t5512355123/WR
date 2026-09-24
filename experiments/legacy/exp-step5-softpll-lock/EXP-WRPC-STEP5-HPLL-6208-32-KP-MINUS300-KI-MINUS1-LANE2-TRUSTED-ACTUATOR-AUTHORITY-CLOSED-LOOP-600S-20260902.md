# EXP-WRPC-STEP5-HPLL-6208-32-KP-MINUS300-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-AUTHORITY-CLOSED-LOOP-600S-20260902

## 實驗目的

依分支 5 對 64-step 結果的最新建議，在相同的 trusted Step4B gate 與控制參數下，
只把 `code_per_physical_step` 由 `64` 改為 `32`，驗證可用 actuator authority
增加後是否能完成 Step5 closed-loop lock。

本輪唯一 functional 變數是 `HPLL_TRACKER_CODE_PER_PHYSICAL_STEP=32`；沒有修改
`kp`、`ki`、bootstrap、SoftPLL event chain、VUART、reset tree 或 static-FSM fix。

## 版本與固定設定

- Git branch：`exp/step5-softpll-lock`
- FPGA source commit：`df45c73521f8d4c61d5844fe64f9079881d07cfe`
- `bootstrap=6208`
- `kp=-300`、`ki=-1`
- `code_per_physical_step=32`
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
  `8b7cffcd88772fb62b163075ac2301e54ca16a0fad3d945bc2580e07b4fdec81`
- Slave SOF SHA-256：
  `47c57fa39d45978af03a5c58e1319ce48bb3c294dc1605412a349020017731ed`

## 啟動與 Step4B gate

燒錄後等待 startup window，再執行 preflight。結果為：

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

因此 600 秒觀測是在 Slave Step4B 已通過、WB transport trusted 的條件下進行。

## 600 秒閉迴路結果

正式觀測執行 6000 samples、約 599.9 秒；本次 6000 個 frame 全部有效：

```text
SAMPLES=6000
VALID_FRAMES=6000
INVALID_FRAMES=0
WINDOW_SECONDS=599.900
HELPER_LOCK_COUNT_MAX=6927
HELPER_LOCK_COUNT_FINAL=100
HELPER_LOCKED_SEEN=0
HELPER_LOCKED_FINAL=0
FIRST_HELPER_LOCK_SAMPLE=NONE
LOCK_CHANGED_EVENTS=0
MAIN_ENABLED_FINAL=1
MAIN_LOCKED_FINAL=0
MAIN_FREQ_LOCKED_FINAL=0
MAIN_PHASE_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
SPLL_DELOCK_COUNT_FIRST=0
SPLL_DELOCK_COUNT_MAX=0
SPLL_DELOCK_COUNT_FINAL=0
NORMAL_REQ_DELTA=4759
NORMAL_COMPLETED_DELTA=4759
DCO_STEP_DELTA=4759
FORCED_ACTIVITY_DELTA=0
BOOTSTRAP_COMPLETED_DELTA=0
BOOTSTRAP_DONE_FINAL=1
NORMAL_TRANSACTION_ACCOUNTING=PASS
RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
```

lock 進度雖然高於 64-step，但仍未達硬 gate。helper error 統計顯示後段曾進入
rail 狀態：

```text
HELPER_ERROR_MEAN=31142.5776035
HELPER_ERROR_RMS=69109.867407
HELPER_ERROR_MAX_ABS=894058
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD=27.8037383178
HELPER_OUTPUT_RAIL5_FRACTION=20.65
HELPER_ERROR_PLUS150000_FRACTION=20.5833333333
```

觀測中可見 `MAIN_ENABLED=1` 與正常 DCO transactions，但 helper lock count 在
達到最高 `6927/10000` 後仍會重置；從未出現 `HELPER_LOCKED=1`，因此後續 main
frequency/phase lock 與 `PSTAT_LOCKED` 也都沒有成立。

## 判定

這次 32-step 實驗仍不是 Step5 pass。第一個失效 boundary 仍為 `HELPER_LOCK`：

```text
STEP4B = PASS
STEP5_COMPLETE = NO
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

本輪正式證明 32-step 比 64-step 具有更高的 lock-progress（`6927` 對 `5590`），
且觀測資料完整、無 RX error、無 SPLL delock、無 reset；但它仍不能支持 Step5
完成或 merge 到 `main`。

下一步交由分支 5 根據這份最新紀錄指定；在取得明確的
`STEP5_COMPLETE=YES` 且 `MERGE_APPROVED=YES` 前，維持不 merge。

## 原始紀錄

原始 build、program、preflight 與 600 秒觀測 log 位於：

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-32-KP-MINUS300-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-AUTHORITY-CLOSED-LOOP-600S-20260902/`
