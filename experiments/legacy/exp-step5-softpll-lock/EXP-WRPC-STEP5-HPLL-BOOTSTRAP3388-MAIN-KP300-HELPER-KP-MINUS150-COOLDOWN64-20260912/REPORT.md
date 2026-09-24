# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-MAIN-KP300-HELPER-KP-MINUS150-COOLDOWN64-20260912

## 結論

本輪是有效的 Step5 closed-loop 觀測，但 **不是 Step5 PASS**。

只在 Slave 加入 `STEP5_NORMAL_HPLL_COOLDOWN_LOADS=64` 後，Helper 的 hunting 旗標雖然消失，控制器卻長時間落在負向 phase-error 偏置並大量接近 high rail；Helper 沒有取得 lock，Main/PSTAT 也沒有啟動。因此 cooldown64 淘汰。

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

上一輪 Main Kp=+300、Helper Kp=-150、cooldown=0 已能在部分窗口同時看到 Helper/Main/PSTAT lock，但 Helper hunting 明顯，完整 chain 最長約 12.7 秒，尚未達 300 秒。

本輪固定：

```text
Main Kp = +300, Ki = +1
Helper Kp = -150, Ki = -1
bootstrap = 3388, reverse = 1
code_per_physical_step = 64
```

唯一 functional 變更為 Slave top-level generic：

```text
STEP5_NORMAL_HPLL_COOLDOWN_LOADS: 0 -> 64
```

其語意是每次 normal HPLL transaction 完成後，必須再收到 64 次 accepted Helper target load，才允許下一個 transaction。未修改 lock threshold、PI gain、bootstrap、DCO account 或 Step5 判定語意。

Source/observer commit：

```text
84b25fd4998bcb63230e64a4c7b1d126486d5e62
```

## Build / program

Pain 已由 GitHub 拉取上述 commit；Master/Slave Quartus build 均成功。

```text
Master SOF SHA256 = c50173b3954c23a6d5848b3e8d89b2ac3d2153b09f2b5b8b073ea1867256e70e
Slave  SOF SHA256 = 1622905e6d66ed42648733d96aa39f5851cd311fee636c1037510cd391908d7f
TIMING_CLOSED = NO
```

Master 與 Slave 均由 Quartus Programmer 回報 configuration succeeded、0 errors；順序為 Master，等待 45 秒，再 Slave。

## Settled preflight

燒錄後等待 120 秒的 settled preflight 已直接建立有效 upstream：

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

Preflight 的瞬時 lock detector 在觀測起點為 Helper count `16/1000`，120 秒後為 `100/1000`；這只是起始狀態，正式判定以下面的完整 coherent window 為準。

## 3600-snapshot coherent observer

```text
SAMPLES = 3600
COHERENT_MEASUREMENT_SNAPSHOTS = 3600
REJECTED_EPOCH_SNAPSHOTS = 0
REJECTED_ACCOUNTING_CANDIDATES = 5
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_SNAPSHOTS = 3600
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_TOTAL_LOWER_BOUND_FAILS = 0

FREQ_ERROR_MEAN = 0.335
FREQ_ERROR_RMS = 17.0346216082
FREQ_ERROR_MIN = -58
FREQ_ERROR_MAX = 54

HELPER_ERROR_MEAN = -58175.9030556
HELPER_ERROR_RMS = 86474.77727944
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.00111111111111
LOW_RAIL_FRACTION = 0.0216666666667
HIGH_RAIL_FRACTION = 0.6275
NO_RAIL_FRACTION = 0.350833333333

LOCK_COUNT_MAX = 536
LOCK_COUNT_FINAL = 100
LOCK_COUNT_RISE_EVENTS = 155
LOCK_COUNT_FALL_EVENTS = 160
ERROR_BAND_EXIT_EVENTS = 4
ACTUATOR_HUNT_OBSERVED = NO
HELPER_DYNAMICS = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0

MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0

FULL_CHAIN_MAX_SECONDS = 0.000
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
SPLL_DELOCK_COUNT_MAX = 51

RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = FAIL
RESET_STABLE = PASS
```

## Interpretation

cooldown64 的效果不是「穩定鎖定」，而是把 actuator update rate 壓到不足以追上當前 phase operating point：

```text
沒有 cooldown（前一輪有效窗口）:
  Helper RMS 約 19589，hunting，曾達到 Main/PSTAT final lock，full chain 約 12.7 s

cooldown64（本輪）:
  Helper RMS 約 86475，high rail 62.75%，無 Helper lock，Main 未啟用
```

因此 `64 loads` 已超過目前 operating point 可接受的 settling interval。雖然 hunting=NO，但這是飽和/偏置狀態，不是閉迴路收斂。

## 原始紀錄

```text
raw-observer.tar.gz
SHA256 = 05becbb5bbd9139defe80a6a8a31dae3d2e8e63a54c0edcc90e1b9457fa0c8f1
```

封存內容包含 build、program、燒錄後 preflight、settled preflight 及完整 3600-snapshot observer log。

## 下一步

回到第 1 步時，保留已知較佳的 `Helper Kp=-150` 與 `Main Kp=+300`，只把 cooldown 改為更短的 `16 loads`；不與 Kp、Ki、bootstrap 或 physical-step account 同輪變更。預期以 16 loads 判斷是否能在不造成 64-load bias 的前提下減少 cooldown0 的 hunting。

正式 Step5 PASS 仍必須同時滿足：Main/Helper/PSTAT lock、連續 300 秒 full chain、position accounting PASS、measurement coherence/accounting PASS，以及所有 reset delta 為零。任何只看到短暫 lock 或沒有 hunting 的 rail-limit 窗口都不能 merge。
