# EXP-WRPC-STEP5-LANE2-SAME-SOF-REPROGRAM-LINK-REPEATABILITY-3X-20260901

## 實驗目的

依分支5-WR 最新建議，固定目前已存在的 Master/Slave SOF，不重新編譯，只重複三次 Slave→Master programming 與 startup preflight，確認 link/PTP bring-up 是否具有 repeatability。這是回到 frozen-bank double-read 前的上游 gate 實驗。

## 固定條件

```text
QSFPA data path = lane 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

本輪沒有 rebuild、沒有 source 修改、沒有 PI/PHY/PTP role 手動修改，也沒有執行 frozen-bank double-read 或 1800 秒 Step5 run。

## SOF provenance

```text
MASTER_SOF_SHA256 = ce400592f498efe98a8a45aa6630ca2379c17ef637c3e6be44376c24c3db16aa
SLAVE_SOF_SHA256 = 292bc51a9ad08fa5575126a42ba11e67771aaa1faaca47b74ebb681984abd016
```

兩個 hash 與前一份 build/program provenance 完全一致。三個 cycle 都使用同一對 SOF；每次 programming 均成功配置 1 device、0 errors。

## Trial 結果

### Trial 1

```text
MASTER:
core_tm_link_up = 1
core_link_ok = 1
WDIAGS_PTP = MASTER
PTP_RX delta = 12
PTP_TX delta = 28
RXERR delta = 0
STEP1 = PASS
STEP2 = PASS
STEP4A = PASS

SLAVE:
core_tm_link_up = 1
core_link_ok = 1
WDIAGS_MODE = SLAVE
WDIAGS_PTP = UNCALIBRATED
PTP_RX delta = 25
PTP_TX delta = 10
RXERR delta = 0
parentIsWRnode = 1
parentCalibrated = 1
LOCK_ENABLE_COUNT = 3
STEP1 = PASS
STEP2 = INVALID
STEP3 = PASS
STEP4B = BLOCKED_BY_STEP2
```

### Trial 2

```text
MASTER:
core_tm_link_up = 1
core_link_ok = 1
WDIAGS_PTP = MASTER
PTP_RX delta = 11
PTP_TX delta = 24
RXERR delta = 0
STEP1 = PASS
STEP2 = PASS
STEP4A = PASS

SLAVE:
core_tm_link_up = 1
core_link_ok = 1
WDIAGS_MODE = SLAVE
WDIAGS_PTP = UNCALIBRATED
PTP_RX delta = 23
PTP_TX delta = 11
RXERR delta = 0
parentIsWRnode = 1
parentCalibrated = 1
LOCK_ENABLE_COUNT = 3
STEP1 = PASS
STEP2 = INVALID
STEP3 = PASS
STEP4B = BLOCKED_BY_STEP2
```

### Trial 3

```text
MASTER:
core_tm_link_up = 0
core_link_ok = 0
WDIAGS_PTP = MASTER
PTP_RX delta = 0
PTP_TX delta = 1
RXERR delta = 0
STEP1 = FAIL

SLAVE:
core_tm_link_up = 0
core_link_ok = 0
WDIAGS_MODE = SLAVE
WDIAGS_PTP = DISABLED
PTP_RX delta = 0
PTP_TX delta = 0
RXERR delta = 0
parentIsWRnode = 1
parentCalibrated = 1
LOCK_ENABLE_COUNT = 1
STEP1 = FAIL
STEP2 = INVALID
STEP3 = INVALID
STEP4B = BLOCKED_BY_STEP1
```

### 延長等待後 recheck

Trial 3 後再等待約 60 秒，結果仍為：

```text
MASTER: core_tm_link_up = 0, core_link_ok = 0, PTP_RX delta = 0
SLAVE: core_tm_link_up = 0, core_link_ok = 0, WDIAGS_PTP = DISABLED
SLAVE: PTP_RX delta = 0, PTP_TX delta = 0
SLAVE: STEP4B_ALLOWED = NO
SLAVE: STEP4B_RESULT = BLOCKED_BY_STEP1
```

## 判定

完整 startup gate 的要求是每一輪都必須同時滿足：Master/Slave link PASS、Master PTP=MASTER、Slave PTP=SLAVE、Slave Step1–3 PASS。三個 cycle 均未滿足：前兩輪 link 已起來但 PTP 仍 UNCALIBRATED，第三輪 link/PTP 都掉下來；延長等待也未恢復。

```text
SAME_SOF_REPROGRAM_REPEATABILITY = FAIL
FULL_STARTUP_GATE_REPRODUCIBILITY = FAIL
LINK_PTP_BRINGUP_STATE = NONDETERMINISTIC
STEP4B_REVALIDATED = NO
FROZEN_BANK_DOUBLE_READ = NOT_RUN
EXPERIMENT_VALID_FOR_STEP5 = NO
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

本輪證明的是同一 SOF 在目前光路與兩張板上的完整 startup gate 無法穩定重現；不能據此宣稱 Step5 或 PI dynamics 失敗。現階段仍停在 upstream link/PTP bring-up，尚未重新取得 Step4B 的有效觀測窗口。

## 下一步交給分支5-WR

請依本報告判斷下一個最小實驗。至少在目前 startup gate 恢復前，不執行 frozen-bank double-read、不修改 PI/firmware/PHY、不跑 1800 秒，也不 merge `main`。
