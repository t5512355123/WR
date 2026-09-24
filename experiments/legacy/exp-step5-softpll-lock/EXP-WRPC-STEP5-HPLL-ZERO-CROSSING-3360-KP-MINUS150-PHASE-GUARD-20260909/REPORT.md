# EXP-WRPC-STEP5-HPLL-ZERO-CROSSING-3360-KP-MINUS150-PHASE-GUARD-20260909

## 判定

本輪固定 3360-step HPLL coarse operating point 與 60 秒 Slave phase
guard，只把 WR node Helper phase-loop proportional gain 由 `kp=-300`
改為 `kp=-150`。編譯、燒錄、preflight 及約 396 秒 coherent trajectory
audit 均完成；頻率與 observer accounting 改善，但 Helper 沒有形成
sustained lock，Step5 未完成，不能 merge。

```text
SOURCE_COMMIT = ee168fd05aaef01dcb0f47f6436881ba9011f457
STEP1_TO_STEP3 = PASS (valid preflight)
STEP4A = PASS (Master)
STEP4B = PASS (Slave)
STEP5_VALID_MEASUREMENT = YES
STEP5_RESULT = NOT_COMPLETE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## 唯一功能變更

```text
WR node Helper kp: -300 -> -150
WR node Helper ki: -1 (unchanged)
Slave STEP5_BOOTSTRAP_STEPS: 3360 (unchanged)
Slave Helper phase guard: 60 seconds (unchanged)
```

沒有修改 DCO page/mask sequence、FINC/FDEC mapping、HPLL step size、Main、
DMTD、PTP、PHY 或 reset policy。observer 的實驗標籤與 gain 註記同步更新。

## Build / program provenance

Pain 從上述 commit 的乾淨 worktree 完整編譯 Master/Slave，兩張板均成功
燒錄：

```text
MASTER_SOF_SHA256 = 87da6b60c4735adb7d4bc0fb726fc2a45d26527716382ecd79787efd2badf6d7
SLAVE_SOF_SHA256  = f0e77aef56975f1dcbf8c93947b3648fbc9baef231671eb59ddd579e071dbdb3
MASTER_COMPILE = Full Compilation was successful
SLAVE_COMPILE = Full Compilation was successful
MASTER_PROGRAM = configuration succeeded, 0 errors, 0 warnings
SLAVE_PROGRAM = configuration succeeded, 0 errors, 0 warnings
MASTER_WORST_SETUP_SLACK_NS = -0.178
SLAVE_WORST_SETUP_SLACK_NS = -0.084
TIMING_CLOSED = NO
```

有效 preflight 確認：

```text
Master Step1/Step2/Step4A = PASS
Slave Step1/Step2/Step3/Step4B = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

## Coherent closed-loop observation

Slave `DE5 [1-11.2]` 完成 3600 samples，約 396.2 秒；本輪量測、位置及
transaction accounting 與 reset stability 全部通過：

```text
SAMPLES = 3600
POST_BOOTSTRAP_BASELINE_SET = 1
COHERENT_MEASUREMENT_SNAPSHOTS = 3600
REJECTED_EPOCH_SNAPSHOTS = 0
REJECTED_ACCOUNTING_CANDIDATES = 0
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_SNAPSHOTS = 3600
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

## 結果與解讀

降低 `kp` 後，頻率誤差仍維持在零附近，且相比前一輪 3360/`kp=-300`
的 `FREQ_ERROR_RMS=10.8025` 略有改善：

```text
FREQ_ERROR_MEAN = 0.0316666666667
FREQ_ERROR_RMS = 9.24226403239
FREQ_ERROR_MIN = -29
FREQ_ERROR_MAX = 32
HELPER_ERROR_MEAN = -10.8675
HELPER_ERROR_RMS = 663.645975946
HELPER_ERROR_MAX_ABS = 2310
FRACTION_ABS_ERROR_LE_200 = 0.229722222222
NORMAL_REQ_DELTA_OBSERVED = 9643
NORMAL_COMPLETED_DELTA = 9643
FINC_DELTA = 4843
FDEC_DELTA = 4800
BOOTSTRAP_COMPLETED_FINAL = 3360
BOOTSTRAP_DONE_FINAL = 1
```

但 phase loop 仍反覆離開 lock band，未曾建立 Helper locked 狀態：

```text
LOCK_COUNT_MAX = 6460
LOCK_COUNT_FINAL = 100
LOCK_COUNT_RISE_EVENTS = 985
LOCK_COUNT_FALL_EVENTS = 994
ERROR_BAND_EXIT_EVENTS = 455
ACTUATOR_HUNT_OBSERVED = YES
HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

`LOCK_COUNT_MAX=6460` 不是 sustained lock；計數器在窗口內反覆上升又跌回
低值，最後為 100。由於 Helper 沒 lock，Main 沒有被啟動，PSTAT 也沒有
鎖定。這輪因此證明 `kp=-150` 可降低部分振盪量且修復了 observer accounting
證據，但不能宣稱達成 Step5。

## 下一輪

`kp=-150` 仍呈現週期性 hunting，且 `ki=-1` 的累積作用可能持續把 phase
loop 推離 lock band。下一輪固定 3360、固定 `kp=-150`，只把 `ki` 降低
至 `-0.25`（若整數 PI 介面不允許 fractional gain，改用 `ki=0` 作為
最小積分作用 A/B），測試能否保留頻率零點附近的比例校正並消除長時間
積分造成的來回漂移。

## Raw evidence

本資料夾 `raw/` 保存 source commit、build、program、preflight 與 Slave
3600-sample observer。遠端 raw archive SHA-256：

```text
75c2de513d8fa596a7a1cca30562e40d521129caacc90619247cf63647b7b514
```
