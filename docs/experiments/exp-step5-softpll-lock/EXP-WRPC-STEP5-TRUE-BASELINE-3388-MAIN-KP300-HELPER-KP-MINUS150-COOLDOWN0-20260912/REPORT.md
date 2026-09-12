# EXP-WRPC-STEP5-TRUE-BASELINE-3388-MAIN-KP300-HELPER-KP-MINUS150-COOLDOWN0-20260912

## 結論

本輪是 provenance 修正後的 Kp=-150 baseline，但後續 source audit 確認 fitted Slave image 的實際 cooldown 是 `8`，不是資料夾名稱與早期報告所寫的 `0`。系統確實進入閉迴路並在觀測期間多次達到全鎖狀態，但未達成 Step5 PASS。

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

主要原因是 Helper 在觀測結尾掉出 lock，且仍有 actuator hunting；full-chain 最長只有 13.178 秒，未達連續 300 秒。

## 實驗設定

    source commit = 75736ce8913f7e4e8bc1a9778f6d56fc6b8f101c
    branch = exp/step5-softpll-lock
    Main Kp = +300
    Main Ki = +1
    Helper Kp = -150
    Helper Ki = -1
    bootstrap = 3388
    reverse = 1
    code_per_physical_step = 64
    STEP5_NORMAL_HPLL_COOLDOWN_LOADS = 8 (actual top-level override)
    helper threshold = 2000
    helper lock samples = 1000

本輪同時把 observer experiment label 修正為上述可信設定；沒有修改 Step5 判定門檻、DCO accounting 或 lock semantics。

## Build / program

Pain 已由 GitHub 拉取 commit 75736ce，Master/Slave Quartus build 與 JTAG programming 均成功。

    Master SOF SHA256 = 44ea9b10643c981a12aa78b896d2d183288bcc97d6ab1b10b69ee2030c06ff8f
    Slave  SOF SHA256 = 7c067b48687443a52eb090d3fc6dc6b658abf28cfa2a7862fb797d2ae1f32057
    Master programmer = successful, 0 errors
    Slave programmer = successful, 0 errors
    TIMING_CLOSED = NO
    Master WNS = -0.058 ns
    Slave WNS = -0.001 ns

燒錄順序為 Master，等待 45 秒，再 Slave；兩張 DE5a 均回報 configuration succeeded。

## Settled preflight

燒錄後等待 120 秒，JTAG/WB transport revalidation 通過：

    WB_TRANSPORT_PROTOCOL = PRELOAD_THEN_TOGGLE_COMMIT
    PRELOAD_UNEXPECTED_TRIGGER_COUNT = 0
    PROBE_3WAY_MATCH_COUNT = 352
    STABLE_RESPONSE_WRONG_COUNT = 0
    ADDRESS_CROSS_CONTAMINATION_COUNT = 0
    TIMEOUT_COUNT = 0
    INVALID_COUNT = 0
    PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
    JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
    STEP4A_RESULT = PASS
    STEP4B_ALLOWED = YES
    STEP4B_RESULT = PASS
    STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE

Preflight 當下的 Slave helper 尚未 lock，故仍照計畫完成完整 observer；不能把 preflight 狀態當成長時間判定。

## 3600-snapshot coherent observer

    SAMPLES = 3600
    ELAPSED = 435258 ms
    COHERENT_MEASUREMENT_SNAPSHOTS = 3600
    REJECTED_EPOCH_SNAPSHOTS = 0
    REJECTED_ACCOUNTING_CANDIDATES = 6
    MEASUREMENT_ACCOUNTING_FAILS = 0
    POSITION_SNAPSHOTS = 3556
    POSITION_INVARIANT_FAILS = 0
    TRANSACTION_INVARIANT_FAILS = 0
    DCO_TOTAL_LOWER_BOUND_FAILS = 0

    FREQ_ERROR_MEAN = -0.004444444444
    FREQ_ERROR_RMS = 8.64355893779
    FREQ_ERROR_MIN = -29
    FREQ_ERROR_MAX = 30

    HELPER_ERROR_MEAN = 2.13722222222
    HELPER_ERROR_RMS = 1752.33650482
    HELPER_ERROR_MAX_ABS = 6197
    FRACTION_ABS_ERROR_LE_200 = 0.227777777778
    LOW_RAIL_FRACTION = 0.0
    HIGH_RAIL_FRACTION = 0.0
    NO_RAIL_FRACTION = 1.0
    LOCK_COUNT_MAX = 1000
    LOCK_COUNT_FINAL = 0
    LOCK_COUNT_RISE_EVENTS = 454
    LOCK_COUNT_FALL_EVENTS = 339
    ERROR_BAND_EXIT_EVENTS = 366
    ACTUATOR_HUNT_OBSERVED = YES
    HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE
    HELPER_LOCKED_SEEN = 2247
    HELPER_LOCKED_FINAL = 0
    FIRST_HELPER_LOCK_SAMPLE = 4

    MAIN_ENABLED_FINAL = 1
    MAIN_FREQ_LOCKED_FINAL = 1
    MAIN_PHASE_LOCKED_FINAL = 1
    MAIN_LOCKED_FINAL = 1
    PSTAT_LOCKED_FINAL = 1
    FULL_CHAIN_MAX_SECONDS = 13.178
    FULL_CHAIN_300S = 0
    STEP5_CHAIN_RESULT = NOT_COMPLETE

    SPLL_DELOCK_COUNT_FIRST = 0
    SPLL_DELOCK_COUNT_MAX = 5
    SPLL_DELOCK_COUNT_FINAL = 0
    RESET_BOOT_GENERATION_DELTA = 0
    RESET_CPU_DELTA = 0
    RESET_WR_CORE_DELTA = 0
    RESET_SI_CONFIG_DELTA = 0
    MEASUREMENT_COHERENCE = PASS
    POSITION_ACCOUNTING = FAIL
    RESET_STABLE = PASS

## Interpretation

相較於先前未正確標籤的 cooldown scan，本輪證明真正的 Kp=-150/cooldown=0 已能讓 Main、phase、PSTAT 最終保持 lock，且不發生 reset；但 Helper 的 lock count 從有效狀態反覆掉出，觀測末端為 0。Helper RMS 約 1752，仍有 366 次 error-band exit，說明目前是可收斂但欠阻尼／仍會重新搜尋的 operating point，不是可宣稱 Step5 完成的穩態鎖定。

因此下一輪不應再把 cooldown 當成唯一旋鈕。應依 Astra 建議，保留已存在的 page/mask 與 Main absolute-target 修正，針對 Helper PI/plant operating point 做一個可隔離、可重複的功能變更；並保留 300 秒、position accounting、PSTAT 及 reset gates。

## 原始資料

    raw-observer.tar.gz
    SHA256 = 3ca2a9d70a889e71f86ac9b9d71b3aa2c5bb78badce341196b2108f3e82f253d

封存內容包含 Master/Slave build identity 與 build logs、programming summary、燒錄後 preflight log，以及完整 3600-snapshot observer log。

## 判定

    STEP5 = NOT PASS
    MERGE_APPROVED = NO
