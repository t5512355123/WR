# EXP-WRPC-STEP5-HPLL-ZERO-CROSSING-3360-KP-MINUS75-PHASE-GUARD-20260909

## 判定

本輪固定 3360-step HPLL coarse point、`ki=-1` 與 60 秒 Slave phase
guard，只把 WR node Helper phase-loop proportional gain 由 `kp=-150`
降為 `kp=-75`。編譯、燒錄、preflight 及約 398.8 秒 coherent trajectory
audit 均完成；accounting 通過，但 Helper 仍週期性離鎖，Step5 未完成，
不能 merge。

```text
SOURCE_COMMIT = b9d330ac58ace77070606f19278540424047c237
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
WR node Helper kp: -150 -> -75
WR node Helper ki: -1 (unchanged)
Slave STEP5_BOOTSTRAP_STEPS: 3360 (unchanged)
Slave Helper phase guard: 60 seconds (unchanged)
```

沒有修改 DCO page/mask sequence、FINC/FDEC mapping、HPLL step size、Main、
DMTD、PTP、PHY 或 reset policy。

## Build / program provenance

Pain 從上述 commit 的乾淨 worktree 完整編譯 Master/Slave，兩張板均成功
燒錄：

```text
MASTER_SOF_SHA256 = bf06a6cc73f3027eb669d32d9bf62fe3a7f2f3c44fba9cc4ebb864e321b22438
SLAVE_SOF_SHA256  = 6b66f83a1e64742b20787a13065e6b7701d2a99c457e2c051f302306083cd003
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

Slave `DE5 [1-11.2]` 完成 3600 samples，約 398.8 秒；本輪量測、position、
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

`kp=-75` 仍可維持頻率零點附近並持續產生雙向 normal DCO transactions：

```text
FREQ_ERROR_MEAN = 0.205277777778
FREQ_ERROR_RMS = 9.79774633951
FREQ_ERROR_MIN = -35
FREQ_ERROR_MAX = 37
HELPER_ERROR_MEAN = -11.4241666667
HELPER_ERROR_RMS = 1045.172371162
HELPER_ERROR_MAX_ABS = 4013
FRACTION_ABS_ERROR_LE_200 = 0.174166666667
NORMAL_REQ_DELTA_OBSERVED = 9718
NORMAL_COMPLETED_DELTA = 9719
FINC_DELTA = 4889
FDEC_DELTA = 4830
BOOTSTRAP_COMPLETED_FINAL = 3360
BOOTSTRAP_DONE_FINAL = 1
```

但較低的比例作用沒有抑制 phase hunting；Helper lock counter 仍反覆
重置，沒有建立有效 locked state：

```text
LOCK_COUNT_MAX = 6419
LOCK_COUNT_FINAL = 100
LOCK_COUNT_RISE_EVENTS = 787
LOCK_COUNT_FALL_EVENTS = 787
ERROR_BAND_EXIT_EVENTS = 381
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

因此不能用 `LOCK_COUNT_MAX` 或接近零的 frequency error 宣稱 Step5；
300 秒 full chain、Helper lock、Main lock 與 PSTAT lock 都未成立。

## 下一輪

`kp=-150` 與 `kp=-75` 都能到達頻率零點，但 phase error RMS 反而在
`kp=-75` 上升，顯示只降比例增益不是正確的穩定化方向。下一輪回到
`kp=-150,ki=-1`，只把 HPLL normal tracker 的每次 physical step 從
64 code 降至 32 code，減少每次 DCO transaction 對 phase loop 的離散
校正量，並保持 3360 bootstrap 與 60 秒 guard 不變。這會測試
「transaction granularity/actuator delay」而非再掃 PI gain。

## Raw evidence

本資料夾 `raw/` 保存 source commit、build、program、preflight 與 Slave
3600-sample observer。遠端 raw archive SHA-256：

```text
1a39434ddaa85eb70d6dce41437310beff4f31fe72b1a1924c5206cc727a901c
```
