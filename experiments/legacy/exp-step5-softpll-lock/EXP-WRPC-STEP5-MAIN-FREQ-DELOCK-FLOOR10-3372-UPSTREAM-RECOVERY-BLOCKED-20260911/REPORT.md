# EXP-WRPC-STEP5-MAIN-FREQ-DELOCK-FLOOR10-3372-UPSTREAM-RECOVERY-BLOCKED-20260911

## 判定

```text
Step5 = NOT COMPLETE
Measurement = NOT EXECUTED
Reason = upstream Step1–Step4B prerequisite was not valid
```

本輪沒有宣稱 Step5 pass。雖然程式已完成編譯並燒錄，但在合法的 Step5 coherent observer window 建立之前，兩次 preflight 都顯示硬體鏈路／上游狀態不具備進入 Step5 的條件，因此沒有執行 Step5 lock trajectory observer，也沒有把任何暫態狀態誤判成鎖定。

## 實驗範圍

- Branch: `exp/step5-softpll-lock`
- Source commit: `e5c5842`
- Baseline objective: 驗證 Main frequency lock detector 能否正確釋放過時的 frequency lock，並讓 Main 重新進入有效的 frequency/phase convergence 路徑。
- 本輪同步修正 observer 的 DCO accounting：改以相鄰 coherent snapshot interval 的 modulo-16-bit 增量作 lower-bound 檢查，避免長時間觀測中 16-bit completion counter wrap 造成假的 accounting failure。

## 程式修改

### Main frequency lock detector

`vendor/wrpc-sw/softpll/spll_main.c` 將 Main 的：

```c
delock_samples = 20000
```

改為 frequency lock-counter floor `10`。原設定高於 `lock_samples = 50`，會使已宣稱 locked 的 frequency detector 在錯誤持續存在時無法正常釋放，造成 stale lock。

### Observer accounting

`read_step5_coherent_closed_loop_trajectory_audit.tcl` 改用相鄰有效 snapshot 的 DCO interval accounting，並保留 modulo-16-bit counter 語意。此修改只影響觀測判定，不改變 FPGA functional path。

## Build / programming

兩個 image 均成功編譯；Quartus timing 仍未 closed。

```text
Master build = PASS
Slave build  = PASS
TIMING_CLOSED = NO
```

SOF SHA-256:

```text
Master 3b0290016bbf3dce3ce6a11f59ec498fd2ad6fd9efdb4f376bc37509446981ff
Slave  06fb699d3df7b2e4ba630c6cf13f08570dcec2fe79480179633a37c5d837cee8
```

第一次 programming：

- Master programming = PASS
- 等待約 45 秒後 Slave programming = PASS

## Preflight 結果

### 第一次 programming 後

Master 當時可見：

```text
WDIAGS_PTP = 6 MASTER
ΔPTP_RX = 7
ΔPTP_TX = 22
```

Slave 當時可見：

```text
WDIAGS_PTP = 8 UNCALIBRATED
ΔPTP_RX = 27
ΔPTP_TX = 13
```

因此 preflight 判定：

```text
STEP1_REGRESSION = PASS       # 這次 snapshot 的 Step1 基本訊號仍可見
STEP4A_RESULT = PASS
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP2
STEP5_RESULT = UPSTREAM_NOT_READY
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
```

Slave 尚未達到可接受的 PTP calibration／Step2 狀態，故不能合法開始 Step5。

### Warm recovery programming 後

在不進行實體斷電的前提下，重新 programming Master，再等待約 45 秒後重新 programming Slave，結果沒有恢復成可用的 master/slave pair：

```text
Master WDIAGS_PTP = 3 DISABLED / 6 MASTER
Master ΔPTP_RX = 0
Master ΔPTP_TX = 0

Slave WDIAGS_PTP = 6 MASTER / 9 SLAVE
Slave ΔPTP_RX = 0
Slave ΔPTP_TX = 0
```

Recovery preflight 判定：

```text
STEP1_REGRESSION = FAIL
STEP4A_RESULT = PASS
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP5_RESULT = UPSTREAM_NOT_READY
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
```

這說明問題在本輪首先落在實驗環境的 upstream/link/runtime pairing，而不是已能由 Step5 observer 判斷的 closed-loop lock 行為。由於 preflight gate 不成立，本輪刻意沒有執行 600/3600 秒的 Step5 trajectory observer。

## 結論

本輪的兩項程式／觀測修正已完成 build 並成功 programming，但實驗證據不足以判定 Step5，也沒有證明 `delock floor = 10` 已讓 Main 成功鎖住 Clock。

需要先恢復一個有效的：

```text
Master ↔ Slave link
Slave PTP calibration
Step1–Step4B upstream gate
```

之後才能重新執行 coherent Step5 observer，檢查：

1. `MAIN_FREQ_LOCKED` 是否會在 frequency error 持續超出 ±50 時釋放；
2. frequency error 是否重新收斂並保持在 lock threshold 內；
3. `MAIN_PHASE_LOCKED`、`MAIN_LOCKED`、`PSTAT_LOCKED` 是否在要求的連續樣本窗內成立；
4. helper actuator hunting 是否下降，而不是只出現 stale status bit。

本輪未執行實體 power-cycle；若要排除目前板卡／link pairing 的殘留狀態，下一輪需由使用者明確授權對 Pain 做 power-cycle，再重做同一個 commit 的 programming 與 preflight。

## 原始紀錄

原始 build、programming 與兩次 preflight 輸出保存在本資料夾的 `raw/`。

Raw archive SHA-256:

```text
d7f591ce6192892ad96a48def54ba0281d8bc8b67637eb4157f4639e0a649481
```
