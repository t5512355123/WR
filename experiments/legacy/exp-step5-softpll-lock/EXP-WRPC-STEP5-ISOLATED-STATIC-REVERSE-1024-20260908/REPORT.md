# EXP-WRPC-STEP5-ISOLATED-STATIC-REVERSE-1024-20260908

## 結論

本輪保留目前已驗證的 DCO page/mask 路徑與 persistent reverse bootstrap
polarity，將 Slave 的 normal HPLL tracker 暫時關閉，並執行固定 `1024`
steps 的 static reverse bootstrap。目的不是調 PI，而是把 bootstrap 後的
Helper operating point 固定下來，分離「static actuator position」與「normal
tracker 持續掃過工作點」兩個因素。

本輪先遇到啟動狀態異常：初次燒錄後 preflight 1–5 的 Master PTP 都是
`DISABLED`、Slave 是 `LISTENING`，因此那些窗口不能用來評估 Step5。對同一組
SOF 重新依 Master → 等待 → Slave 順序燒錄並等待 60 秒後，preflight 6 恢復
雙板 PTP 與 Step4B，才進行正式 Step5 觀測。

正式 120 秒觀測的判定如下：

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS (full Quartus compile)
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_TO_STEP3 = PASS (preflight 6)
STEP4B = PASS (preflight 6)
STEP5 = NOT_PASS
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

這是有效的 Step5 負結果，不是 upstream blocker：bootstrap 已完成 `1024`
steps，但固定位置的 Helper error 最終停在負向飽和，`HELPER_LOCKED` 全程
沒有成立。

## 版本、變更、編譯與燒錄

- Branch：`exp/step5-softpll-lock`
- Source commit：`fc5e8aad35ad7e7dc6a343755fc794d581487f32`
- 唯一本輪 top-level 變因：Slave `ENABLE_NORMAL_HPLL_TRACKER = 0`
- 保留：`STEP5_BOOTSTRAP_STEPS = 1024`、`STEP5_BOOTSTRAP_REVERSE = 1`、
  `HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 16` 與既有 page/mask、static-FSM
  completion gate、persistent reverse polarity 修正
- Firmware rebuild scripts 回傳 `1`，原因是 pain 上既有 root-owned cache
  無法移除；本輪 firmware tree 與前一輪相同，因此使用已確認相同的 MIF，並
  在報告中保留該限制，沒有把 firmware rebuild 誤報成成功
- Master/Slave full Quartus compile：成功，Quartus Prime Standard 17.0
  Build 595
- 燒錄：Master `DE5 [1-11.1]` → 等待 45 秒 → Slave `DE5 [1-11.2]`
- 初次與 recovery reprogram 的 Programmer 均為 `Configuration succeeded`、
  `0 errors, 0 warnings`

SOF SHA-256：

```text
Master 959b3fc32c31c8e504c32c3ee02d1cd4873bf25692d394c2b8b1a50a66570f9
Slave  b57c87b1e0fd0139d78603310c565118333129c98af5af5284922ac03b588ee1
```

Timing 仍未 closed：Master worst setup slack `-0.246 ns`、Slave
`-2.335 ns`。Slave timing regression 是本輪重要 implementation caveat，
但不把它單獨當成 Step5 失敗根因。

## 啟動復原與 upstream preflight

初次燒錄後的 preflight 1–5 都是同一類 upstream 問題：

```text
Master core_tm_link_up = 0
Master core_link_ok    = 0
Master WDIAGS_PTP      = 3 DISABLED
Slave  core_tm_link_up = 1
Slave  core_link_ok    = 1
Slave  WDIAGS_PTP      = 4 LISTENING
STEP4B_RESULT          = BLOCKED_BY_STEP2
```

已嘗試的 non-functional recovery 包含 shell-ready gated 讀取（因 firmware
main-loop gate 未成立而中止）以及一次 `mode master\n` 的 post-startup
逐 byte 注入；注入完成後狀態仍未恢復。之後對同一組 SOF 重新燒錄 Master
與 Slave，等待 60 秒後的 preflight 6 為：

```text
Master core_tm_link_up = 1
Master core_link_ok    = 1
Master WDIAGS_PTP      = 6 MASTER
Master PTP_RX delta    = 13
Master PTP_TX delta    = 28

Slave  core_tm_link_up = 1
Slave  core_link_ok    = 1
Slave  WDIAGS_PTP      = 9 SLAVE
Slave  PTP_RX delta    = 30
Slave  PTP_TX delta    = 3

STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

所以正式 Step5 觀測使用的是已恢復且可追溯的 upstream 窗口。

## 120 秒 static Helper 觀測

Slave 執行 `1200` samples、每次間隔 `100 ms`；完整 raw output 在本實驗
`raw/` 資料夾：

```text
SAMPLES = 1200
VALID_FRAMES = 1198
INVALID_FRAMES = 2
WINDOW_SECONDS = 119.901

BOOTSTRAP_COMPLETED_FINAL = 1024
BOOTSTRAP_DONE_FINAL = 1
DCO_STEP_DELTA = 0
NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
FORCED_ACTIVITY_DELTA = 0
NORMAL_TRANSACTION_ACCOUNTING = PASS

HELPER_LOCK_COUNT_MAX = 31
HELPER_LOCK_COUNT_FINAL = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
FIRST_HELPER_LOCK_SAMPLE = NONE

HELPER_ERROR_SAMPLES = 1195
HELPER_ERROR_MEAN = -146736.401674
HELPER_ERROR_RMS = 148359.227051
HELPER_ERROR_MAX_ABS = 150000
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD = 2.17573221757
HELPER_OUTPUT_FINAL_SIGNED = 65531

MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0

RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

`HELPER_LOCK_COUNT_MAX=31` 低於 threshold `200`，且 `HELPER_LOCKED_SEEN=0`，
故沒有短暫 Step5 lock。`DCO_STEP_DELTA=0` 表示正式觀測期間沒有 normal
tracker 交易；bootstrap 的 `1024` steps 已在觀測開始前完成，位置保持固定。
最後的 Helper error 約為 `-150000`，output code 為 `65531`，表示本輪固定
reverse position 位於負向飽和端，而不是可鎖定的 operating point。

## 與前輪的對照

```text
no bootstrap + normal tracker : error mean -142321.905209，normal 4938 steps
persistent reverse 1024       : tracker 同時活動，normal 22525 steps
static reverse 1024            : error mean -146736.401674，normal 0 steps
```

本輪把 normal tracker 關閉後，仍停在負向 rail，排除了「只是 tracker 在
120 秒內持續掃過工作點」這個解釋。搭配 no-bootstrap 結果，可知目前初始
位置與 reverse 方向都在負向側；要找到 Helper lock，下一輪應測試等量的
正向 `1024` steps，而不是先改 PI。

## Step5 判定與下一步

```text
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

下一輪唯一 functional 變因建議為：維持 normal tracker 關閉、維持
`STEP5_BOOTSTRAP_STEPS = 1024`，只將 `STEP5_BOOTSTRAP_REVERSE` 從 `1` 改為
`0`，以相同步數做 opposite-polarity A/B。若正向 1024 仍飽和，再以相同
隔離模式做 `512/2048` 的有界 coarse bracket；在取得 Helper lock 或至少
進入可達區前，不調整 PI、lock threshold 或 Main loop。

完整 build、program、recovery、preflight、120 秒觀測與 checksum evidence
均保留在本目錄的 `raw/`：

`raw/EXP-WRPC-STEP5-ISOLATED-STATIC-REVERSE-1024-20260908/`

封存 tar SHA-256：

`07b2de60da3482ef025f7dbc36d492be660a934ed32dd1d0c9620a3191b73cc4`
