# EXP-WRPC-STEP5-LANE2-SAME-SOF-MASTER-FIRST-PROGRAM-ORDER-3X-20260901

## 實驗目的

依分支5-WR 最新建議，固定同一對 SOF，不重新編譯，將 programming order 從 `Slave→Master` 改成 `Master→等待 Master ready→Slave`，執行三次 startup preflight，確認 programming order 是否造成先前的 link/PTP 非決定性。

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

本輪沒有 rebuild、沒有 source 修改、沒有 PI/PHY/通訊角色手動修改，也沒有執行 frozen-bank double-read 或 1800 秒 Step5 observer。唯一變因是 programming order。

## SOF provenance

```text
MASTER_SOF_SHA256 = ce400592f498efe98a8a45aa6630ca2379c17ef637c3e6be44376c24c3db16aa
SLAVE_SOF_SHA256 = 292bc51a9ad08fa5575126a42ba11e67771aaa1faaca47b74ebb681984abd016
```

三個 cycle 都使用同一對已核對 hash 的 SOF。每次 Master 與 Slave programming 均成功配置 1 device、0 errors。

## Trial 結果

每一輪均先 program Master，確認 Master `WRC_MODE=MASTER`、`PTP=MASTER`、`wr_ready=1`、`wr_rx_ready=1`、`wr_tx_ready=1`，再 program Slave；沒有加入 shell command。

### Trial 1

第一次 preflight（Slave programming 後等待約 30 秒）：

```text
MASTER: core_tm_link_up = 1, core_link_ok = 1, PTP = MASTER
SLAVE: core_tm_link_up = 1, core_link_ok = 1, PTP = SLAVE
SLAVE: LOCK_ENABLE = 0
SLAVE: STEP1 = PASS, STEP2 = PASS, STEP3 = INVALID
SLAVE: STEP4B = BLOCKED_BY_STEP3
```

再等待約 60 秒 recheck：

```text
MASTER: core_tm_link_up = 1, core_link_ok = 1, PTP = MASTER
MASTER: PTP_RX delta = 0, RXERR delta = 0, STEP4A = PASS
SLAVE: core_tm_link_up = 1, core_link_ok = 1, PTP = SLAVE
SLAVE: PTP_RX delta = 15, PTP_TX delta = 10, RXERR delta = 0
SLAVE: parentIsWRnode = 1, parentCalibrated = 1, LOCK_ENABLE = 0
SLAVE: STEP1 = PASS, STEP2 = PASS, STEP3 = INVALID
SLAVE: STEP4B = BLOCKED_BY_STEP3
```

Trial 1 未達完整 gate。

### Trial 2

第一次 preflight（Slave programming 後等待約 30 秒）：

```text
MASTER: core_tm_link_up = 1, core_link_ok = 1, PTP = MASTER
SLAVE: core_tm_link_up = 1, core_link_ok = 1, PTP = UNCALIBRATED
SLAVE: PTP_RX delta = 26, PTP_TX delta = 10, RXERR delta = 0
SLAVE: parentIsWRnode = 1, parentCalibrated = 1, LOCK_ENABLE = 4
SLAVE: STEP1 = PASS, STEP2 = INVALID, STEP3 = PASS
SLAVE: STEP4B = BLOCKED_BY_STEP2
```

再等待約 60 秒 recheck：

```text
MASTER: core_tm_link_up = 1, core_link_ok = 1, PTP = MASTER
MASTER: PTP_RX delta = 11, PTP_TX delta = 24, RXERR delta = 0
MASTER: STEP1 = PASS, STEP2 = PASS, STEP4A = PASS
SLAVE: core_tm_link_up = 1, core_link_ok = 1, PTP = SLAVE
SLAVE: PTP_RX delta = 24, PTP_TX delta = 2, RXERR delta = 0
SLAVE: parentIsWRnode = 1, parentCalibrated = 1, LOCK_ENABLE = 4
SLAVE: STEP1 = PASS, STEP2 = PASS, STEP3 = PASS
SLAVE: STEP4B_ALLOWED = YES, STEP4B_RESULT = PASS
```

Trial 2 在延長等待後達到完整 Step1–4B gate；Step5 仍是 `NEVER_LOCKED`，本輪沒有執行 Step5 observer。

### Trial 3

Master ready check 通過 `WRC_MODE=MASTER`、`PTP=MASTER`、`wr_ready=1`、`wr_rx_ready=1`、`wr_tx_ready=1` 後才 program Slave。

第一次 preflight（Slave programming 後等待約 60 秒）：

```text
MASTER: core_tm_link_up = 0, core_link_ok = 0, PTP = MASTER
SLAVE: core_tm_link_up = 0, core_link_ok = 0, PTP = LISTENING
SLAVE: PTP_RX delta = 0, PTP_TX delta = 1, RXERR delta = 0
SLAVE: parentIsWRnode = 0, parentCalibrated = 0, LOCK_ENABLE = 0
SLAVE: STEP1 = FAIL, STEP2 = INVALID, STEP3 = INVALID
SLAVE: STEP4B = BLOCKED_BY_STEP1
```

再等待約 60 秒 recheck 仍為：

```text
MASTER: core_tm_link_up = 0, core_link_ok = 0, PTP_RX delta = 0
SLAVE: core_tm_link_up = 0, core_link_ok = 0, PTP = LISTENING
SLAVE: PTP_RX delta = 0, PTP_TX delta = 1, RXERR delta = 0
SLAVE: STEP4B_ALLOWED = NO, STEP4B_RESULT = BLOCKED_BY_STEP1
```

Trial 3 未達完整 gate。

## 正式判定

在可接受的延長等待觀測點，Trial 1 FAIL、Trial 2 PASS、Trial 3 FAIL。即使 Trial 2 能夠恢復完整 Step1–4B，三次結果仍未達到 repeatability 要求。

```text
MASTER_FIRST_PROGRAM_ORDER = FAIL
FULL_STARTUP_GATE_REPRODUCIBILITY = FAIL
PROGRAM_ORDER_NOT_SUFFICIENT = YES
LINK_PTP_BRINGUP_NONDETERMINISM = CONFIRMED
STEP4B_REVALIDATED = NO
FROZEN_BANK_DOUBLE_READ = NOT_RUN
EXPERIMENT_VALID_FOR_STEP5 = NO
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

本輪顯示：同一 SOF、同一光路、僅改 programming order，仍會在 `LOCK_ENABLE/PTP` 或 core link boundary 出現不同結果。這是比 Helper PLL 更上游的 startup/link/PTP bring-up 問題，不能拿來裁決 `ki=-1` 或宣稱 Step5。

## 下一步交給分支5-WR

請依本報告判斷下一個最小的 reset/transceiver/PTP startup timeline 或 image A/B 實驗。在上游 gate 穩定前，不執行 frozen-bank double-read、不修改 PI/firmware/PHY、不跑 1800 秒，也不 merge `main`。
