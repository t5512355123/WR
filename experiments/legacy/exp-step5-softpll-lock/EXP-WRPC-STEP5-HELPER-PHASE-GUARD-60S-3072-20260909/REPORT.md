# EXP-WRPC-STEP5-HELPER-PHASE-GUARD-60S-3072-20260909

## 判定

本輪保留 Slave-only 60 秒 Helper phase guard，將 coarse HPLL bootstrap
由 1664 改為 3072 reverse/FINC。目的在於確認較接近零頻率誤差的 coarse
operating point 是否能在 phase history 清除後進入 fine lock。

編譯、燒錄、preflight 與完整 Slave 觀測均完成，但 Step5 仍未鎖定，
不能 merge。

```text
SOURCE_COMMIT = 9d04eba925ba4f6563cb309dffae570ac3ccc4be
PREFLIGHT_1 = VALID
STEP1_TO_STEP3 = PASS
STEP4A = PASS
STEP4B = PASS
STEP5_VALID_MEASUREMENT = YES
STEP5_RESULT = NOT_COMPLETE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## 變更

```text
Slave STEP5_BOOTSTRAP_STEPS: 1664 -> 3072
Slave STEP5_BOOTSTRAP_REVERSE: 1 (reverse/FINC, unchanged)
Slave Helper phase guard: 60 seconds (unchanged)
observer bootstrap_steps: 1664 -> 3072
```

上一輪加入的 phase guard 仍會在 `SEQ_START_HELPER` 後抑制 Slave
`helper_update()`，guard 到期後呼叫 `helper_reseed()`，清除 phase
accumulator、PI integrator 與 lock detector，並以第一個新 accepted tag
重新建立 baseline。PI gains、DCO mapping、Main、DMTD、PTP、PHY 與 reset
policy 均未修改。

## Build / program provenance

Pain 從上述 commit 的乾淨 build worktree 完整編譯 Master/Slave；兩個
Quartus full compilation 與兩次 JTAG programming 均成功：

```text
MASTER_SOF_SHA256 = 1be5d6e8329dd31534998ba43dd9430bd0d8903e2b37d30e58ed10ee5d0af31a
SLAVE_SOF_SHA256  = f86c6460c8094d58db632551fb5543fccd03a5af3ec71d9eebb85075713a58f4
MASTER_COMPILE = Full Compilation was successful
SLAVE_COMPILE = Full Compilation was successful
MASTER_PROGRAM = configuration succeeded, 0 errors, 0 warnings
SLAVE_PROGRAM = configuration succeeded, 0 errors, 0 warnings
TIMING_CLOSED = NO
MASTER_WORST_SETUP_SLACK_NS = -0.178
SLAVE_WORST_SETUP_SLACK_NS = -0.198
```

## Valid upstream window

等待超過 60 秒 guard 後，preflight-1 通過：

```text
Master Step1/Step2/Step4A = PASS
Slave Step1/Step2/Step3/Step4B = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

preflight 同時短窗口顯示 `STEP5_RESULT=NEVER_LOCKED`、
`STEP5_FIRST_INACTIVE_BOUNDARY=HELPER_LOCK`；這只是正式長觀測前的狀態
確認，不作為 300 秒穩定鎖定判定。

## Coherent closed-loop observation

在 valid preflight 後，僅對 Slave `DE5 [1-11.2]` 執行 3600 samples、
約 399.9 秒的 coherent trajectory audit：

```text
SAMPLES = 3600
POST_BOOTSTRAP_BASELINE_SAMPLE = 1
POST_BOOTSTRAP_BASELINE_SET = 1
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
RESET_STABLE = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

## 結果與解讀

3072 + phase guard 讓 frequency error 顯著接近零，但 phase branch 仍在
同一個飽和狀態，未能啟動 Main：

```text
FREQ_ERROR_MEAN = -77.1894444444
FREQ_ERROR_RMS = 77.8956531379
FREQ_ERROR_MIN = -115
FREQ_ERROR_MAX = -43
FREQ_ERROR_FIRST = -92
FREQ_ERROR_LAST = -64
PRECLAMP_FIRST = -115807549
PRECLAMP_FINAL = -233916315
HELPER_ERROR_MEAN = -150000.0
HELPER_ERROR_RMS = 150000.0
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 0.0
HIGH_RAIL_FRACTION = 1.0
HELPER_LOCK_COUNT_MAX = 1
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
TARGET_FINAL = 65531
APPLIED_FINAL = 65541
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 3072
BOOTSTRAP_DONE_FINAL = 1
FULL_CHAIN_MAX_SECONDS = 0.000
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

這輪已排除「1664 只是 frequency operating point 選錯」：3072 的頻率
誤差已經小很多，但 Helper phase error 仍固定在 `-150000`，output 仍
100% 高 rail，且沒有 normal tracker request。換句話說，phase guard
本身成功延後並重設了 Helper 更新，3072 也改善了 coarse frequency；剩下
的主要問題是 Helper phase error 的符號/target 語意與實際 HPLL actuator
方向不一致，或 page/mask 寫入後的實際 DAC 語意仍不是目前假設。

因此不能因為 frequency error 接近零或 lock counter 曾短暫變化，就宣稱
Step5 pass；Helper lock、Main lock、PSTAT 與 300 秒 full chain 都沒有
成立。

## 下一輪

停止繼續掃 coarse 數值，改做一輪唯讀 source/RTL 對照與最小 actuator
極性驗證：逐一對齊 Helper PI output、DCO `TARGET_CODE`、實際
`APPLIED_CODE`、SI5340 page/mask 及 FINC/FDEC 的物理方向，並用單步可逆
測試確認「phase error 為負時，實際輸出是否應向高 rail 或低 rail」。只有
方向語意確認後，再修改一個明確的 mapping 變因並重跑相同 300 秒 audit。

## Raw evidence

本資料夾 `raw/` 保存 build、program、preflight 與 Slave 3600-sample
observer。遠端 raw archive SHA-256：

```text
76f851b46bf89ad0b3999660e87f1206c0a84ef111113c5e3740cbf07d5c868a
```
