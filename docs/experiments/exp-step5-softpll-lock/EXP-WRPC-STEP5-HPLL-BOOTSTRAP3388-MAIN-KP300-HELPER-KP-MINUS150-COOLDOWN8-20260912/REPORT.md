# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-MAIN-KP300-HELPER-KP-MINUS150-COOLDOWN8-20260912

## 結論

本輪是有效的 Step5 closed-loop 觀測，但 **不是 Step5 PASS**。

cooldown8 讓 Helper 在 settled preflight 短暫達到 `1000/1000`，但完整窗口仍有 hunting；Helper 最終掉出 lock，Main frequency 雖維持 lock，Main phase/PSTAT 沒有成立，full-chain 只維持 0.274 秒。cooldown8 淘汰，並停止繼續縮小 cooldown 的掃描。

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

本輪固定：

```text
Main Kp = +300, Ki = +1
Helper Kp = -150, Ki = -1
bootstrap = 3388, reverse = 1
code_per_physical_step = 64
```

唯一 functional 變更為 Slave top-level generic：

```text
STEP5_NORMAL_HPLL_COOLDOWN_LOADS: 16 -> 8
```

未修改 PI gain、bootstrap、DCO accounting、lock threshold、Main 或 Step5 判定語意。

Source/observer commit：

```text
94f135dd5d82d6735306bf70ed944310bbe7fe43
```

## Build / program

Pain 已由 GitHub 拉取上述 commit；Master/Slave Quartus build 與 JTAG programming 均成功。

```text
Master SOF SHA256 = 3e96b9730d80fdb9fa5942c34db09bcce74dd9095688dff39563ffdba13e8f31
Slave  SOF SHA256 = 75537abddb6a6adf85ff016486caef48fd57810067fd9b8f66fd0626ffbef4e8
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
SPLL_SEQ_STATE         = SEQ_WAIT_MAIN
```

settled preflight 當下的 detector 為：

```text
HELPER locked = 1
HELPER lock count = 1000/1000
MAIN enabled = 1
MAIN frequency = 1
MAIN phase = 0
PSTAT = 0
```

這是有效觀測的起點，不是長時間 Step5 結果。

## 3600-snapshot coherent observer

```text
SAMPLES = 3600
COHERENT_MEASUREMENT_SNAPSHOTS = 3600
REJECTED_EPOCH_SNAPSHOTS = 0
REJECTED_ACCOUNTING_CANDIDATES = 2
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_SNAPSHOTS = 3498
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_TOTAL_LOWER_BOUND_FAILS = 0

FREQ_ERROR_MEAN = 0.8725
FREQ_ERROR_RMS = 9.94720787178
FREQ_ERROR_MIN = -94
FREQ_ERROR_MAX = 37

HELPER_ERROR_MEAN = -2843.52083333
HELPER_ERROR_RMS = 20927.84467435
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0305555555556
LOW_RAIL_FRACTION = 0.000277777778
HIGH_RAIL_FRACTION = 0.0255555555556
NO_RAIL_FRACTION = 0.974166666667

LOCK_COUNT_MAX = 1000
LOCK_COUNT_FINAL = 0
LOCK_COUNT_RISE_EVENTS = 995
LOCK_COUNT_FALL_EVENTS = 736
ERROR_BAND_EXIT_EVENTS = 109
ACTUATOR_HUNT_OBSERVED = YES
HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE
HELPER_LOCKED_SEEN = 117
HELPER_LOCKED_FINAL = 0
FIRST_HELPER_LOCK_SAMPLE = 46

MAIN_ENABLED_FINAL = 1
MAIN_FREQ_LOCKED_FINAL = 1
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0

FULL_CHAIN_MAX_SECONDS = 0.274
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
SPLL_DELOCK_COUNT_MAX = 5
SPLL_DELOCK_COUNT_FINAL = 1

RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = FAIL
RESET_STABLE = PASS
```

## Interpretation

cooldown8 沒有把系統帶到穩定閉迴路：

```text
Helper RMS 約 20928，仍有 109 次 error-band exits 與 actuator hunting
Helper 只在 117 個樣本曾 lock，觀測末端為 0
Main frequency final=1，但 phase/main/PSTAT final=0
full-chain 最長只有 0.274 秒
```

與 cooldown16 相比，cooldown8 的 Helper RMS 由約 5188 回升至約 20928，hunting 也沒有消失；與 cooldown0 相比，則沒有保留原本曾出現的較長 full-chain。這確認目前主要問題不只是 transaction rate，而是 PI/actuator interface 與 phase operating point 的互動。

## 原始紀錄

```text
raw-observer.tar.gz
SHA256 = b0f85d555a49e911e7ada490ad20c2a1972375c2c69bc62b24297b919ff6f3fd
```

封存內容包含 build、program、燒錄後 preflight、settled preflight 及完整 3600-snapshot observer log。

## 下一步

本輪之後停止 cooldown 掃描，回到 cooldown=0 的已知較佳 baseline，並依 `Astra建議.md` 改做 page-aware DCO/I2C contract audit：先在離線 model/testbench 解碼實際 page、mask、ACK 與 N0/N1 作用對象，再決定是否修正硬體交易。這比繼續微調相鄰 cooldown 更可能真正推進 Step5。

下一個硬體實驗若需要，應只修 page/mask isolation，固定 Main Kp=300、Helper Kp=-150、Ki=-1、bootstrap=3388、physical-step=64；不要與 PI、lock detector 或 Main absolute-target 同輪修改。若隔離確認後再重新辨識 operating point，最後才以真實 target/applied 與物理頻率量測整定 fine loop。

正式 Step5 PASS 仍必須同時滿足 Main/Helper/PSTAT lock、連續 300 秒 full chain、position accounting PASS、measurement coherence/accounting PASS，以及所有 reset delta 為零。任何只看到短暫 lock、低 rail 或沒有 hunting 的 rail-limit 窗口都不能 merge。
