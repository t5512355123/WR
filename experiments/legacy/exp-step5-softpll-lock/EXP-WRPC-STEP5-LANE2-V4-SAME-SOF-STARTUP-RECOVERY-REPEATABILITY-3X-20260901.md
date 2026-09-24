# EXP-WRPC-STEP5-LANE2-V4-SAME-SOF-STARTUP-RECOVERY-REPEATABILITY-3X-20260901

## 結論

本輪依分支5要求，在不 rebuild、不修改 source、不修改控制參數的條件下，
使用同一對 V4 SOF 完成三次 Master-first startup recovery/repeatability。

```text
V4_SOF_PROVENANCE = PASS
MASTER_FIRST_PROGRAM_ORDER = PASS
V4_SAME_SOF_STARTUP_RECOVERY = PASS
STARTUP_TIMELINE_CAPTURE = PASS (3/3)
STEP4B_REVALIDATED = YES
V4_SMOKE = NOT_RUN
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

三輪都取得可信的 Slave Step1–4B clean window；依分支5規則，本輪做到這裡
停止，下一輪才有資格執行 V4 exclusive PI-bank 100-sample smoke。

## Fixed source/image

```text
branch = exp/step5-softpll-lock
V4 source commit = 6943afa
current branch report commit = 4a59697

QSFPA lane = 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

三輪使用完全相同的已核對 SOF：

```text
MASTER_SOF_SHA256 = 0c83bd82a505f64588c5f722f21db66ea2acbfc20b2067cf3c41b6df611ada84
SLAVE_SOF_SHA256  = 822cd8eb26f6eb544572f65bc8db990ef44ad32f3971e4573e57a3042f2f7d37
```

每輪流程固定為：

```text
Program Master DE5 [1-11.1]
→ wait for Master WRC_MODE/PTP/ready
→ Program Slave DE5 [1-11.2]
→ immediately run 120-second read-only startup timeline
→ run one read-only post-preflight
```

沒有執行 V4 double-read、1800 秒 Step5 observer、PI/PHY/lane/PTP 變更或 merge。

## Trial summaries

每張板每輪均取得 56 samples、`sample_errors=0`，觀測時間約 121 秒。

| Trial | Master first core/PTP RX/parent/lock | Slave first core/PTP RX/parent/lock | Slave first event chain | Post-preflight |
|---|---|---|---|---|
| 1 | 1922 / 4954 / NEVER / NEVER ms | 2183 / 2183 / 14359 / 12829 ms | 12829 ms | Step4B PASS |
| 2 | 1908 / 405 / 38214 / NEVER ms | 2172 / 9726 / 14262 / 12750 ms | 12750 ms | Step4B PASS |
| 3 | 1919 / 408 / 78506 / NEVER ms | 2179 / 9762 / 17330 / 12801 ms | 12801 ms | Step4B PASS |

`parent` 欄位是 `parentIsWRnode && parentCalibrated` 首次同時成立時間；
`event chain` 是 TAG/TRR write/TRR pop/IRQ/Helper update 皆開始有活動的時間。
Master 的 Helper lock 欄位對本輪 Slave Step4B 判定不適用；Master Step4A
post-preflight 三輪均 PASS。

## Trial 1 post-preflight

```text
MASTER:
  core_tm_link_up = 1
  core_link_ok = 1
  WRC_MODE = 2 MASTER
  PTP = 6 MASTER
  PTP_RX delta = 10
  PTP_TX delta = 25
  RXERR delta = 0
  STEP4A_RESULT = PASS

SLAVE:
  core_tm_link_up = 1
  core_link_ok = 1
  WRC_MODE = 3 SLAVE
  PTP = 9 SLAVE
  PTP_RX delta = 27
  PTP_TX delta = 2
  RXERR delta = 0
  parentIsWRnode = 1
  parentCalibrated = 1
  LOCK_ENABLE_COUNT = 4
  STEP4B_ALLOWED = YES
  STEP4B_RESULT = PASS
  STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
  STEP5_RESULT = NEVER_LOCKED
  STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

## Trial 2 post-preflight

```text
MASTER:
  core_tm_link_up = 1
  core_link_ok = 1
  WRC_MODE = 2 MASTER
  PTP = 6 MASTER
  PTP_RX delta = 9
  PTP_TX delta = 22
  RXERR delta = 0
  STEP4A_RESULT = PASS

SLAVE:
  core_tm_link_up = 1
  core_link_ok = 1
  WRC_MODE = 3 SLAVE
  PTP = 9 SLAVE
  PTP_RX delta = 25
  PTP_TX delta = 3
  RXERR delta = 0
  parentIsWRnode = 1
  parentCalibrated = 1
  LOCK_ENABLE_COUNT = 4
  STEP4B_ALLOWED = YES
  STEP4B_RESULT = PASS
  STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
  STEP5_RESULT = NEVER_LOCKED
  STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

## Trial 3 post-preflight

```text
MASTER:
  core_tm_link_up = 1
  core_link_ok = 1
  WRC_MODE = 2 MASTER
  PTP = 6 MASTER
  PTP_RX delta = 10
  PTP_TX delta = 23
  RXERR delta = 0
  STEP4A_RESULT = PASS

SLAVE:
  core_tm_link_up = 1
  core_link_ok = 1
  WRC_MODE = 3 SLAVE
  PTP = 9 SLAVE
  PTP_RX delta = 22
  PTP_TX delta = 2
  RXERR delta = 0
  parentIsWRnode = 1
  parentCalibrated = 1
  LOCK_ENABLE_COUNT = 4
  STEP4B_ALLOWED = YES
  STEP4B_RESULT = PASS
  STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
  STEP5_RESULT = NEVER_LOCKED
  STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

## Formal decision

```text
V4_SAME_SOF_STARTUP_RECOVERY = PASS
STARTUP_NONDETERMINISM_BLOCKER = NOT_OBSERVED_IN_THIS_3X_ROUND
STEP1 = PASS (3/3 post-preflight)
STEP2 = PASS (3/3 post-preflight)
STEP3 = PASS (3/3 post-preflight)
STEP4B = PASS (3/3 post-preflight)
RXERR_DELTA = 0 (all post-preflights)
RESET_DELTAS = 0 (all post-preflights)
SPLL_INIT_COUNT = stable within each post-preflight
```

這只證明 V4 image 已重新取得可用的 Step4B live state，不代表 Step5 lock。
目前仍為：

```text
HELPER_LOCKED = 0
PSTAT_LOCKED = 0
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

```text
raw/EXP-WRPC-STEP5-LANE2-V4-SAME-SOF-STARTUP-RECOVERY-REPEATABILITY-3X-20260901-TRIAL1-MASTER-READY-CHECK.log
raw/EXP-WRPC-STEP5-LANE2-V4-SAME-SOF-STARTUP-RECOVERY-REPEATABILITY-3X-20260901-TRIAL1-MASTER-READY-CHECK-EXTENDED.log
raw/EXP-WRPC-STEP5-LANE2-V4-SAME-SOF-STARTUP-RECOVERY-REPEATABILITY-3X-20260901-TRIAL1-TIMELINE.log
raw/EXP-WRPC-STEP5-LANE2-V4-SAME-SOF-STARTUP-RECOVERY-REPEATABILITY-3X-20260901-TRIAL1-POSTPREFLIGHT.log
raw/EXP-WRPC-STEP5-LANE2-V4-SAME-SOF-STARTUP-RECOVERY-REPEATABILITY-3X-20260901-TRIAL2-MASTER-READY-CHECK.log
raw/EXP-WRPC-STEP5-LANE2-V4-SAME-SOF-STARTUP-RECOVERY-REPEATABILITY-3X-20260901-TRIAL2-TIMELINE.log
raw/EXP-WRPC-STEP5-LANE2-V4-SAME-SOF-STARTUP-RECOVERY-REPEATABILITY-3X-20260901-TRIAL2-POSTPREFLIGHT.log
raw/EXP-WRPC-STEP5-LANE2-V4-SAME-SOF-STARTUP-RECOVERY-REPEATABILITY-3X-20260901-TRIAL3-MASTER-READY-CHECK.log
raw/EXP-WRPC-STEP5-LANE2-V4-SAME-SOF-STARTUP-RECOVERY-REPEATABILITY-3X-20260901-TRIAL3-TIMELINE.log
raw/EXP-WRPC-STEP5-LANE2-V4-SAME-SOF-STARTUP-RECOVERY-REPEATABILITY-3X-20260901-TRIAL3-POSTPREFLIGHT.log
```

以上 raw logs 位於 pain server 的 branch working tree；本輪沒有把它們加入
repository，以避免將大量機器產生輸出直接納入 source history。
