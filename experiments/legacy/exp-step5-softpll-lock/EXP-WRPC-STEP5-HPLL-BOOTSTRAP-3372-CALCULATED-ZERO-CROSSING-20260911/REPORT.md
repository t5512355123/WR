# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-3372-CALCULATED-ZERO-CROSSING-20260911

## 結論

本輪 **Step5 = NOT COMPLETE**，不可判定為 PASS。

3372 版本成功把 HPLL bootstrap 工作點由前一輪的負頻率誤差推近零交越，並且完成 fresh build、實體重新燒錄與 3600 個 coherent observation samples。主迴路頻率已鎖定，Helper 最終也曾維持鎖定；但主迴路相位鎖定與 `PSTAT.locked` 仍為 0，Helper 仍呈現 underdamped/actuator hunting，尚未滿足完整 Step5 chain。

## 實驗目的

驗證以量測到的 HPLL plant slope 計算 operating-point correction：

- baseline：`STEP5_BOOTSTRAP_STEPS = 3360`
- plant ID：FINC 方向斜率約 `+0.216 FREQ_ERROR / physical step`
- 前一輪量測平均 `FREQ_ERROR ≈ -2.4`
- 本輪修正：3360 加 12 個 FINC steps，使用 `3372`

這是 bounded operating-point correction，不是 PI gain sweep。

## 執行紀錄

- branch：`exp/step5-softpll-lock`
- source commit：`dc93d34` (`exp: shift HPLL bootstrap to calculated zero crossing`)
- Master SOF SHA-256：`2fbee8ecdcfc37db912c294f0841d8f84026f5286ffbe22767c67ced13f6144f`
- Slave SOF SHA-256：`dd36bafcb0509f40c1aa4a4cda070507c63a6fe67d5dd723b12dfbf1d0ac2fc1`
- Quartus：Intel FPGA Standard 17.0
- board：`DE5 [1-11.2]`
- observer：3600 samples，100 ms cadence，約 360 秒
- raw archive SHA-256：`20f8c36590ff228d5fec1362acf1e28ac8feeab69630bb01ed3fc6e05b7489d8`

執行順序符合本實驗流程：

1. laptop 修改 VHDL/Tcl 並 push GitHub。
2. Pain pull commit `dc93d34`，重新 build Master/Slave，並實體重新燒錄。
3. Pain 執行 preflight 與 coherent closed-loop observer。
4. 原始 build、program、preflight、observer logs 歸檔於本資料夾。

## Build / programming

- Master build：PASS，`timing_closed=NO`
- Slave build：PASS，`timing_closed=NO`
- Master programming：PASS，1 device configured，0 errors，0 warnings
- Slave programming：PASS，1 device configured，0 errors，0 warnings

## Preflight

Preflight 顯示：

- Slave `STEP4B_RESULT = PASS`
- Helper lock detector：`1000/1000`，`locked=1`
- Main enabled：`1`
- Main frequency locked：`1`
- Main phase locked：`0`
- Main locked：`0`
- `PSTAT_locked=0`
- first inactive boundary：`MAIN_FREQUENCY_LOCK`

## Coherent observer 結果

```text
SAMPLES=3600
COHERENT_MEASUREMENT_SNAPSHOTS=3600
REJECTED_EPOCH_SNAPSHOTS=0
REJECTED_ACCOUNTING_CANDIDATES=79
MEASUREMENT_ACCOUNTING_FAILS=0
POSITION_SNAPSHOTS=3029
POSITION_INVARIANT_FAILS=0
TRANSACTION_INVARIANT_FAILS=0
DCO_TOTAL_LOWER_BOUND_FAILS=221

FREQ_ERROR_MEAN=0.0261111111111
FREQ_ERROR_RMS=8.11996852758
FREQ_ERROR_MIN=-31
FREQ_ERROR_MAX=31
HELPER_ERROR_MEAN=5.60638888889
HELPER_ERROR_RMS=1430.49310408
HELPER_ERROR_MAX_ABS=4902
FRACTION_ABS_ERROR_LE_200=0.125

LOW_RAIL_FRACTION=0.0
HIGH_RAIL_FRACTION=0.0
NO_RAIL_FRACTION=1.0

LOCK_COUNT_MAX=1000
LOCK_COUNT_FINAL=1000
HELPER_LOCKED_SEEN=2407
HELPER_LOCKED_FINAL=1
FIRST_HELPER_LOCK_SAMPLE=4
ERROR_BAND_EXIT_EVENTS=334
ACTUATOR_HUNT_OBSERVED=YES
HELPER_DYNAMICS=UNDERDAMPED_OR_OVERAGGRESSIVE

MAIN_ENABLED_FINAL=1
MAIN_FREQ_LOCKED_FINAL=1
MAIN_PHASE_LOCKED_FINAL=0
MAIN_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
FULL_CHAIN_300S=0
STEP5_CHAIN_RESULT=NOT_COMPLETE

SPLL_DELOCK_COUNT_MAX=94
RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_RESET_DELTA=0
RESET_SI_CONFIG_DELTA=0
MEASUREMENT_COHERENCE=PASS
POSITION_ACCOUNTING=FAIL
RESET_STABLE=PASS
```

## 判讀

### 已確認的改善

1. `FREQ_ERROR_MEAN` 從前一輪約 `-2.4` 改善到約 `+0.026`，證明 12-step operating-point correction 方向正確。
2. 3600 samples 內 Helper output 沒有碰到 low/high rail，說明本輪不是 actuator authority 不足或 gross bootstrap 偏移。
3. Helper 曾在第 4 個 sample 進入 lock detector 的 1000-sample lock window，最終觀測仍為 locked。
4. Main 已 enable 且 frequency lock 已成立。
5. `BOOT_GENERATION`、CPU reset、WR core reset、SI config drop 都為 0，實驗期間系統保持穩定。

### 尚未通過的部分

1. Main phase lock 與 `PSTAT.locked` 仍為 0，因此完整 chain 沒有成立。
2. Helper error RMS 約 1430，只有 12.5% samples 在 ±200 內，且有 334 次 error-band exit；observer 明確判定 actuator hunting、under-damped/over-aggressive。
3. `REJECTED_ACCOUNTING_CANDIDATES=79`、`DCO_TOTAL_LOWER_BOUND_FAILS=221`，所以 position accounting 目前不具備完整證據力。這些是觀測有效性/取樣對齊問題，不能直接當成硬體 actuator 失效。
4. `TARGET_FINAL`、`APPLIED_FINAL` 等 position probe final fields 為 INVALID，下一輪必須先檢查 observer 的 probe/transaction accounting，再用同一個可靠 measurement window 判定鎖定。

## 下一步

保留 `bootstrap_steps=3372`，不要再改 operating point。下一輪先針對目前已證實的 hunting 做最小幅度、可回退的 closed-loop damping 實驗；同時修正或隔離 observer 的 position-accounting invalid/rejection 原因。判定門檻維持嚴格：同一 fresh coherent window 必須同時看到 Helper lock、Main frequency lock、Main phase lock、`PSTAT.locked=1`，並通過連續穩定時間要求，才可標示 Step5 PASS。

## 原始資料

本資料夾 `raw/` 包含：

- Master/Slave build logs
- Master/Slave programming logs
- preflight log
- 3600-sample coherent observer log

