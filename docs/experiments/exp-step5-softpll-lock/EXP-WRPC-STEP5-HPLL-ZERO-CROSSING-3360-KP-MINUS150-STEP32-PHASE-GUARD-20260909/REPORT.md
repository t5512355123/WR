# EXP-WRPC-STEP5-HPLL-ZERO-CROSSING-3360-KP-MINUS150-STEP32-PHASE-GUARD-20260909

## 判定

本輪回到已可進入 fine loop 的 `kp=-150,ki=-1`，只把 Slave HPLL normal
tracker 的 physical transaction step 由 64 code 改為 32 code。編譯、燒錄、
preflight 與完整 observer 均完成，但較小的 transaction step 造成嚴重
actuator runaway，Step5 未完成，不能 merge。

```text
SOURCE_COMMIT = 5d92a74d925acf31c0e51d8c309c0d5dd28470db
STEP1_TO_STEP3 = PASS (valid preflight)
STEP4A = PASS (Master)
STEP4B = PASS (Slave)
STEP5_VALID_MEASUREMENT = PARTIAL
STEP5_RESULT = NOT_COMPLETE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## 唯一功能變更

```text
WR node Helper kp: -150 (unchanged)
WR node Helper ki: -1 (unchanged)
Slave HPLL_TRACKER_CODE_PER_PHYSICAL_STEP: 64 -> 32
observer code_per_physical_step: 64 -> 32
Slave STEP5_BOOTSTRAP_STEPS: 3360 (unchanged)
Slave Helper phase guard: 60 seconds (unchanged)
```

沒有修改 DCO page/mask sequence、FINC/FDEC mapping、Main、DMTD、PTP、PHY
或 reset policy。

## Build / program provenance

Pain 從上述 commit 的乾淨 worktree 完整編譯 Master/Slave，兩張板均成功
燒錄：

```text
MASTER_SOF_SHA256 = 855b7be7b88e486f1c2f3d2a8ecf443248a71c702d3fab0aa0202acb7ee2ca52
SLAVE_SOF_SHA256  = 9a370fb696a8d9ee739bad08143fa5e2443dd6d8ce2f331758045af11d8b0f8e
MASTER_COMPILE = Full Compilation was successful
SLAVE_COMPILE = Full Compilation was successful
MASTER_PROGRAM = configuration succeeded, 0 errors, 0 warnings
SLAVE_PROGRAM = configuration succeeded, 0 errors, 0 warnings
MASTER_WORST_SETUP_SLACK_NS = -0.178
SLAVE_WORST_SETUP_SLACK_NS = -0.081
TIMING_CLOSED = NO
```

有效 preflight 確認：

```text
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
STEP4A_RESULT = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

## Coherent closed-loop observation

Slave `DE5 [1-11.2]` 完成 3600 samples，約 582.1 秒。早期即出現
transaction runaway 與 lock 失敗，完整窗口結果如下：

```text
SAMPLES = 3600
COHERENT_MEASUREMENT_SNAPSHOTS = 3597
REJECTED_EPOCH_SNAPSHOTS = 3
REJECTED_ACCOUNTING_CANDIDATES = 348
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_SNAPSHOTS = 2552
POSITION_INVARIANT_FAILS = 45
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = FAIL
RESET_STABLE = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

約 36 秒時已看到 `HELPER_OUTPUT=5`、`PRECLAMP_ERROR` 約 `+673049`、
`SPLL_DELOCK_COUNT=210`，normal transaction 數量快速增加。約 146 秒時
`DCO_STEP` 已接近 64000，Helper output 多次到 rail；這不是較細緻的
穩定控制，而是離散 actuator 與目前 phase loop 互相放大的 runaway。

最終統計：

```text
FREQ_ERROR_MEAN = 10.5151515152
FREQ_ERROR_RMS = 419.019249224
FREQ_ERROR_MIN = -304
FREQ_ERROR_MAX = 16384
HELPER_ERROR_MEAN = 3538.73922713
HELPER_ERROR_RMS = 1439.90126815
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 0.39644147901
HIGH_RAIL_FRACTION = 0.371142618849
NO_RAIL_FRACTION = 0.232415902141
NORMAL_REQ_DELTA_OBSERVED = 13961
NORMAL_COMPLETED_DELTA = 13961
FINC_DELTA = 39809
FDEC_DELTA = 39688
BOOTSTRAP_COMPLETED_FINAL = 3360
BOOTSTRAP_DONE_FINAL = 1
LOCK_COUNT_MAX = 100
LOCK_COUNT_FINAL = 100
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
SPLL_DELOCK_COUNT_MAX = 248
SPLL_DELOCK_COUNT_FINAL = 0
```

這輪證明 32-code step 不能直接套用目前的 tracker admission/phase-loop
動態；它不提供有效 Step5 證據，也不應再沿相同設定重跑。

## 下一輪

回到最後一個 accounting 與 reset 都通過、且可維持頻率零點附近的基線：
`kp=-150,ki=-1,HPLL step=64,bootstrap=3360`。下一輪不再改 gain 或
transaction step，而是針對目前 `ld_update()` 的 lock detector 取樣時序
與 Helper phase measurement 做 read-only trace/source audit，確認為何
phase error 短暫進入 ±200 卻在 Helper update cadence 下反覆離開，再決定
最小的 functional 修正。

## Raw evidence

本資料夾 `raw/` 保存 source commit、build、program、preflight 與 Slave
3600-sample observer。遠端 raw archive SHA-256：

```text
0f64b8c9a766259050eda01f35c81090adc55ef1b7b6311bf0e0fc72b841fd3e
```
