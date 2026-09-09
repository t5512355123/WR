# EXP-WRPC-STEP5-HELPER-PI-STARTUP-OPERATING-POINT-AUDIT-3360-KP-MINUS150-THRESHOLD1200-COOLDOWN32-20260909

## 判定

本輪不是 Step5 pass：`STEP5_CHAIN_RESULT = NOT_COMPLETE`。

```text
Step 1 PHY / Link              PASS
Step 2 Endpoint / PTP          PASS
Step 3 WR Handshake             PASS
Step 4B Slave SoftPLL Startup   PASS
Step 5 Closed-loop Lock         NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY   HELPER_LOCK
```

Step1/2/3/4B 與 JTAG/WB transport 都已通過，但 Helper 沒有進入 lock；因此 Main、PSTAT 與完整 300 秒鏈條沒有啟動，不能宣稱 Step5 pass。

## 實驗目的

依 `Astra建議.md`，先不繼續盲掃 PI gain，而是觀察 Helper 啟動點、PI integrator、target/applied 與 rail 行為，確認失敗是 startup operating point、控制方向、或 actuator range/控制器動態造成。

本輪同時修正 observer 的參數契約，使觀測器使用目前 firmware 的：

```text
kp=-150
ki=-1
PI update decimation=1
lock threshold=1200
PI y_min=5
PI y_max=65531
HPLL bootstrap=3360 steps, reverse=1
```

## 重要 provenance 更正

Observer 原先以 `normal_hpll_cooldown_loads=0` 標示，但 source audit 顯示本次實際 Slave top-level generic 是：

```text
STEP5_NORMAL_HPLL_COOLDOWN_LOADS => 32
```

因此本報告明確標示為 `COOLDOWN32`；不能把本輪當成 no-cooldown 證據。下一輪會先做真正 `cooldown=0` 的隔離 A/B。

## Build / program provenance

Pain 從 GitHub pull 後，在乾淨 detached worktree 編譯並燒錄：

```text
SOURCE_COMMIT = 6f661954408f8ecc007aa844b26e4f479158b2d8
QUARTUS       = Intel Quartus Prime Standard 17.0.0 Build 595
BUILD         = Master/Slave full compilation successful; 0 errors
```

SOF SHA-256：

```text
master = 8ff1bb72c071e0a0906ff72e9a5751cf16c4a90ef13d135e8e21a309ea00c874
slave  = 7ca051591e992e431934d2f89351c128bf85214dbd47178f07aa013ad6efc766
```

兩張板的 JTAG configuration 都回報成功。第一次 post-program preflight 即取得：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED   = YES
STEP4B_RESULT    = PASS
```

## PI startup / dynamics audit

600 個 sample、observer tag window 59.9 秒；全部 snapshot coherent，沒有 PI transport 或數學驗證失敗：

```text
VALID_FRAMES                  = 600
PI_TRACE_PRESENT              = 600
PI_SNAPSHOT_REJECTS           = 0
PI_ACCOUNTING_FAILS           = 0
PI_OUTPUT_MISMATCH_FAILS      = 0
ANTI_WINDUP_VIOLATIONS        = 0
MEASUREMENT_COHERENCE         = PASS
POSITION_ACCOUNTING           = PASS
FROZEN_BANK_READ_STABILITY    = PASS
```

控制結果：

```text
HELPER_ERROR_MEAN             = -22699.2916667
HELPER_ERROR_RMS              = 41702.647277
HELPER_ERROR_MAX_ABS          = 150000
FRACTION_ABS_ERROR_LE_1200    = 3.0 %
FREQ_ERROR_MEAN               = -0.0583333333
FREQ_ERROR_RMS                = 15.7180893665
FREQ_ZERO_CROSSINGS           = 175
HIGH_RAIL_FRACTION            = 49.500 %
LOW_RAIL_FRACTION             = 0.000 %
NO_RAIL_FRACTION               = 50.500 %
ERROR_BAND_EXIT_EVENTS        = 17
RAIL_TO_RAIL_CYCLE_COMPLETE   = 0
DYNAMICS_CANDIDATE            = UNDERDAMPED_OR_OVERAGGRESSIVE_CANDIDATE
```

最早的有效 sample 已經顯示 bootstrap 完成後 PI 正在工作：

```text
sample=1  HELPER_ERROR=-9642    PI_OUTPUT=34695  TARGET=33849  APPLIED=56389
sample=2  HELPER_ERROR=-135141  PI_OUTPUT=65531 TARGET=65531 APPLIED=56581
sample=5  HELPER_ERROR=24392    PI_OUTPUT=59239  TARGET=59982 APPLIED=63365
sample=6  HELPER_ERROR=1866     PI_OUTPUT=32830  TARGET=32842 APPLIED=56709
```

但之後 PI output 反覆在 high rail 與中間區間間切換；在觀測結尾仍為：

```text
HELPER_ERROR_FINAL             = -24186
HELPER_OUTPUT_FINAL            = 65531
TARGET_FINAL                   = 65531
APPLIED_FINAL                  = 5
HELPER_LOCKED_FINAL            = 0
HELPER_LOCK_COUNT_FINAL        = 0
MAIN_ENABLED_FINAL             = 0
PSTAT_LOCKED_FINAL             = 0
```

這不是「量不到」：PI trace、frozen-bank double-read、position accounting 與 JTAG transport 都通過；是控制器沒有形成可持續的 lock region。頻率誤差很小也不能取代 phase lock 證據。

## Reset / upstream stability

```text
SPLL_INIT_COUNT_FIRST/FINAL    = 1 / 1
SPLL_DELOCK_COUNT_FIRST/FINAL  = 0 / 0
RESET_BOOT_GENERATION_DELTA    = 0
RESET_CPU_DELTA                = 0
RESET_WR_CORE_DELTA            = 0
RESET_SI_CONFIG_DELTA          = 0
RESET_STABLE                   = PASS
```

因此本輪沒有新的 reset 或 reinitialization 破壞控制迴路。

## 結論與下一步

本輪排除了 observer transport、PI snapshot math、upstream Step4B 與 reset regression。觀察到的是 `kp=-150`、每 tag 更新、threshold=1200 在實際 `cooldown=32` image 上的高增益/啟動點敏感動態；不能只用放寬 threshold 解決。

下一輪先做唯一隔離變更：把 Slave top-level 的 `STEP5_NORMAL_HPLL_COOLDOWN_LOADS` 從實際 32 改成 0，其他 firmware、PI、bootstrap、observer 參數全部保持不變。這是為了取得真正 no-cooldown 的可重現基準，並避免把錯誤 provenance 當成控制結論。若仍未 lock，再依本輪 PI startup trace 修改 Helper 初始 operating point 或將 phase guard/reseed 與實際 bootstrap completion 對齊。

## 原始證據

本資料夾 `raw/` 保存：

```text
raw/preflight.log
raw/observer-pi-600.log
raw/source-commit.txt
raw/sof-sha256.txt
raw/raw-transfer.tgz
```

Pain 端 archive SHA-256：

```text
14d2f886b3b40a131f2a006b046d45fbfba15e4920af68cd9399f278c890fe99
```
