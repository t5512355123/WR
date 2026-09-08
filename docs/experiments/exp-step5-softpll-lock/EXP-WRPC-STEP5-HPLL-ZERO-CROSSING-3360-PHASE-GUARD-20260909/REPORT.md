# EXP-WRPC-STEP5-HPLL-ZERO-CROSSING-3360-PHASE-GUARD-20260909

## 判定

本輪以計算得到的 HPLL coarse zero-crossing 附近點 `3360` 進行 Slave
觀測，保留 60 秒 phase guard 與既有 DCO mapping。編譯、燒錄、preflight
及約 405 秒 coherent trajectory audit 均完成，但沒有形成可持續的
Helper/Main/PSTAT lock，因此 Step5 未完成，不能 merge。

```text
SOURCE_COMMIT = 0fa62a9be73a5b390daee50d4460c8ac9af2b150
STEP1_TO_STEP3 = PASS (valid preflight)
STEP4A = PASS (Master)
STEP4B = PASS (Slave)
STEP5_VALID_MEASUREMENT = PARTIAL
STEP5_RESULT = NOT_COMPLETE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## 變更

```text
Slave STEP5_BOOTSTRAP_STEPS: 3072 -> 3360
Slave STEP5_BOOTSTRAP_REVERSE: 1 (reverse/FINC, unchanged)
Slave Helper phase guard: 60 seconds (unchanged)
observer bootstrap_steps: 3072 -> 3360
```

3360 是依 1664 與 3072 兩輪的頻率誤差做同一 phase-guard 條件下的
插值所得，目的是直接測試接近頻率零點的 coarse operating point。沒有
修改 PI gain、DCO page/mask sequence、FINC/FDEC mapping、Main、DMTD、
PTP、PHY 或 reset policy。

## Build / program provenance

Pain 從上述 commit 的乾淨 worktree 完整編譯 Master/Slave，兩張板均成功
燒錄：

```text
MASTER_SOF_SHA256 = 62e1f638f9672f05e56640d3355a199f133b8fe7cd3917a4a5b8a2d4b44702b3
SLAVE_SOF_SHA256  = 650bbd73350f7cc863be24af746fff500e5b6bd67d165aa02560923c466d21ab
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

Slave `DE5 [1-11.2]` 完成 3600 samples，約 405.5 秒。量測與 reset 穩定性
如下：

```text
SAMPLES = 3600
POST_BOOTSTRAP_BASELINE_SET = 1
COHERENT_MEASUREMENT_SNAPSHOTS = 3600
REJECTED_EPOCH_SNAPSHOTS = 0
REJECTED_ACCOUNTING_CANDIDATES = 0
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_SNAPSHOTS = 3599
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 260
MEASUREMENT_COHERENCE = PASS
RESET_STABLE = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

## 結果與解讀

3360 成功把頻率誤差帶到零附近，證明 coarse operating point 的方向是
有效的，且已進入會產生 normal DCO transaction 的 fine loop：

```text
FREQ_ERROR_MEAN = -0.105
FREQ_ERROR_RMS = 10.8025459962
FREQ_ERROR_MIN = -37
FREQ_ERROR_MAX = 41
HELPER_ERROR_MEAN = -16.7530555556
HELPER_ERROR_RMS = 496.058620248
FRACTION_ABS_ERROR_LE_200 = 0.344166666667
NORMAL_REQ_DELTA_OBSERVED = 15607
NORMAL_COMPLETED_DELTA = 15607
FINC_DELTA = 7837
FDEC_DELTA = 7770
BOOTSTRAP_COMPLETED_FINAL = 3360
BOOTSTRAP_DONE_FINAL = 1
```

但 fine loop 是低阻尼/過度積極的 hunting 狀態，而不是 lock：

```text
LOCK_COUNT_MAX = 10000
LOCK_COUNT_FINAL = 1654
LOCK_COUNT_RISE_EVENTS = 1287
LOCK_COUNT_FALL_EVENTS = 1244
ERROR_BAND_EXIT_EVENTS = 484
ACTUATOR_HUNT_OBSERVED = YES
HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE
HELPER_LOCKED_SEEN = 7
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 1
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

`LOCK_COUNT_MAX=10000` 不是 sustained lock；它只表示計數器曾達到上限，
但後續反覆跌出 lock band，最後只剩 1654。`MAIN_ENABLED` 曾變成 1 也不
等於 Main lock，因為 Main frequency/phase lock、PSTAT 與完整 300 秒鏈
均未成立。

本輪的 `DCO_INVARIANT_FAILS=260` 使整體 position accounting 判定為
FAIL。雖然 transaction invariant 與 position invariant 各自為 0，且
normal request/completion 數量一致，仍不能忽略這個 observer/RTL 座標
契約問題；本輪因此只能視為「頻率零點與 fine-loop 可達性已證明」，不能
視為 Step5 證據閉合。

## 下一輪

3360 已足以說明目前主要瓶頸不是 coarse frequency point，而是 phase loop
動態：`kp=-300, ki=-1` 在零點附近造成明顯 hunting。下一輪只改比例增益
為 `kp=-150`，保留 `ki=-1`、3360 bootstrap、60 秒 phase guard 及所有
其他設定，觀察是否能降低 FINC/FDEC 來回切換並取得持續 Helper lock。

## Raw evidence

本資料夾 `raw/` 保存 source commit、build、program、preflight 與 Slave
3600-sample observer。遠端 raw archive SHA-256：

```text
18254c0950eea0108914e517eb9d35cd5aea04110b2f7599e2d6a862205e45b6
```
