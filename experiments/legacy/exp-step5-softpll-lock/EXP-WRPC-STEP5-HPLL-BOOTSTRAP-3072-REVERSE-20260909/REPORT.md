# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-3072-REVERSE-20260909

## 判定

本輪把 Slave 的 reverse/FINC coarse bootstrap 從 1024 增至 3072，保留
PI、page/mask sequence、方向修正、half-step tracker 與 reset policy。結果
顯示 operating point 確實往正確方向移動，但仍沒有達成 Step5；不能 merge。

```text
SOURCE_COMMIT = 097b9333119503a6bdd745f8c1c8664a200bc936
STEP1_TO_STEP3 = PASS (preflight 2)
STEP4B = PASS (preflight 2)
STEP5_VALID_MEASUREMENT = PARTIAL
STEP5_RESULT = NOT_COMPLETE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

第一次 preflight 是診斷腳本的短暫 Step3 measurement failure；等待後的
preflight 2 才是有效窗口。它確認雙板 PHY/PTP、Slave WR RX lock、Step1/2/3
與 Step4B 全部通過。

## 唯一功能變更

`quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd`：

```text
STEP5_BOOTSTRAP_STEPS: 1024 -> 3072
STEP5_BOOTSTRAP_REVERSE: 1 (unchanged, FINC direction)
```

觀測腳本只更新了實驗標籤與設定文字。沒有改 PI、HPLL step size、Main、DMTD、
PTP、PHY 或 reset。

## Build / program provenance

Pain 從上述 source commit 完整編譯 Master/Slave；兩張 SOF 均成功產出：

```text
MASTER_SOF_SHA256 = ebf589196d4e4ea142c986aa784891dd523a417606e97be324d21e8d4fe64ca1
SLAVE_SOF_SHA256  = d0c856a12a40dabe0868c8a39e1497358924c5cfdf8c5ef32159eaed36af79a2
MASTER_WORST_SETUP_SLACK_NS = -0.178
SLAVE_WORST_SETUP_SLACK_NS = -0.198
TIMING_CLOSED = NO
PROGRAM_ORDER = SLAVE_THEN_MASTER
PROGRAM_RESULT = Configuration succeeded, 0 errors, 0 warnings
```

## Coherent observer

觀測器完成 1200 筆、約 134.8 秒 snapshots。coherence、transaction invariant
與 reset stability 通過；但 observer 的 position invariant 未通過，因此本輪
只把 rail、頻率趨勢與 lock 狀態作為部分有效證據，不把它包裝成完整 accounting
pass。

```text
SAMPLES = 1200
MEASUREMENT_COHERENCE = PASS
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
POSITION_ACCOUNTING = FAIL
RESET_STABLE = PASS
SPLL_DELOCK_COUNT_FIRST/MAX/FINAL = 0/5/0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

## 結果與解讀

相對 1024 reverse run 的 `FREQ_ERROR_MEAN=-621.29`，3072 reverse run 改善到：

```text
FREQ_ERROR_MEAN = -344.81
FREQ_ERROR_RMS = 344.999850242
FREQ_ERROR_MIN = -381
FREQ_ERROR_MAX = -313
FREQ_ERROR_FIRST = -350
FREQ_ERROR_LAST = -368
```

這支持「增加 FINC coarse 位移會把頻率誤差往零推近」的方向判斷。但在整個
觀測窗中，Helper 仍在低 rail，phase error 仍飽和於正端，沒有形成 lock：

```text
HELPER_ERROR_MEAN = 150000.0
HELPER_ERROR_RMS = 150000.0
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 1.0
HIGH_RAIL_FRACTION = 0.0
HELPER_LOCK_COUNT_MAX = 1
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
FINC_DELTA = 0
FDEC_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 3072
BOOTSTRAP_DONE_FINAL = 1
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

觀測開始時 virtual counters 已顯示 `FINC_COMPLETED=1024`、
`FDEC_COMPLETED=1024`、`NORMAL_COMPLETED=2048`，其後 target/applied 均為 5，
沒有新的 normal transaction。也就是 controller 已把 coarse operating point
帶到比 1024 更接近的頻率位置，但仍落在 Helper low rail 端，無法自行進入
`|helper_error| <= 200`。

`POSITION_ACCOUNTING=FAIL` 也表示 bootstrap 與 normal transaction 的跨階段
座標契約仍需修正或重新定義；下一輪不能忽略這個問題。

## 下一輪

依 `Astra建議.md` 與本輪趨勢，下一個受控 A/B 是沿同一 FINC 方向測試約
5632-step coarse operating point，同時保留 64-code half-step tracker；重點
是確認 phase error 能否由正飽和穿越 lock band，而不是再掃 PI。若仍在 rail，
應先修正 observer/RTL 的 bootstrap-to-applied position contract，再進行長時間
Step5 宣稱。

## Raw evidence

本資料夾 `raw/` 保存 build、program、兩次 preflight、coherent observer 與
SOF hash。遠端 raw archive SHA-256：

```text
16c3b35f133e0fec8f19fa9fd75f5bec8bb2b2af50795c51679d543fefbb8165
```
