# EXP-WRPC-STEP5-HPLL-ZERO-CROSSING-3360-KP-MINUS150-COOLDOWN32-PI-DECIMATE64-PHASE-GUARD-20260909

## 判定

本輪 `STEP5_CHAIN_RESULT = NOT_COMPLETE`，不是 Step5 pass。

| 項目 | 結果 |
|---|---|
| Step 1 PHY / Link | PASS（恢復重燒後） |
| Step 2 Endpoint / PTP | PASS（恢復重燒後） |
| Step 3 WR Handshake | PASS（恢復重燒後） |
| Step 4B Slave SoftPLL Startup | PASS |
| Step 5 Closed-loop Lock | 未完成；第一個 inactive boundary = `HELPER_LOCK` |

這輪證明量測鏈、位置 accounting 與 reset 穩定性沒有失效，但沒有證明 closed-loop lock。不得將本輪標記為 Step5 PASS。

## 實驗假設與修改

目的：驗證 Helper PI target 更新降採樣是否能降低 HPLL actuator hunting，同時保留每個 accepted tag 的 lock detector。

本輪 source commit：

```text
88aebb3a7062907d13a696168ebc7d49c086093d
```

參數與既有設定：

```text
Helper kp                    = -150
Helper ki                    = -1
Helper lock threshold        = 200
Helper lock samples          = 10000
Helper delock samples        = 100
PI target update decimation  = 64 accepted tags
HPLL normal cooldown         = 32 loads
HPLL bootstrap               = 3360 physical steps, reverse=1
HPLL tracker code/step       = 64
DPLL tracker code/step       = 16
```

唯一 functional hypothesis change 是 `spll_helper.c`：PI lock detector 仍每個 accepted sample 執行，但 `DAC_HPLL` 的 PI target MMIO 更新每 64 個 sample 才寫一次；未到更新點時保留既有 PI output。這不是 parser、VUART、WR handshake 或 SI5340 page/mask 修改。

## Build、燒錄與恢復

Pain 端 clean worktree 完整編譯成功，build identity：

```text
STARTED        = 2026-09-09T09:52:10+08:00
BUILD_COMPLETED= 2026-09-09T10:01:17+08:00
```

JTAG SOF SHA-256：

```text
master = ac965a5d6978fa3e5107ab155e9b006224eeb0ccb8b8290e1d6ba68411f6b8d5
slave  = 704fcce9967823c8526187b4adddd5166def928cefdda193da69397beb1d93c4
```

初次燒錄後，3600-sample observer 在 sample 2138 之後遭遇連續 invalid/all-zero JTAG/WB frame，沒有產生可用的完整 summary；該 log 僅作為 transport failure 診斷，不納入 Step5 數值判定。

之後依序重新燒錄 Master，等待 45 秒，再燒錄 Slave，等待 60 秒。恢復後 preflight 通過 Step1、Step2、Step3、Step4B，且 `BOOT_GENERATION`、CPU、WR core、SI config 在觀測期間沒有新增 reset。

## 600-sample coherent observer 結果

觀測時間約 76.8 秒；600 個 snapshot 全部 coherent，沒有 rejected epoch snapshot 或 accounting failure。

```text
SAMPLES                         = 600
COHERENT_MEASUREMENT_SNAPSHOTS = 600
REJECTED_EPOCH_SNAPSHOTS       = 0
MEASUREMENT_ACCOUNTING_FAILS   = 0
POSITION_SNAPSHOTS              = 600
POSITION_INVARIANT_FAILS        = 0
TRANSACTION_INVARIANT_FAILS     = 0
DCO_INVARIANT_FAILS             = 0
MEASUREMENT_COHERENCE           = PASS
POSITION_ACCOUNTING             = PASS

FREQ_ERROR_MEAN                = -250.895
FREQ_ERROR_RMS                 = 251.195498235
FREQ_ERROR_MIN                 = -287
FREQ_ERROR_MAX                 = -219
HELPER_ERROR_MEAN              = -150000.0
HELPER_ERROR_RMS               = 150000.0
HELPER_ERROR_MAX_ABS           = 150000
FRACTION_ABS_ERROR_LE_200      = 0.0

HELPER_OUTPUT_SAMPLES           = 600
LOW_RAIL_FRACTION               = 0.0
HIGH_RAIL_FRACTION              = 1.0
NO_RAIL_FRACTION                = 0.0
LOCK_COUNT_MAX                  = 11
LOCK_COUNT_FINAL                = 1
LOCK_COUNT_RISE_EVENTS          = 19
LOCK_COUNT_FALL_EVENTS          = 19
ERROR_BAND_EXIT_EVENTS          = 0
ACTUATOR_HUNT_OBSERVED          = NO
HELPER_DYNAMICS                 = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT

TARGET_FINAL                    = 65531
APPLIED_FINAL                   = 10245
EXPECTED_APPLIED_ABSOLUTE       = 10245
NORMAL_REQ_DELTA_OBSERVED       = 117
NORMAL_COMPLETED_DELTA          = 117
FINC_DELTA                      = 117
FDEC_DELTA                      = 0
DCO_STEP_DELTA                  = 117
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
SPLL_DELOCK_COUNT_MAX           = 189
SPLL_DELOCK_COUNT_FINAL         = 0
RESET_BOOT_GENERATION_DELTA     = 0
RESET_CPU_DELTA                 = 0
RESET_WR_CORE_DELTA             = 0
RESET_SI_CONFIG_DELTA            = 0
RESET_STABLE                    = PASS
```

末段仍維持：

```text
HELPER_ERROR_FINAL  = -150000
HELPER_OUTPUT_FINAL = 65531
HELPER_LOCKED       = 0
MAIN_ENABLED        = 0
PSTAT_LOCKED        = 0
```

因此 decimation=64 沒有改善鎖定，反而使 coarse acquisition 太慢：在有效觀測窗結束時 target 已在 high rail，而 applied code 僅到 10245，Helper error 仍在負 rail。這個 A/B 假設應排除，不能繼續單純增加 cooldown 或 decimation。

## 與前一輪結果的關係

既有 cooldown32、未降採樣的觀測曾能把 Helper 拉近零交越，但仍出現 hunting，且沒有形成穩定的 Helper/Main/PSTAT lock。這輪將 target update 直接改成每 64 samples 後，連 coarse acquisition 都未完成；所以問題不是只靠降低寫入頻率即可解決。

目前最合理的下一個方向是 conditional two-stage controller：

1. coarse acquisition 期間每個 accepted tag 更新 PI target，避免從 high rail 慢慢追。
2. 只有當 Helper error 進入明確的 near-zero window 後，才啟用較慢的 target update 或較小的 fine-loop gain，以抑制零交越附近的 hunting。
3. lock detector 維持獨立，仍須連續通過 Helper lock、Main frequency/phase lock、PSTAT locked，以及至少 300 秒穩定窗口，才可判定 Step5 PASS。

此方向尚未在本輪實作或宣稱通過，下一輪需先以 source audit 確認 error 單位、target/applied 語意與 lock gate 的實際邊界，再建立新的 A/B 實驗。

## 原始證據

本資料夾 `raw/` 包含 build、燒錄、preflight 及 observer 原始輸出。Pain 端封存檔：

```text
raw/raw-transfer.tgz
SHA256 = a3ac54d41376c1afab2673c27dfd5e6c57235b174481d08a355f5616fed5c265
```

主要檔案：

```text
raw/observer-slave-coherent-600.log
raw/observer-slave-coherent-3600.log
raw/preflight-recovery.log
raw/preflight-post.log
raw/identity.txt
raw/sof-sha256.txt
```
