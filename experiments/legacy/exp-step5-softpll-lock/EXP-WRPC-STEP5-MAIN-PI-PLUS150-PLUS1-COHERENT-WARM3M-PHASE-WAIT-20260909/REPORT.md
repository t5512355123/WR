# EXP-WRPC-STEP5-MAIN-PI-PLUS150-PLUS1-COHERENT-WARM3M-PHASE-WAIT-20260909

## 判定

本輪依指定流程完成 observer metadata push、Pain pull、Master/Slave
Quartus full compile、Slave→Master 燒錄、暖機與 coherent closed-loop
trajectory audit。Step 4B 維持 PASS，Main frequency lock 已出現且誤差已進入
小幅範圍，但 Main phase lock、Main lock 與 PSTAT lock 仍未出現；因此
Step5 尚未完成。

```text
SOURCE_HEAD = 47cb0f9
MASTER_SOF_SHA256 = 879657fa382517a851a8ca56f0a32b5cebe20bf8fd442c824f1f162425166e03
SLAVE_SOF_SHA256  = 6a6a91b468f9009d538512d6c99f87a23d179eab038e054f321817a3b82371ff
PROGRAM_ORDER = SLAVE_THEN_MASTER
STEP1_TO_STEP3 = PASS (warm3m preflight)
STEP4B = PASS (warm3m preflight)
HELPER_LOCK = PASS (warm3m preflight)
MAIN_ENABLED = 1 (warm3m preflight)
MAIN_FREQ_LOCK = 1 (warm3m preflight and trajectory samples)
MAIN_PHASE_LOCK = 0
MAIN_LOCK = 0
PSTAT_LOCK = 0
STEP5 = NOT_COMPLETE
MERGE_APPROVED = NO
```

## 本輪設定與流程

本輪沒有新增 functional firmware 變更；使用前一輪已驗證的 Main PI operating
point：

```text
Main KP = +150
Main KI = +1
Main frequency threshold = 50
Main frequency lock_samples = 50
Helper threshold = 2000
Helper lock_samples = 1000
Slave bootstrap = 3360, reverse = 1
HPLL code per physical step = 64
DPLL code per physical step = 16
```

本輪 `47cb0f9` 只修正兩個 observer 的 provenance/config label，讓觀測器標示
與實際映像的 `Main KP/KI` 及 Helper 設定一致。Pain 重新產生並成功配置
Master/Slave SOF；燒錄採 Slave→Master 順序。重新上電後的第一個短窗口曾有
Slave 未校準狀態，等待後的 warm3m preflight 才作為有效 upstream 窗口。

## Warm3m upstream 結果

有效窗口顯示鏈路、PTP 與 Step4B 仍然活躍：

```text
Master PTP = MASTER, RX/TX activity > 0
Slave  PTP = SLAVE, RX/TX activity > 0
Slave  WR_RX_SIGNAL = LOCK
LOCK_ENABLE_COUNT = 4
SPLL_SEQ_STATE = 6 (SEQ_WAIT_MAIN)
STEP1 = PASS
STEP2 = PASS
STEP3 = PASS
STEP4B_RESULT = PASS
HELPER locked = 1, lock_count = 1000/1000
MAIN enabled = 1, MAIN frequency locked = 1
MAIN phase locked = 0, MAIN locked = 0, PSTAT locked = 0
SPLL_DELOCK_COUNT = 0
```

## Coherent trajectory audit

`observer-closedloop-180-warm3m.log` 執行 180 個請求，實際觀測時間約
42.110 秒。這是每筆 JTAG snapshot 的 transport 時間，不是 180 秒的
穩定性證明；因此不能用本輪的 180 samples 宣稱 Step5 的 300 秒 gate。

```text
SAMPLES = 180
COHERENT_MEASUREMENT_SNAPSHOTS = 180
REJECTED_EPOCH_SNAPSHOTS = 0
REJECTED_ACCOUNTING_CANDIDATES = 0
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_SNAPSHOTS = 132
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
RESET_STABLE = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

coherent measurement 的 Main frequency error（內部誤差單位，不是外部頻率計
Hz）已非常接近零：

```text
FREQ_ERROR_MEAN = -0.3
FREQ_ERROR_RMS = 8.08359106118
FREQ_ERROR_MIN = -25
FREQ_ERROR_MAX = 22
FREQ_ERROR_FIRST = -10
FREQ_ERROR_LAST = -15
```

Helper actuator 也沒有 rail saturation：

```text
HELPER_ERROR_MEAN = 7.65
HELPER_ERROR_RMS = 995.386884583
HELPER_ERROR_MAX_ABS = 3705
HELPER_OUTPUT_SAMPLES = 180
LOW_RAIL_FRACTION = 0.0
HIGH_RAIL_FRACTION = 0.0
NO_RAIL_FRACTION = 1.0
ERROR_BAND_EXIT_EVENTS = 29
ACTUATOR_HUNT_OBSERVED = NO
```

最後一筆有效 position/accounting snapshot 顯示 absolute tracker 本身一致：

```text
TARGET_FINAL = 61962
APPLIED_FINAL = 61957
EXPECTED_APPLIED_ABSOLUTE = 61957
NORMAL_REQ_DELTA_OBSERVED = 517
NORMAL_COMPLETED_DELTA = 517
FINC_DELTA = 262
FDEC_DELTA = 255
BOOTSTRAP_COMPLETED_FINAL = 3360
BOOTSTRAP_DONE_FINAL = 1
```

但目前 observer 報告：

```text
DCO_INVARIANT_FAILS = 132
POSITION_ACCOUNTING = FAIL
```

這個 fail 不能直接解讀成 RTL actuator 失效。現行 checker 用絕對式
`DCO_STEP == BOOTSTRAP_COMPLETED + NORMAL_COMPLETED`；本輪是在既有映像暖機
及重新配置後觀測，`dco_step_count` 並非從本輪 bootstrap 邊界歸零，而是
16-bit counter 的既有累積值。相反地，transaction delta 已吻合
`NORMAL_REQ_DELTA == NORMAL_COMPLETED_DELTA`，且 `POSITION_INVARIANT_FAILS=0`。
下一輪會把 DCO invariant 改成以 post-bootstrap baseline 的 delta 關係檢查，
並同步修正 helper lock reader 仍殘留的舊 `1200/10000` 條件；兩者都是
observer correctness 修正，不改變控制器行為。

## Step5 結論與下一步

本輪最重要的進展是：暖機後 Main 已從上一輪的 frequency convergence 階段
進入 `frequency locked=1`，而 coherent error 已落在約 ±25；PI 沒有 low/high
rail。可是 phase detector 仍為 0，且沒有任何同一窗口的 Main phase/PSTAT
lock 證據，更沒有 300 秒 full-chain 穩定時間。因此本輪嚴格判定：

```text
STEP4B = PASS
STEP5 = NOT_COMPLETE
```

下一步先在 laptop 修正 observer 的兩個錯誤假設：

1. Helper lock reader 使用目前實際的 threshold 2000、lock_samples 1000。
2. DCO accounting 使用 baseline delta，而非要求 counter 的絕對值從零開始。

修正後再依相同流程重新 build、燒錄並觀測；不放寬 phase lock threshold，也不
把 `MAIN_FREQ_LOCKED=1` 單獨當成 Step5 pass。

## Raw evidence

本資料夾 `raw/` 保存本輪 build、program、warm preflight 與 120/180-sample
trajectory logs。遠端 archive 已下載至本輪根目錄：

```text
EXP-WRPC-STEP5-MAIN-PI-PLUS150-PLUS1-COHERENT-WARM3M-PHASE-WAIT-20260909-raw.tgz
SHA256 = 3eb7db877775b0925e33eb94c053f7739506f609a38c25002269533bbd6ad9b2
```
