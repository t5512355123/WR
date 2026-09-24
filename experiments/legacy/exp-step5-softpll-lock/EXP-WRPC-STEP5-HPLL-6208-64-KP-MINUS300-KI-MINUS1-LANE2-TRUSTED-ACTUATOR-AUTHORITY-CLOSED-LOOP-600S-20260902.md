# EXP-WRPC-STEP5-HPLL-6208-64-KP-MINUS300-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-AUTHORITY-CLOSED-LOOP-600S-20260902

## 實驗目的

依分支 5 最新建議，在已確認 actuator 方向與持續 authority 的映像上，只把
`code_per_physical_step` 由 `128` 改為 `64`，驗證 6208-step bootstrap 後的正常
HPLL tracker 是否能在可信的 Slave Step4B gate 上完成 Step5 closed-loop lock。

本輪唯一 functional 變數是 `HPLL_TRACKER_CODE_PER_PHYSICAL_STEP=64`；其餘控制參數
固定為分支 5 指定值。

## 版本與固定設定

- Git branch：`exp/step5-softpll-lock`
- FPGA source commit：`72f0de4a06bf75bd9a6d8db9d5c01bb40da18dc4`
- `bootstrap=6208`
- `kp=-300`、`ki=-1`
- `code_per_physical_step=64`
- `shift=12`、`bias=5`、`threshold=200`
- `lock_samples=10000`
- QSFPA lane：2
- normal HPLL tracker：ON
- JTAG forced activity：OFF

本輪沒有再修改 parser、VUART、reset tree、SoftPLL event chain 或 static-FSM fix。

## Build 與 programming

- Master Quartus build：PASS，`timing_closed=NO`
- Slave Quartus build：PASS，`timing_closed=NO`
- Master programming：PASS，1 device configured，0 errors、0 warnings
- Slave programming：PASS，1 device configured，0 errors、0 warnings
- Master SOF SHA-256：
  `530100d60f136023423dea10af9412429615b3c64dcd226742ec9fca72c7ae0e`
- Slave SOF SHA-256：
  `235e992b960cc409bf1c9c66a223ec24c3d963e6c8d2d1ed80483db0b0600141`

## 啟動與 Step4B gate

第一次燒錄後立即讀取時，Slave 尚在 startup/calibration window；等待後重跑
preflight，得到可信 gate：

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

這確認本輪 600 秒觀測是在 Step4B 已通過、而非 link 或 transport 尚未 ready 的
狀態下進行。

## 600 秒閉迴路結果

正式觀測執行 6000 samples、約 599.9 秒。硬 gate 的關鍵結果為：

```text
STEP5_LOCK_CONVERGENCE_SUMMARY
SAMPLES=6000
VALID_FRAMES=4285
INVALID_FRAMES=1715
WINDOW_SECONDS=599.900
HELPER_LOCK_COUNT_MAX=5590
HELPER_LOCK_COUNT_FINAL=100
HELPER_LOCKED_SEEN=0
HELPER_LOCKED_FINAL=0
FIRST_HELPER_LOCK_SAMPLE=NONE
MAIN_ENABLED_FINAL=0
MAIN_LOCKED_FINAL=0
MAIN_FREQ_LOCKED_FINAL=0
MAIN_PHASE_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
SPLL_DELOCK_COUNT_FIRST=0
SPLL_DELOCK_COUNT_MAX=0
SPLL_DELOCK_COUNT_FINAL=0
NORMAL_REQ_DELTA=4187
NORMAL_COMPLETED_DELTA=4187
DCO_STEP_DELTA=4187
BOOTSTRAP_COMPLETED_DELTA=0
BOOTSTRAP_DONE_FINAL=1
NORMAL_TRANSACTION_ACCOUNTING=PASS
RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
```

helper error 的統計也顯示尚未進入可鎖定區域：

```text
HELPER_ERROR_MEAN=25713.8816803
HELPER_ERROR_RMS=62072.0361776
HELPER_ERROR_MAX_ABS=150000
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD=18.1096849475
HELPER_OUTPUT_RAIL5_FRACTION=17.1528588098
HELPER_ERROR_PLUS150000_FRACTION=17.0828471412
```

雖然 bootstrap 確實完成 `6208` steps，且 normal tracker 的 request/completion
accounting 完整一致，觀測期間沒有 SPLL delock 或 reset；但是 helper lock count
曾短暫上升，最高也只有 `5590/10000`，之後重置，從未產生 `HELPER_LOCKED=1`。

## 判定

本輪不是 Step5 pass。第一個失效 boundary 是 `HELPER_LOCK`：

```text
STEP4B = PASS
STEP5_COMPLETE = NO
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

因此目前不能 merge 到 `main`。本輪同時證明：

- Step4B gate 在 600 秒實驗前已成立；
- 6208-step bootstrap 已完成；
- normal HPLL tracker 有 4187 次 request，且完成數完全相同；
- 沒有新增 SPLL delock 或任何 reset；
- 但 `MAIN_ENABLED`、`PSTAT_LOCKED` 及所有 Step5 lock flags 均維持 0。

下一步交由分支 5 根據這份最新實驗紀錄指定；在取得明確的
`STEP5_COMPLETE=YES` 且 `MERGE_APPROVED=YES` 前，維持不 merge。

## 原始紀錄

原始 build、program、preflight 與 600 秒觀測 log 位於：

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-64-KP-MINUS300-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-AUTHORITY-CLOSED-LOOP-600S-20260902/`
