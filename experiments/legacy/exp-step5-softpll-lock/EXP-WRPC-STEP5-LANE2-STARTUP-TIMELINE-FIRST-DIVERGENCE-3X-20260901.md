# EXP-WRPC-STEP5-LANE2-STARTUP-TIMELINE-FIRST-DIVERGENCE-3X-20260901

## 結論

本輪完成了分支5-WR 指定的 diagnostic-only startup timeline。三個正式
Master-first → wait Master ready → Slave cycles 都成功取得兩張板的唯讀時間軸，
每張板各 68 筆、約 121 秒，`sample_errors=0`，且每一輪都能分類第一個非穩定邊界。

但是本輪**不是 Step5 pass**：

```text
STARTUP_TIMELINE_CAPTURE = PASS
FIRST_INACTIVE_BOUNDARY_IDENTIFIED = YES
UNCLASSIFIED_STARTUP_FAILURES = 0

STEP4B_STARTUP_EVENT_ACTIVITY = OBSERVED
STEP4B_REVALIDATED_BY_POST_TRIAL_PREFLIGHT = YES
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

最後一次 read-only runtime preflight 明確得到：

```text
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE

STEP5_LOCKDET_BEFORE: HELPER locked=0 cnt=100/10000 threshold=200
STEP5_LOCKDET_AFTER:  HELPER locked=0 cnt=264/10000 threshold=200
PSTAT_locked = 0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

因此不能 merge `exp/step5-softpll-lock` 到 `main`。

## 固定條件

本輪使用 branch `exp/step5-softpll-lock`，observer source commit 為
`9d0ea1d`。這個 commit 只改 read-only Tcl observer；沒有 rebuild，沒有修改
RTL、firmware、SoftPLL、PI、PHY、lane 或 PTP role。

```text
MASTER_SOF_SHA256 = ce400592f498efe98a8a45aa6630ca2379c17ef637c3e6be44376c24c3db16aa
SLAVE_SOF_SHA256  = 292bc51a9ad08fa5575126a42ba11e67771aaa1faaca47b74ebb681984abd016

QSFPA data path = lane 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

每一輪固定：

```text
Program Master DE5 [1-11.1]
→ wait until Master WRC_MODE=MASTER, PTP=MASTER,
  wr_ready=1, wr_rx_ready=1, wr_tx_ready=1, core_link_ok=1
→ Program Slave DE5 [1-11.2]
→ immediately start the two instances of the same read-only timeline observer
```

Observer 取樣規格為 0–30 秒目標每 1 秒、30–120 秒目標每 2 秒；實際因 JTAG
transaction overhead，前三輪各取得 26 筆 early-window samples 與總計 68 筆，
時間戳仍完整記錄於 raw logs。

## 觀測內容

兩張板都記錄：

```text
si_config_done, wr_ready, wr_rx_ready, wr_tx_ready
wr_rx_locked_to_data, wr_rx_enc_err, wr_tx_enc_err
core_tm_link_up, core_link_ok
WRC_MODE, PTP_STATE, PTP_RX_COUNT, PTP_TX_COUNT, RXERR_COUNT
BOOT_GENERATION, CPU_RESET_COUNT, WR_CORE_RESET_COUNT, SI_CONFIG_RESET_COUNT
```

並記錄 Slave 的：

```text
FOREIGN_META, parentIsWRnode, parentModeOn, parentCalibrated
WR RX/TX signaling, WR state, LOCK_ENABLE_COUNT
LOCK_CALIB_FAIL_COUNT, LOCK_UNLOCKED_COUNT
SPLL_INIT_COUNT, SPLL_MODE, SPLL_SEQ_STATE, SPLL_ALIGN_STATE, SPLL_DELOCK_COUNT
RCER, OCER
DMTD_REF_ACCEPT, DMTD_FB_ACCEPT, TAG_VALID, TRR_WRITE, TRR_POP
IRQ_COUNT, HELPER_UPDATE_COUNT, PSTAT, PSTAT_LOCKED
```

## 三輪摘要

| Trial | Slave 首次 core link / PTP RX | Slave 首次 parent+calibrated | Slave 首次 LOCK_ENABLE / SPLL init | 120 秒內觀察 | 第一個邊界 |
|---|---:|---:|---:|---|---|
| `TRIAL1-CADENCE` | 486 ms | 486 ms | 486 ms | parent/PTP 多次掉回再恢復；PSTAT lock 未出現 | `STARTUP_GATE`（事件活動已出現，但未形成 Step5 lock） |
| `TRIAL2` | 485 ms | 37077 ms | 23648 ms | parent/PTP 在後段反覆轉換；PSTAT lock 未出現 | `STARTUP_GATE`（早期先有事件活動，後續穩定性失敗） |
| `TRIAL3` | 494 ms | 494 ms | 494 ms | parent/PTP/SoftPLL state 反覆轉換；PSTAT lock 未出現 | `STARTUP_GATE`（事件活動已出現，但未形成 Step5 lock） |

更細的首次量測值：

```text
TRIAL1-CADENCE SLAVE:
  FIRST_CORE_LINK_OK_MS=486
  FIRST_PTP_RX_ACTIVITY_MS=486
  FIRST_DMTD_ACCEPT_MS=486
  FIRST_PARENT_WR_CALIBRATED_MS=486
  FIRST_LOCK_ENABLE_MS=486
  FIRST_SPLL_INIT_MS=486
  FIRST_TAG_VALID_MS=486
  FIRST_TRR_WRITE_MS=486
  FIRST_TRR_POP_MS=486
  FIRST_IRQ_MS=486
  FIRST_HELPER_UPDATE_MS=486
  FIRST_PSTAT_LOCKED_MS=NEVER

TRIAL2 SLAVE:
  FIRST_CORE_LINK_OK_MS=485
  FIRST_PTP_RX_ACTIVITY_MS=485
  FIRST_DMTD_ACCEPT_MS=485
  FIRST_PARENT_WR_CALIBRATED_MS=37077
  FIRST_LOCK_ENABLE_MS=23648
  FIRST_SPLL_INIT_MS=23648
  FIRST_TAG_VALID_MS=22489
  FIRST_TRR_WRITE_MS=22489
  FIRST_TRR_POP_MS=22489
  FIRST_IRQ_MS=22489
  FIRST_HELPER_UPDATE_MS=13220
  FIRST_PSTAT_LOCKED_MS=NEVER

TRIAL3 SLAVE:
  FIRST_CORE_LINK_OK_MS=494
  FIRST_PTP_RX_ACTIVITY_MS=494
  FIRST_DMTD_ACCEPT_MS=494
  FIRST_PARENT_WR_CALIBRATED_MS=494
  FIRST_LOCK_ENABLE_MS=494
  FIRST_SPLL_INIT_MS=494
  FIRST_TAG_VALID_MS=494
  FIRST_TRR_WRITE_MS=494
  FIRST_TRR_POP_MS=494
  FIRST_IRQ_MS=494
  FIRST_HELPER_UPDATE_MS=494
  FIRST_PSTAT_LOCKED_MS=NEVER
```

## First-divergence interpretation

這三輪不是「完全沒有 link」的同一種失敗。三輪都能在 observer window 早期看到
core link、PTP RX、DMTD/event counters；因此失效點不是固定卡在
`WR_CORE_LINK` 或 `PTP_RX`。

分岔發生在後續 startup state 的穩定性：

```text
PTP / parent metadata
→ WR signaling / locking_enable
→ SoftPLL event activity
→ helper lock detector
```

例如 Trial 2 的 Slave 在約 23.6 秒出現 `LOCK_ENABLE` 與 `SPLL_INIT`，約 37.1
秒才首次同時觀察到 parent/calibrated；之後 PTP/parent flags 仍反覆轉換。Trial 1
與 Trial 3 則較早觀察到 event activity，但同樣沒有在 120 秒內得到 helper lock
或 `PSTAT_LOCKED=1`。這解釋了為什麼某些畫面會顯示 Step1/Step4B 的部分 pass，
但總診斷仍不能進入 Step5。

## Raw evidence

Raw logs 保存在 pain：

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-LANE2-STARTUP-TIMELINE-FIRST-DIVERGENCE-3X-20260901/
  TRIAL1-CADENCE.master.timeline.log
  TRIAL1-CADENCE.slave.timeline.log
  TRIAL2.master.timeline.log
  TRIAL2.slave.timeline.log
  TRIAL3.master.timeline.log
  TRIAL3.slave.timeline.log
  post-trial3-runtime-preflight.log
```

Local observer source：

```text
scripts/jtag/read_step5_startup_timeline_first_divergence.tcl
```

## Handoff to 分支5-WR

```text
LATEST_HEAD = 9d0ea1d
STARTUP_TIMELINE_CAPTURE = PASS
FIRST_INACTIVE_BOUNDARY_IDENTIFIED = YES
UNCLASSIFIED_STARTUP_FAILURES = 0

STEP4B_STARTUP_EVENT_ACTIVITY = OBSERVED
STEP4B_REVALIDATED_BY_POST_TRIAL_PREFLIGHT = YES
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

本輪完成了分支5要求的 startup causality diagnosis；下一步應由分支5判斷是否要
進入專門的 helper-lock / WR parent stability 實驗。在它明確核准前，不執行 merge。
