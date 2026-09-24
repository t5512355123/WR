# EXP-WRPC-STEP5-HPLL-ZERO-CROSSING-3360-KI-ZERO-PHASE-GUARD-20260909

## 判定

本輪固定 3360-step HPLL coarse point、`kp=-150` 與 60 秒 Slave phase
guard，只把 WR node Helper 的積分增益由 `ki=-1` 改為 `ki=0`。編譯、
燒錄、preflight 及約 398.5 秒 coherent trajectory audit 均完成；移除
積分後控制器停在 bootstrap 後的錯誤位置，沒有 Step5 lock。

```text
SOURCE_COMMIT = 7cf1346b56db164b0c2d1bdf1c37aad4b3ba801f
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
WR node Helper kp: -150 (unchanged)
WR node Helper ki: -1 -> 0
Slave STEP5_BOOTSTRAP_STEPS: 3360 (unchanged)
Slave Helper phase guard: 60 seconds (unchanged)
```

`ki` 與 `kp` 是整數 fixed-point 權重；在目前介面中不能直接表示
`-0.25`，因此以 `ki=0` 作為移除積分作用的 A/B。沒有修改 DCO
page/mask sequence、FINC/FDEC mapping、HPLL step size、Main、DMTD、PTP、
PHY 或 reset policy。

## Build / program provenance

Pain 從上述 commit 的乾淨 worktree 完整編譯 Master/Slave，兩張板均成功
燒錄：

```text
MASTER_SOF_SHA256 = 8e31a25909928225a813c9c81f016457100de6ea4927eafe5a9e14ecd535ce8f
SLAVE_SOF_SHA256  = 08407a38ee598d9efc69479ba96d510f4bf4e4c5ee442788aa0305a230e05992
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

Slave `DE5 [1-11.2]` 完成 3600 samples，約 398.5 秒；量測、position 與
transaction accounting 及 reset stability 全部通過：

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

在 bootstrap 完成後，沒有積分作用使 Helper 無法消除剩餘的頻率誤差：

```text
FREQ_ERROR_MEAN = -248.368333333
FREQ_ERROR_RMS = 248.713431706
FREQ_ERROR_MIN = -295
FREQ_ERROR_MAX = -201
FREQ_ERROR_FIRST = -218
FREQ_ERROR_LAST = -265
HELPER_ERROR_MEAN = -150000.0
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
FINC_DELTA = 0
FDEC_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 3360
BOOTSTRAP_DONE_FINAL = 1
```

因此 lock detector 從未接近成立：

```text
LOCK_COUNT_MAX = 2
LOCK_COUNT_FINAL = 2
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
ACTUATOR_HUNT_OBSERVED = NO
HELPER_DYNAMICS = NO_LOCK_CLASSIFICATION
```

這輪結果與 `kp=-150, ki=-1` 的成功 fine-loop 可達性對照後，說明積分
項在目前系統中是必要的；`ki=0` 不是較穩定的 lock，而是失去補足頻率
偏差的能力。不能因 accounting 全部 PASS 就宣稱 Step5 pass。

## 下一輪

回到已證明可進入 fine loop 的 `ki=-1`，固定 3360 coarse point，只把
`kp=-150` 降至 `kp=-75`，測試是否能保留積分消除頻率偏差的能力，同時
降低 phase-loop hunting。若仍無法鎖定，下一步應從 PI trace/lock detector
與 DCO transaction latency 著手，而不是再宣稱 coarse point 已足夠。

## Raw evidence

本資料夾 `raw/` 保存 source commit、build、program、preflight 與 Slave
3600-sample observer。遠端 raw archive SHA-256：

```text
77413dbb6e766b9db35e162601bebe1e75ae0fd2953cb2b9a380c4870238a73c
```
