# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-MAIN-KP300-HELPER-KP-MINUS150-COOLDOWN16-20260912

## 結論

本輪是有效的 Step5 closed-loop 觀測，但 **不是 Step5 PASS**。

相較 cooldown=64，16 loads 大幅減少了 rail-limit；相較 cooldown=0，Helper phase-error RMS 也下降，但仍然有 actuator hunting，Helper 在窗口末端掉出 lock，Main phase/PSTAT 沒有成立，且沒有任何連續 full-chain。因此 cooldown16 仍淘汰。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4A_RESULT = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = FAIL
RESET_STABLE = PASS
STEP5_CHAIN_RESULT = NOT_COMPLETE
MERGE_APPROVED = NO
```

## 實驗目的與唯一變更

本輪固定 Main/Helper PI、bootstrap、physical-step account，只把上一輪的 normal HPLL settling cooldown 從 64 loads 降為 16 loads：

```text
Main Kp = +300, Ki = +1
Helper Kp = -150, Ki = -1
bootstrap = 3388, reverse = 1
code_per_physical_step = 64
STEP5_NORMAL_HPLL_COOLDOWN_LOADS = 16
```

Source/observer commit：

```text
988e77744ba743392c49f3a7e8d6b8e5861de5c2
```

唯一 functional 變更是 Slave top-level generic `STEP5_NORMAL_HPLL_COOLDOWN_LOADS: 64 -> 16`。未修改 lock threshold、PI gain、bootstrap、DCO account 或 Step5 判定語意。

## Build / program

Pain 已由 GitHub 拉取上述 commit；Master/Slave Quartus build 與 JTAG programming 均成功。

```text
Master SOF SHA256 = 861de81fc4e19f8c810038163ce817b4e9aaec1f96885a9efa892f9e840238e0
Slave  SOF SHA256 = f417c0100d4172c094c11d00ef206b16218f32ac2622d018b9183d34ea2a98d4
TIMING_CLOSED = NO
```

燒錄順序為 Master，等待 45 秒，再 Slave；兩張板均回報 configuration succeeded、0 errors。

## Settled preflight

燒錄後等待 120 秒，兩板上游 gate 皆成立：

```text
Master core_tm_link_up = 1
Master core_link_ok    = 1
Master WDIAGS_PTP      = MASTER
Slave  core_tm_link_up = 1
Slave  core_link_ok    = 1
Slave  WDIAGS_PTP      = SLAVE
STEP1_REGRESSION       = PASS
STEP2_REGRESSION       = PASS
STEP3_REGRESSION       = PASS
STEP4A_RESULT          = PASS
STEP4B_ALLOWED         = YES
STEP4B_RESULT          = PASS
SPLL_MODE              = SPLL_MODE_SLAVE
SPLL_SEQ_STATE         = SEQ_WAIT_HELPER
```

## 3600-snapshot coherent observer

```text
SAMPLES = 3600
COHERENT_MEASUREMENT_SNAPSHOTS = 3600
REJECTED_EPOCH_SNAPSHOTS = 0
REJECTED_ACCOUNTING_CANDIDATES = 148
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_SNAPSHOTS = 3530
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_TOTAL_LOWER_BOUND_FAILS = 0

FREQ_ERROR_MEAN = 4.41277777778
FREQ_ERROR_RMS = 273.183547373
FREQ_ERROR_MIN = -37
FREQ_ERROR_MAX = 16384

HELPER_ERROR_MEAN = -248.036666667
HELPER_ERROR_RMS = 5187.73619114
HELPER_ERROR_MAX_ABS = 26318
FRACTION_ABS_ERROR_LE_200 = 0.0325
LOW_RAIL_FRACTION = 0.0
HIGH_RAIL_FRACTION = 0.0188888888889
NO_RAIL_FRACTION = 0.981111111111

LOCK_COUNT_MAX = 1000
LOCK_COUNT_FINAL = 100
LOCK_COUNT_RISE_EVENTS = 1102
LOCK_COUNT_FALL_EVENTS = 876
ERROR_BAND_EXIT_EVENTS = 113
ACTUATOR_HUNT_OBSERVED = YES
HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE
HELPER_LOCKED_SEEN = 115
HELPER_LOCKED_FINAL = 0
FIRST_HELPER_LOCK_SAMPLE = 385

MAIN_ENABLED_FINAL = 1
MAIN_FREQ_LOCKED_FINAL = 1
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0

FULL_CHAIN_MAX_SECONDS = 0.000
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
SPLL_DELOCK_COUNT_MAX = 242

RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = FAIL
RESET_STABLE = PASS
```

## Interpretation

cooldown16 位於 cooldown0 與 cooldown64 之間，但仍沒有形成可接受的閉迴路：

```text
cooldown0:
  Helper RMS 約 19589，hunting，曾達 Main/PSTAT final lock，full-chain 約 12.7 s

cooldown16:
  Helper RMS 約 5188，high rail 1.89%，但仍 hunting，Helper final=0，Main phase/PSTAT final=0

cooldown64:
  Helper RMS 約 86475，high rail 62.75%，無 Helper lock，Main 未啟用
```

因此 cooldown 確實是有效的動態旋鈕，但 16 loads 尚未提供足夠 damping；同時本輪 `FREQ_ERROR_MAX=16384` 與 position accounting fail 顯示觀測窗口仍有量測/交易邊界問題，不能把短暫的 Main frequency lock 視為 Step5。

## 原始紀錄

```text
raw-observer.tar.gz
SHA256 = a6b0da6be01412c6056caadb7a47abcadf8b194813813ff6efaf0369edaea5f9
```

封存內容包含 build、program、燒錄後 preflight、settled preflight 及完整 3600-snapshot observer log。

## 下一步

回到第 1 步時，固定 `Main Kp=+300`、`Helper Kp=-150`、`Ki=-1`、bootstrap=3388、physical-step=64，只把 cooldown 改為更短的 `8 loads`。若 cooldown8 仍出現 hunting，下一個方向不再繼續任意縮放 cooldown，而應改用同一窗口的 Helper PI trace 做 integrator/anti-windup 來源定位；不得同輪同時改 Ki 與 cooldown。

正式 Step5 PASS 仍必須同時滿足 Main/Helper/PSTAT lock、連續 300 秒 full chain、position accounting PASS、measurement coherence/accounting PASS，以及所有 reset delta 為零。任何只看到短暫 lock、低 rail 比例或沒有 hunting 的 rail-limit 窗口都不能 merge。
