# EXP-WRPC-STEP5-MAIN-FREQ-DELOCK-FLOOR10-3372-COLD-POWERCYCLE-20260912-HELPER-HIGH-RAIL

## 判定

```text
Step5 = NOT COMPLETE
STEP5_CHAIN_RESULT = NOT_COMPLETE
FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

本輪完成實體 power-cycle、重新編譯、燒錄、上游 recovery 與 3600-sample coherent observer。上游 gate 最終恢復並通過 Step4B，因此這次是有效的 Step5 measurement；但 Helper 一直在高 rail、沒有取得 lock，Main 沒有被啟用，故不能宣稱 Step5 pass。

## 版本與實驗流程

- Branch: `exp/step5-softpll-lock`
- Build source: `6a47ee8`
- Relevant code change: `e5c5842`（Main frequency delock floor 由不合理的 `20000` 改為 `10`，並修正 observer 的 modulo-16-bit adjacent accounting）
- Power-cycle: 依授權執行 Pain 實體關機、等待 10 秒、重新開機；開機控制第二次點擊後已視覺確認啟用
- SSH probe: PASS，主機 `pain`，工作目錄 `/home/b10504072`
- Programming order: Master（`DE5 [1-11.1]`）→ 等待 45 秒 → Slave（`DE5 [1-11.2]`）

## Build / programming

```text
Master build = PASS
Slave build  = PASS
TIMING_CLOSED = NO
Master programming = PASS
Slave programming  = PASS
```

SOF SHA-256:

```text
Master 82c2c319c575ce2d6e8188ebed1fa8ff2dc2adfc79113780e49d34eba7976fcf
Slave  33881b1d8bed7f663d9dec807f27a00ab436ce11734977f698a44dff0a849704
```

## 上游恢復過程

### Cold power-cycle 後第一次 preflight

```text
Master: STEP1_REGRESSION = FAIL, PTP_RX delta = 0
Slave:  PTP = LISTENING, PTP_RX delta = 0, LOCK_ENABLE = 0
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP5_RESULT = UPSTREAM_NOT_READY
```

### Warm recovery 後

重新 programming Master、等待 45 秒、重新 programming Slave 後，Master 恢復 Step1–3，但 Slave 暫時仍為 `UNCALIBRATED`，因此 Step4B 先被 Step2 擋住。

再等待 120 秒後的 settled preflight：

```text
Master WDIAGS_PTP = 6 MASTER
Master PTP_RX delta = 8
Master PTP_TX delta = 25

Slave WDIAGS_PTP = 9 SLAVE
Slave PTP_RX delta = 24
Slave PTP_TX delta = 4
Slave LOCK_ENABLE = 4

STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

這確認本輪 observer 使用的是有效的 Master/Slave upstream window，而不是在無鏈路狀態下解讀 Step5 counters。

## Step5 coherent observer

```text
SAMPLES = 3600
COHERENT_MEASUREMENT_SNAPSHOTS = 3599
REJECTED_EPOCH_SNAPSHOTS = 1
WINDOW_ELAPSED = 424.118 seconds
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
```

核心結果：

```text
FREQ_ERROR_MEAN = -3.531258688297
FREQ_ERROR_RMS = 8.31130551651
FREQ_ERROR_MIN = -38
FREQ_ERROR_MAX = 24

HELPER_ERROR_MEAN = -150000.0
HELPER_ERROR_MAX_ABS = 150000
HELPER_OUTPUT_SAMPLES = 3599
LOW_RAIL_FRACTION = 0.0
HIGH_RAIL_FRACTION = 1.0
NO_RAIL_FRACTION = 0.0

HELPER_LOCK_COUNT_MAX = 37
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

Helper output 從觀測開始即固定在 `65531` 高 rail，`HELPER_ERROR=-150000`；因此沒有送出新的 normal DCO request：

```text
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
FINC_DELTA = 0
FDEC_DELTA = 0
DCO_STEP_DELTA = 0
BOOTSTRAP_DELTA = 0
```

這表示 Main frequency error 雖然接近 0，並不是 Main 已鎖定；因為 Helper lock gate 未成立，`MAIN_ENABLED=0`，`PSTAT_LOCKED=0`。本輪結果把目前邊界從「上游未就緒」推進到「Helper operating point / lock detector 尚未成立」。

## 結論與下一步

本輪證明：

1. 實體 power-cycle 後可以透過 warm recovery 恢復 Step1–Step4B。
2. `e5c5842` 的 Main frequency delock 與 observer accounting 修改成功編譯、燒錄，且沒有造成 reset 或 accounting regression。
3. 在有效 upstream window 中，Main frequency error 的內部數值接近 0，但 Helper 仍被固定在高 rail，不能把這個數值誤判為 Step5 lock。

下一輪應只針對 Helper 的 operating point／coarse acquisition 做一個最小變因，保留 Main PI、Main delock floor、lock threshold 與 reset policy 不變；必須先讓 Helper error 離開 `-150000` rail 並能通過 Helper lock dwell，才會產生合法的 Main closed-loop evidence。

## 原始紀錄

本資料夾 `raw/` 保存 build、programming、所有 recovery/preflight 以及完整 coherent observer log。

Raw archive SHA-256:

```text
c75a761e88156c30b81ab4c1f073f711312eb8bcc9b21de6168cd8a5a5021f8d
```
