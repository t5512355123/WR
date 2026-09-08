# EXP-WRPC-STEP5-ISOLATED-STATIC-FORWARD-1024-20260908

## 結論

本輪只將 Slave 的 `STEP5_BOOTSTRAP_REVERSE` 從 `1` 改為 `0`，保留
`STEP5_BOOTSTRAP_STEPS=1024`、normal HPLL tracker 關閉、page/mask 路徑、
persistent bootstrap request polarity fix 與其他 Step5 設定不變。目的為對
前一輪 static reverse 1024 做同樣步數的 opposite-polarity A/B。

本輪編譯、燒錄與 upstream preflight 都成功；120 秒 Step5 觀測也成功完成，
但沒有 Helper lock：

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_TO_STEP3 = PASS
STEP4B = PASS
STEP5 = NOT_PASS
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

重要限制：本輪是在前一輪 static reverse 1024 觀測後，未實體斷電便重新燒錄
同一組板卡。SI5340 是有狀態的外部 actuator，因此本輪不能作為乾淨的
polarity 物理 A/B；它只證明「在當時持續的外部狀態下，forward 1024 仍未把
Helper 帶離負向飽和」。下一輪必須實體斷電，並讀取 bootstrap 實際完成的
FINC/FDEC 方向後再判斷 polarity 是否真的作用於晶片。

## 版本、變更、編譯與燒錄

- Branch：`exp/step5-softpll-lock`
- Source commit：`a986315aac5056497d7c08ab100930fcafb1666b`
- 唯一 functional variable：Slave `STEP5_BOOTSTRAP_REVERSE = 0`
- `STEP5_BOOTSTRAP_STEPS = 1024`
- `ENABLE_NORMAL_HPLL_TRACKER = 0`
- Firmware rebuild scripts 回傳 `1`，原因是 pain 上既有 root-owned cache
  無法移除；firmware tree 無變更，因此沿用相同 MIF，並將限制保留在 raw
  identity，沒有把 firmware rebuild 誤報成成功
- Master/Slave full Quartus compile：成功，Quartus Prime Standard 17.0
  Build 595
- 燒錄順序：Master `DE5 [1-11.1]` → 等待 45 秒 → Slave `DE5 [1-11.2]`
- Programmer：兩板均 `Configuration succeeded`、`0 errors, 0 warnings`

SOF SHA-256：

```text
Master ed6262d7a84fff4678ed1649f6021a6f6b21bdae8aa02009d1022e46ea78a6a3
Slave  7f4a8bddb81352ce26f742da4a3aa469d5e86b6b9dde1e4ec8ae7062e9e76607
```

Timing 尚未 closed：Master worst setup slack `-0.246 ns`、Slave
`-0.264 ns`。

## Settled preflight

燒錄後等待 45 秒的第一個 preflight 已直接恢復 upstream：

```text
Master core_tm_link_up = 1
Master core_link_ok    = 1
Master WDIAGS_PTP      = 6 MASTER
Master PTP_RX delta    = 12
Master PTP_TX delta    = 27

Slave  core_tm_link_up = 1
Slave  core_link_ok    = 1
Slave  WDIAGS_PTP      = 9 SLAVE
Slave  PTP_RX delta    = 30
Slave  PTP_TX delta    = 2

STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

本輪因此是有效的 Step4B upstream 窗口；Step5 的失敗邊界不是 Step1–4B。

## 120 秒 static Helper 觀測

Slave 執行 `1200` samples、每次間隔 `100 ms`，完整 raw output 位於本目錄
`raw/`：

```text
SAMPLES = 1200
VALID_FRAMES = 1200
INVALID_FRAMES = 0
WINDOW_SECONDS = 119.900

BOOTSTRAP_COMPLETED_FINAL = 1024
BOOTSTRAP_DONE_FINAL = 1
DCO_STEP_DELTA = 0
NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
FORCED_ACTIVITY_DELTA = 0
NORMAL_TRANSACTION_ACCOUNTING = PASS

HELPER_LOCK_COUNT_MAX = 7517
HELPER_LOCK_COUNT_FINAL = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
FIRST_HELPER_LOCK_SAMPLE = NONE

HELPER_ERROR_SAMPLES = 1200
HELPER_ERROR_MEAN = -147852.898333
HELPER_ERROR_RMS = 149080.837894
HELPER_ERROR_MAX_ABS = 150000
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD = 0.0833333333333
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

`HELPER_LOCK_COUNT_MAX=7517` 仍沒有形成有效 lock，因為 `HELPER_LOCKED_SEEN=0`
且 final count 回到 0；不能把中途累積的 detector count 當成 PASS。bootstrap
在觀測開始前已完成，觀測期間沒有 normal DCO transaction，故這是固定位置
觀測，不是 normal tracker 追蹤結果。

## 與前輪的比較與可用性判斷

```text
static reverse 1024：HELPER_ERROR_MEAN = -146736.401674
static forward 1024：HELPER_ERROR_MEAN = -147852.898333
```

兩輪都在同一批板卡上連續進行，沒有在兩輪間實體斷電。數值都落在負向
飽和端，表示當時外部 SI5340 狀態沒有被帶入可鎖定 operating point；但不能
由此單獨推論 `STEP5_BOOTSTRAP_REVERSE` 對應的 FINC/FDEC 寫入沒有改變。

下一輪要增加既有 `WR_STEP5_ACTUATOR_DEBUG_SLAVE` probe 的讀出，確認
`forced_finc_completed_count` 與 `forced_fdec_completed_count` 哪一個累積了
1024 次；再以實體斷電後 fresh-program 的結果判斷物理方向。這個證據比再
做一次未重置外部 actuator 的相同步數 sweep 更有區分力。

## Step5 判定與下一步

```text
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

下一步是：

1. laptop 加入唯讀 actuator-direction telemetry，讀出 bootstrap 完成的
   FINC/FDEC counter，並維持目前 `1024`、normal tracker off 的隔離設定。
2. push 後在 pain pull、重新 full compile/program；program 前先完成一次
   實體斷電，確保 A/B 起點不是上一輪留下的 SI5340 runtime 狀態。
3. settled preflight 通過後再做 120 秒 Helper 觀測。
4. 若方向與物理 response 確認正確但仍飽和，再以同一乾淨起點做 `512/2048`
   有界 coarse bracket；在此之前不改 PI、lock threshold 或 Main loop。

完整 build、program、preflight、120 秒觀測與 checksum evidence 均保留於：

`raw/EXP-WRPC-STEP5-ISOLATED-STATIC-FORWARD-1024-20260908/`

封存 tar SHA-256：

`8a0d31545758d29c35a00e96255626178847ef86477f168726bc17d68eff560f`
