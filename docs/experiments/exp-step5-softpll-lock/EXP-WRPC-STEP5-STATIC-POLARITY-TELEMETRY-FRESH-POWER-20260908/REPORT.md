# EXP-WRPC-STEP5-STATIC-POLARITY-TELEMETRY-FRESH-POWER-20260908

## 結論

本輪加入唯讀 actuator-direction telemetry，並維持 Slave 的 isolated static
設定：`STEP5_BOOTSTRAP_STEPS=1024`、`STEP5_BOOTSTRAP_REVERSE=0`、normal
HPLL tracker 關閉。這次先透過 `pain-shutdown` 完成實體斷電重開，再依
Master → 45 秒 → Slave 燒錄；冷啟動 preflight 1–2 仍未建立 link，依已知
recovery procedure 對同一 SOF 再配置一次後，preflight 3 恢復 Step1–4B。

在這個乾淨 power-cycle 起點的有效 upstream 窗口中，telemetry 明確顯示
`STEP5_BOOTSTRAP_REVERSE=0` 對應 `1024` 次 FDEC：

```text
BOOTSTRAP_COMPLETED = 1024
FORCED_FINC = 0
FORCED_FDEC = 1024
FORCED_COMPLETED = 1024
```

但 Helper 仍停在負向飽和，沒有形成 lock：

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_TO_STEP3 = PASS (preflight 3)
STEP4B = PASS (preflight 3)
STEP5 = NOT_PASS
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

因此本輪完成了「數位 polarity → 實際完成交易方向」的證明，但尚未完成
「FINC/FDEC → Helper physical response」的 lock 證明。

## 版本、變更、編譯與燒錄

- Branch：`exp/step5-softpll-lock`
- Source commit：`ec08bfe1bfb5af06ba6781cd6527b83637050b56`
- 本輪 source 變更：Step5 convergence observer 讀取既有
  `WR_STEP5_ACTUATOR_DEBUG_SLAVE` probe 49，輸出 `FORCED_FINC`、
  `FORCED_FDEC`、`FORCED_COMPLETED`；沒有新增 functional control
- Slave 設定：`STEP5_BOOTSTRAP_STEPS=1024`、
  `STEP5_BOOTSTRAP_REVERSE=0`、`ENABLE_NORMAL_HPLL_TRACKER=0`
- Firmware rebuild scripts 回傳 `1`，原因是 pain 上既有 root-owned cache
  無法移除；firmware tree 無變更，因此沿用相同 MIF。這個限制已保留在
  raw identity，沒有把 firmware rebuild 誤報成成功
- Master/Slave full Quartus compile：成功，Quartus Prime Standard 17.0
  Build 595
- `pain-shutdown`：UI power control 關閉 → 等待 10 秒 → 開啟，並重新辨識
  藍色「開啟」狀態；120 秒後 SSH 恢復
- 初次 power-cycle 後燒錄：Master `DE5 [1-11.1]` → 等待 45 秒 → Slave
  `DE5 [1-11.2]`
- cold-start preflight 1–2 未建立 link；recovery reprogram 再次使用
  Master → 45 秒 → Slave，兩次 Programmer 均 `Configuration succeeded`、
  `0 errors, 0 warnings`

SOF SHA-256：

```text
Master cd1b442428a5835c1a3524a3638742f127d72a7cbe578f90ec12cd1b748ef7de
Slave  b4bbfe38cd31a0a3dca96358e35597fb84bd9fdca02ce41af569ac99ae0b4d9c
```

Timing 尚未 closed：Master worst setup slack `-0.246 ns`、Slave
`-0.264 ns`。

## Upstream preflight

Power-cycle 後第一、第二個窗口都仍是 cold-start blocker：Master/Slave
`core_tm_link_up=0`、`core_link_ok=0`，Master PTP 為 `MASTER` 但 RX delta
為 0，Slave 為 `LISTENING` 且 RX delta 為 0；Step4B 被 `STEP1` 擋住。

重新配置同一 SOF 後的 preflight 3 恢復：

```text
Master core_tm_link_up = 1
Master core_link_ok    = 1
Master WDIAGS_PTP      = 6 MASTER
Master PTP_RX delta    = 13
Master PTP_TX delta    = 28

Slave  core_tm_link_up = 1
Slave  core_link_ok    = 1
Slave  WDIAGS_PTP      = 9 SLAVE
Slave  PTP_RX delta    = 23
Slave  PTP_TX delta    = 3

STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

正式 Step5 觀測只採用 preflight 3 之後的資料，沒有把前兩個 cold-start
窗口混入 Step5 統計。

## 120 秒 Helper 觀測與方向證據

Slave 執行 `1200` samples、每次間隔 `100 ms`：

```text
SAMPLES = 1200
VALID_FRAMES = 1200
INVALID_FRAMES = 0
WINDOW_SECONDS = 119.900

BOOTSTRAP_COMPLETED_FINAL = 1024
BOOTSTRAP_DONE_FINAL = 1
FORCED_FINC_FIRST = 0
FORCED_FDEC_FIRST = 1024
FORCED_COMPLETED_FIRST = 1024
FORCED_FINC_DELTA = 0
FORCED_FDEC_DELTA = 0
FORCED_COMPLETED_16_DELTA = 0
DCO_STEP_DELTA = 0
NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
NORMAL_TRANSACTION_ACCOUNTING = PASS

HELPER_LOCK_COUNT_MAX = 5531
HELPER_LOCK_COUNT_FINAL = 1
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
FIRST_HELPER_LOCK_SAMPLE = NONE

HELPER_ERROR_SAMPLES = 1200
HELPER_ERROR_MEAN = -148738.960833
HELPER_ERROR_RMS = 149447.056075
HELPER_ERROR_MAX_ABS = 150000
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD = 0.166666666667
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

第一個有效 sample 已經顯示 bootstrap 完成，因此 `*_DELTA=0` 是因為正式
觀測區間在 bootstrap 後開始；方向欄位仍保留了本次 bootstrap 的累積結果。
這排除了「本次 observer 沒有捕捉到 direction」的疑問。

`HELPER_LOCK_COUNT_MAX=5531` 低於 `HELPER_LOCK_SAMPLES=10000`，而且
`HELPER_LOCKED_SEEN=0`、final count 為 1，不能當作短暫 Step5 PASS。固定
FDEC 1024 steps 後 Helper error 仍在負向飽和端，表示目前 operating point
仍不可鎖定，或外部 actuator state/映射仍需要進一步辨識。

## Step5 判定與下一步

```text
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

下一輪只把 polarity 改回 `STEP5_BOOTSTRAP_REVERSE=1`，保留 `1024` steps、
normal tracker off 與本輪 telemetry，並再次使用 `pain-shutdown` 後的
Master → Slave recovery protocol。成功條件是先確認 telemetry 為
`FORCED_FINC=1024、FORCED_FDEC=0`，再看 Helper error 是否離開負向 rail。
只有在兩方向都被乾淨起點證明後，才決定 `512/2048` coarse bracket 或修正
更深層的 SI5340 page/mask/physical mapping；本輪不改 PI、lock threshold
或 Main loop。

完整 build、program、power-cycle、preflight、telemetry 與 120 秒觀測均在：

`raw/EXP-WRPC-STEP5-STATIC-POLARITY-TELEMETRY-FRESH-POWER-20260908/`

封存 tar SHA-256：

`dc296c60673e9ef300d91121826766d3e1b3fe5f40d5470212b972b535e8db24`
