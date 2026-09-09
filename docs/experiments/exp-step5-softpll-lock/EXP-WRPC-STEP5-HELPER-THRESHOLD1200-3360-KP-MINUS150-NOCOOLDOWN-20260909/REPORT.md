# EXP-WRPC-STEP5-HELPER-THRESHOLD1200-3360-KP-MINUS150-NOCOOLDOWN-20260909

## 判定

本輪不是 Step5 pass：`STEP5_CHAIN_RESULT = NOT_COMPLETE`。

```text
Step 1 PHY / Link             PASS（recovery 後）
Step 2 Endpoint / PTP         PASS（recovery 後）
Step 3 WR Handshake           PASS（recovery 後）
Step 4B Slave SoftPLL Startup PASS
Step 5 Closed-loop Lock       NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

本輪 observer 的量測、位置 accounting 與 reset stability 都有效；但 Helper 沒有 lock，因此 Main、PSTAT 與 300 秒完整鏈條均未啟動或成立。不能 merge，也不能把 threshold 變更當成 Step5 證據。

## 實驗目的

先前最佳的 3360-step、`kp=-150`、每個 accepted tag 更新 PI target 的 coherent run，Helper phase error 曾集中在零附近，但在 threshold=200 下反覆離開 lock band。本輪測試將 Helper acceptance threshold 改成與 Main phase detector 相同的 1200，並恢復每 tag PI target update，以分辨「量測離散/門檻過窄」與「控制器根本未收斂」兩種可能。

## 唯一 firmware 變更

```text
WR node Helper kp                 = -150（不變）
WR node Helper ki                 = -1（不變）
Helper PI target update decimation= 1（恢復每 accepted tag）
Helper lock threshold             = 1200（200 -> 1200）
Helper lock samples               = 10000（不變）
HPLL bootstrap                    = 3360 steps, reverse=1（不變）
HPLL normal cooldown              = 0（恢復 no-cooldown baseline）
```

另外修正 trajectory observer 的契約：`read_helper_pair` 原先把 threshold 寫死為 200，現在接受本實驗的 1200；這是觀測器修正，不參與 firmware 控制。

## Build / program provenance

Pain 端從 GitHub pull 後，在乾淨 worktree 完整編譯 Master/Slave JTAG image。

```text
SOURCE_COMMIT  = 1a2d1ff7787d7f75b71594a494a73e332f38184b
STARTED        = 2026-09-09T11:02:32+08:00
BUILD_COMPLETED= 2026-09-09T11:11:34+08:00
```

SOF SHA-256：

```text
master = 9bb47f80ed34b9848e9e424704f7e00faf0611c4040035d1169b9f31ef653ac7
slave  = c11cbd88b090a501a1d2eb0c6c99c98b172e2f59d38e7ec8f0399b03229ba02b
```

第一次 Master→45 秒→Slave 後的 preflight 出現短暫 Step1 error，Slave Step4B 被 upstream prerequisite 擋下。依 recovery path 再次 Master→45 秒→Slave→60 秒後，Step1/2/3/4B 全部 PASS；此 recovery 結果才作為 observer 的有效起點。

## Corrected 600-sample coherent observer

Slave `DE5 [1-11.2]` 觀測約 140.4 秒，600 個 snapshot 全部 coherent；這次 observer 已正確接受並讀到 threshold=1200，沒有再出現因 threshold 契約不符而造成的 `INVALID` lock 欄位。

```text
SAMPLES                         = 600
POST_BOOTSTRAP_BASELINE_SET    = 1
COHERENT_MEASUREMENT_SNAPSHOTS = 600
REJECTED_EPOCH_SNAPSHOTS       = 0
MEASUREMENT_ACCOUNTING_FAILS   = 0
POSITION_SNAPSHOTS              = 600
POSITION_INVARIANT_FAILS        = 0
TRANSACTION_INVARIANT_FAILS     = 0
DCO_INVARIANT_FAILS             = 0
MEASUREMENT_COHERENCE           = PASS
POSITION_ACCOUNTING             = PASS

FREQ_ERROR_MEAN                = 13.3533333333
FREQ_ERROR_RMS                 = 17.0792271488
FREQ_ERROR_MIN                 = -16
FREQ_ERROR_MAX                 = 46
HELPER_ERROR_MEAN              = -150000.0
HELPER_ERROR_RMS               = 150000.0
HELPER_ERROR_MAX_ABS           = 150000
FRACTION_ABS_ERROR_LE_200      = 0.0

HELPER_OUTPUT_SAMPLES           = 600
LOW_RAIL_FRACTION               = 0.0
HIGH_RAIL_FRACTION              = 1.0
NO_RAIL_FRACTION                = 0.0
LOCK_COUNT_MAX                  = 9
LOCK_COUNT_FINAL                = 9
LOCK_COUNT_RISE_EVENTS          = 12
LOCK_COUNT_FALL_EVENTS          = 12
ERROR_BAND_EXIT_EVENTS          = 0
ACTUATOR_HUNT_OBSERVED          = NO
HELPER_DYNAMICS                 = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT

TARGET_FINAL                    = 65531
APPLIED_FINAL                   = 65541
EXPECTED_APPLIED_ABSOLUTE       = 65541
NORMAL_REQ_DELTA_OBSERVED       = 0
NORMAL_COMPLETED_DELTA          = 0
FINC_DELTA                      = 0
FDEC_DELTA                      = 0
DCO_STEP_DELTA                  = 0
BOOTSTRAP_COMPLETED_FINAL       = 3360
BOOTSTRAP_DONE_FINAL             = 1

HELPER_LOCKED_SEEN               = 0
HELPER_LOCKED_FINAL              = 0
MAIN_ENABLED_FINAL               = 0
MAIN_FREQ_LOCKED_FINAL           = 0
MAIN_PHASE_LOCKED_FINAL          = 0
MAIN_LOCKED_FINAL                = 0
PSTAT_LOCKED_FINAL               = 0
FULL_CHAIN_300S                  = 0
STEP5_CHAIN_RESULT               = NOT_COMPLETE

SPLL_DELOCK_COUNT_FIRST         = 0
SPLL_DELOCK_COUNT_MAX           = 246
SPLL_DELOCK_COUNT_FINAL         = 0
RESET_BOOT_GENERATION_DELTA     = 0
RESET_CPU_DELTA                 = 0
RESET_WR_CORE_DELTA             = 0
RESET_SI_CONFIG_DELTA            = 0
RESET_STABLE                    = PASS
```

觀測結尾仍為：

```text
HELPER_ERROR_FINAL  = -150000
HELPER_OUTPUT_FINAL = 65531
TARGET_FINAL        = 65531
APPLIED_FINAL       = 64645
NORMAL_REQ_DELTA    = 0
NORMAL_COMPLETED_DELTA = 0
HELPER_LOCKED       = 0
MAIN_ENABLED        = 0
PSTAT_LOCKED        = 0
```

此 run 的實際控制行為是 Helper 長時間把 PI output 推到 high rail，HPLL target 也停在 high rail；因此即使 acceptance threshold 放寬，Helper 並沒有進入可測試的 near-zero lock region。這輪不能證明 1200 threshold 足以形成真鎖，也不能把 `FREQ_ERROR_RMS` 低誤認成 phase lock。

## 結論與下一步

本輪排除了「只要把 Helper threshold 從 200 放到 1200 就能直接通過 Step5」這個假設。更重要的現象是：相同 no-cooldown/每 tag baseline 在不同 fresh recovery run 可能分別落在 near-zero 或 high-rail；這表示目前還有 startup operating-point、初始 target/applied position 或 DCO feedback polarity/plant state 的未封閉問題，不能只繼續掃 threshold、cooldown 或 decimation。

下一輪先做一個受控的 startup operating-point audit：保留 `kp=-150`、`ki=-1`、no-cooldown、threshold=1200，增加唯讀的 Helper PI initial bias、first post-bootstrap target/applied、first normal FINC/FDEC direction、以及 target-applied residual 時序；若 source audit 證實 Helper 一開始即被推向 rail，才修改 startup bias/target admission，使它從實際 applied position 開始收斂。仍須以 Helper lock、Main frequency/phase lock、PSTAT locked、reset stability 與至少 300 秒完整窗口作為 Step5 pass 條件。

## 原始證據

本資料夾 `raw/` 保存 build、燒錄、recovery、preflight 與 corrected observer 原始輸出。Pain 端 archive：

```text
raw/raw-transfer.tgz
SHA256 = 51843cb7625b481feecbf01cfc3a047a38a8f2c9d560d97058962b77d373adbe
```

主要檔案：

```text
raw/observer-slave-coherent-600.log
raw/preflight.log
raw/preflight-recovery.log
raw/program-master.log
raw/program-slave.log
raw/program-master-recovery.log
raw/program-slave-recovery.log
raw/identity.txt
raw/sof-sha256.txt
```
