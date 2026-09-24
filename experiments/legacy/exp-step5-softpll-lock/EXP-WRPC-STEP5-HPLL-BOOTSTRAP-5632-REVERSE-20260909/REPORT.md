# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-5632-REVERSE-20260909

## 判定

本輪將 reverse/FINC coarse bootstrap 增至 5632，並讓 observer 使用相同的
5632 bootstrap boundary。結果證實 5632 已跨過 3072 的頻率零點，但 phase
error 仍在正端飽和、Helper 固定低 rail，Step5 未完成，不能 merge。

```text
SOURCE_COMMIT = 5ac9d69dd3936afa9faa898e6e604b6a24a92596
STEP1_TO_STEP3 = PASS (preflight 1)
STEP4B = PASS (preflight 1)
STEP5_VALID_MEASUREMENT = YES
STEP5_RESULT = NOT_COMPLETE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## 變更

```text
Slave STEP5_BOOTSTRAP_STEPS: 3072 -> 5632
Slave STEP5_BOOTSTRAP_REVERSE: 1 (FINC, unchanged)
observer bootstrap_steps: 3072 -> 5632
```

其餘 PI、HPLL step size、page/mask sequence、Main、DMTD、PTP、PHY 與 reset
policy 均未改變。

## Build / program provenance

Pain 從本輪 source 完整編譯 Master/Slave，兩個 full compilation 均成功：

```text
MASTER_SOF_SHA256 = 9fa0da6e9829d7c8294e54f6a87beacfbe6f3f3eb64351552e9d5b47762f5b9b
SLAVE_SOF_SHA256  = aad7f7a473b835bf61a58eb8945340d724d1df7dc4f3da57dc11ca6a02f37c19
MASTER_WORST_SETUP_SLACK_NS = -0.178
SLAVE_WORST_SETUP_SLACK_NS = -0.203
TIMING_CLOSED = NO
PROGRAM_ORDER = SLAVE_THEN_MASTER
PROGRAM_RESULT = Configuration succeeded, 0 errors, 0 warnings
```

preflight 確認雙板 PHY/PTP、Slave WR RX lock、Step1/2/3 與 Step4B 通過：

```text
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

## Coherent closed-loop observation

觀測器完成 1200 筆、約 134.7 秒 coherent snapshots；本輪 bootstrap boundary
與 RTL 一致，完整 accounting 與 reset stability 均通過：

```text
SAMPLES = 1200
POST_BOOTSTRAP_BASELINE_SAMPLE = 1
POST_BOOTSTRAP_BASELINE_SET = 1
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
RESET_STABLE = PASS
SPLL_DELOCK_COUNT_FIRST/MAX/FINAL = 0/0/0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

## 結果與解讀

頻率誤差由 3072 輪的負值跨到正值：

```text
FREQ_ERROR_MEAN = 380.2675
FREQ_ERROR_RMS = 380.394673333
FREQ_ERROR_MIN = 354
FREQ_ERROR_MAX = 411
FREQ_ERROR_FIRST = 388
FREQ_ERROR_LAST = 356
```

這與 1024、3072、5632 三個 operating point 的趨勢一致：增加 FINC coarse
位移會把 frequency error 由約 -621 推到 -345，再推到約 +380。5632 已是
頻率零點的另一側，但它沒有讓累積 phase error 回到 lock window，因為 PI 在
低 rail 無法再提出下一個有效 physical step：

```text
HELPER_ERROR_MEAN = 150000.0
HELPER_ERROR_RMS = 150000.0
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 1.0
HIGH_RAIL_FRACTION = 0.0
NO_RAIL_FRACTION = 0.0
HELPER_LOCK_COUNT_MAX = 2
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
FINC_DELTA = 0
FDEC_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 5632
BOOTSTRAP_DONE_FINAL = 1
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

`PRECLAMP_ERROR` 從 `150356323` 增至 `341175595`，表示 phase error 正在遠離
零而不是進入 lock；因此不能以 frequency error 已跨過零點，或以 Helper
lock counter 的短暫值 2，宣稱 Step5 pass。

## 下一輪

本輪已證明：目前單純增加 FINC bootstrap 會穿越 frequency operating point，
但無法解決 bootstrap 後 phase accumulator 的初始偏移。下一輪應回到已量測
的 1024/3072 phase bracket，選擇內插工作點並保留完整 observer accounting；
重點是同時讓 `FREQ_ERROR` 接近零與 `PRECLAMP_ERROR` 落入 lock window，而非
繼續向 5632 外推或盲掃 PI。

## Raw evidence

本資料夾 `raw/` 保存 build、program、preflight、coherent observer 與 SOF hash。
遠端 raw archive SHA-256：

```text
ff74d8991d8692221e88849c28969d956de95c4cfbbba4576ad61bcaf8ea772b
```
