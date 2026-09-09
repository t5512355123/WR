# EXP-WRPC-STEP5-HELPER-PI-LOCKSAMPLES1000-CODESTEP64-COOLDOWN0-3360-KP-MINUS150-THRESHOLD1200-20260909

## 判定

本輪 **不是 Step5 PASS**，因此不具備 merge 到 `main` 的條件。

正式判定：

```text
Step1 PHY / Link              PASS
Step2 Endpoint / PTP          PASS
Step3 WR Handshake             PASS
Step4B Slave SoftPLL startup   PASS
Step5 Closed-loop Lock         NOT COMPLETE
```

Step5 的第一個未通過邊界仍是 `HELPER_LOCK`。`MAIN_ENABLED`、`MAIN_FREQ_LOCKED`、`MAIN_PHASE_LOCKED`、`MAIN_LOCKED` 與 `PSTAT_LOCKED` 都維持 0。

## 本輪目的

驗證在保持實際 HPLL physical step 為 64、cooldown 為 0、`kp=-150`、`ki=-1`、threshold 為 1200 的條件下，把 Helper lock dwell 從 10000 個 accepted samples 降到 1000，是否能讓 Helper 進入 lock 並開啟 Main loop。

這是控制參數的 A/B 實驗；沒有改變 threshold、PI gain、DCO direction、SI5340 page-aware four-write、bootstrap direction 或 Main absolute target/applied tracking。

## 實際建置與燒錄

本輪先在 laptop 端提交並推送 source commit：

```text
898dee7452088100339ac40f2f637cc21995f202
```

Pain 端使用正式 firmware build scripts 重新產生 Master/Slave firmware MIF，再執行 Quartus compile，最後重新燒錄兩張板。直接只跑 Quartus compile 的早期嘗試因未重建 firmware MIF，已排除、不列入本輪結果。

SOF SHA-256：

```text
Master 0ac360f5cac6432357382d2a08cbb8bfb740008276ea52595a9b9e9e2deae9485f
Slave  8ab508f61119f68793c31c520b1d47f026a6aa6ba64959eee6aaa7e415e7fde3
```

## 觀測結果

正式觀測窗為 60 秒，共 600 次 snapshot：

```text
VALID_FRAMES                 = 598
INVALID_FRAMES               = 2
PI_TRACE_PRESENT             = 598
PI_SNAPSHOT_REJECTS          = 2
PI_ACCOUNTING_FAILS          = 0
PI_OUTPUT_MISMATCH_FAILS     = 0
MEASUREMENT_COHERENCE         = PASS
POSITION_ACCOUNTING           = PASS
TRANSACTION_ACCOUNTING       = PASS
ATOMIC_SNAPSHOT_TRANSPORT_V3  = PASS
```

Helper phase/error：

```text
HELPER_ERROR_MEAN             = 7.0585
HELPER_ERROR_RMS              = 654.0193
HELPER_ERROR_MAX_ABS          = 1959
FRACTION_ABS_ERROR_LE_1200    = 91.9732%
RAW_ERROR_MIN/MAX             = -1959 / 1774
ERROR_BAND_EXIT_EVENTS        = 42
LOW_RAIL_FRACTION             = 0%
HIGH_RAIL_FRACTION            = 0%
NO_RAIL_FRACTION               = 100%
DYNAMICS_CANDIDATE             = UNDERDAMPED_OR_OVERAGGRESSIVE_CANDIDATE
```

Lock 與 runtime gate：

```text
LOCK_COUNT_MAX                = 0
LOCK_COUNT_FINAL              = 0
HELPER_LOCKED_FINAL           = 0
HELPER_LOCK_COUNT_FINAL       = 0
MAIN_ENABLED_FINAL            = 0
MAIN_FREQ_LOCKED_FINAL        = 0
MAIN_PHASE_LOCKED_FINAL       = 0
MAIN_LOCKED_FINAL             = 0
PSTAT_LOCKED_FINAL            = 0
```

Event/health：

```text
SPLL_INIT_COUNT               = 1 -> 1
CLEAR_DACS_COUNT              = 1 -> 1
BOOTSTRAP_COMPLETED_FINAL     = 3360
BOOTSTRAP_DONE_FINAL          = 1
NORMAL_REQ_DELTA              = 19425
NORMAL_COMPLETED_DELTA        = 19425
DCO_STEP_DELTA                = 19541
FORCED_COMPLETED_DELTA        = 0
SPLL_DELOCK_COUNT              = 0 -> 0
BOOT/CPU/WR/SI reset deltas    = 0 / 0 / 0 / 0
RESET_STABLE                   = PASS
```

## 解讀

這輪證明新的 `lock_samples=1000` 已經被編入正式 firmware，且 PI transaction、輸出計算、position accounting、transaction accounting 與 reset stability 都正常。系統也沒有 low/high rail，表示目前不是單純 DCO 飽和或 SI5340 write transport 失敗。

但是 60 秒內 Helper lock counter 從未上升，並非只是在觀測結束時剛好尚未滿足 dwell。因此把 dwell 由 10000 降到 1000，在目前的誤差動態下仍不足以打開 Helper lock gate。由於 Helper gate 沒開，Main loop 與 PSTAT lock 不會啟動，Step5 不能宣告通過。

2 個 invalid snapshot frame 沒有被當成有效樣本；其餘 transport、coherence 與 accounting 檢查通過，故不影響本輪「未 lock」的主要判定。

## 下一輪建議

下一輪先不要再盲目掃 PI gain。應在不改變控制輸出的前提下，增加能區分下列兩種情況的 persistent observability：

1. `ld_update()` 實際收到的 accepted error 是否連續達到 1000 samples，但 snapshot 沒抓到 lock state。
2. accepted error 是否在每次 lock dwell 尚未完成前就被 42 次 band exit 打斷。

若確認是第二種情況，再以小幅度、可回退的控制改動降低 phase-error excursions；若確認是第一種情況，則先修正 lock-state 的取樣/暴露路徑，再重新做 Step5 判定。兩者未分辨前，不應宣告 Step5 或 merge 到 `main`。

## Raw evidence

本輪 Pain 原始 build、program、preflight、observer log 與 source/SOF checksum 已保存於同資料夾的 `raw/`，並以 artifact archive 保存於 `artifacts/`。
