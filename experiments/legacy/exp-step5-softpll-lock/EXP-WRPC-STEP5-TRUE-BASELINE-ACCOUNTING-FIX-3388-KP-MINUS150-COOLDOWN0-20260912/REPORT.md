# EXP-WRPC-STEP5-TRUE-BASELINE-ACCOUNTING-FIX-3388-KP-MINUS150-COOLDOWN0-20260912

## 結論

本輪只修正 coherent observer 的 bootstrap accounting 常數；後續 source audit 確認本輪 fitted Slave image 的實際 cooldown 是 `8`，不是資料夾名稱與早期報告所寫的 `0`。修正後 position accounting 已通過，且系統確實可進入完整 lock；但仍未達成 Step5 PASS。

    STEP1_REGRESSION = PASS
    STEP2_REGRESSION = PASS
    STEP3_REGRESSION = PASS
    STEP4A_RESULT = PASS
    STEP4B_ALLOWED = YES
    STEP4B_RESULT = PASS
    MEASUREMENT_COHERENCE = PASS
    POSITION_ACCOUNTING = PASS
    RESET_STABLE = PASS
    STEP5_CHAIN_RESULT = NOT_COMPLETE
    MERGE_APPROVED = NO

本輪完整鎖定最長 113.791 秒，低於要求的連續 300 秒；觀測期間仍有 Helper error-band exits 與 hunting。

## 唯一變更

Source/observer commit：

    17f20ad32c619212133e6134205cf017212d7dd8

coherent observer 原本錯誤使用：

    bootstrap_steps = 3372

本輪修正為與目前 Slave image 相同的：

    bootstrap_steps = 3388

這是 measurement-only 修正，不改變 FPGA 控制器、PI gain、DCO page/mask、Main absolute target、lock threshold 或 Step5 判定語意。資料夾名稱中的 cooldown=0 是歷史 provenance 標籤，並非本輪 fitted image 的實際設定。

硬體設定維持：

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

## Build / program

Pain 已由 GitHub 拉取 commit 17f20ad，Master/Slave Quartus build 與 JTAG programming 均成功。

    Master SOF SHA256 = d58873136bfa41afdf40225421f5a26f6602187ab7fe0547820dacc92b3eae98
    Slave  SOF SHA256 = 3cda3f9b65db4b388f3f1087d7b225227541f12599e7b230e3a1dd5e5ea7a555
    Master programmer = successful, 0 errors
    Slave programmer = successful, 0 errors
    TIMING_CLOSED = NO

燒錄順序為 Master，等待 45 秒，再 Slave；兩張 DE5a 均回報 configuration succeeded。

## Settled preflight

燒錄後等待 120 秒，JTAG/WB transport revalidation 及 upstream gate 通過：

    WB_TRANSPORT_PROTOCOL = PRELOAD_THEN_TOGGLE_COMMIT
    PRELOAD_UNEXPECTED_TRIGGER_COUNT = 0
    PROBE_3WAY_MATCH_COUNT = 353
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

## 3600-snapshot coherent observer

    SAMPLES = 3600
    ELAPSED = 427965 ms
    POST_BOOTSTRAP_BASELINE_SAMPLE = 1
    POST_BOOTSTRAP_BASELINE_SET = 1
    COHERENT_MEASUREMENT_SNAPSHOTS = 3600
    REJECTED_EPOCH_SNAPSHOTS = 0
    REJECTED_ACCOUNTING_CANDIDATES = 1
    MEASUREMENT_ACCOUNTING_FAILS = 0
    POSITION_SNAPSHOTS = 3574
    POSITION_INVARIANT_FAILS = 0
    TRANSACTION_INVARIANT_FAILS = 0
    DCO_TOTAL_LOWER_BOUND_FAILS = 0

    FREQ_ERROR_MEAN = -0.135833333333
    FREQ_ERROR_RMS = 9.80191307858
    FREQ_ERROR_MIN = -31
    FREQ_ERROR_MAX = 32

    HELPER_ERROR_MEAN = 10.5983333333
    HELPER_ERROR_RMS = 1026.19685165
    HELPER_ERROR_MAX_ABS = 5369
    FRACTION_ABS_ERROR_LE_200 = 0.211388888889
    LOW_RAIL_FRACTION = 0.0
    HIGH_RAIL_FRACTION = 0.0
    NO_RAIL_FRACTION = 1.0
    LOCK_COUNT_MAX = 1000
    LOCK_COUNT_FINAL = 1000
    LOCK_COUNT_RISE_EVENTS = 214
    LOCK_COUNT_FALL_EVENTS = 160
    ERROR_BAND_EXIT_EVENTS = 393
    ACTUATOR_HUNT_OBSERVED = YES
    HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE
    HELPER_LOCKED_SEEN = 2918
    HELPER_LOCKED_FINAL = 1
    FIRST_HELPER_LOCK_SAMPLE = 24

    MAIN_ENABLED_FINAL = 1
    MAIN_FREQ_LOCKED_FINAL = 1
    MAIN_PHASE_LOCKED_FINAL = 1
    MAIN_LOCKED_FINAL = 1
    PSTAT_LOCKED_FINAL = 1
    FULL_CHAIN_MAX_SECONDS = 113.791
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
    POSITION_ACCOUNTING = PASS
    RESET_STABLE = PASS

## Interpretation

這次修正排除了 observer 的 3372/3388 mismatch。position accounting 現在有真正的 post-bootstrap baseline，且所有 position、transaction、DCO lower-bound invariant 都通過。這表示先前的 POSITION_ACCOUNTING=FAIL 主要是觀測起點 bug，不應再作為硬體控制器失敗的結論。

同時，真正 baseline 的 Helper error RMS 約 1026，且 Helper 最終仍維持 lock；Main、phase、PSTAT 也都為 1，沒有 reset。但 full-chain 只有 113.791 秒，期間有 393 次 error-band exits 與 160 次 lock-count fall，仍不是可接受的 300 秒穩態。

因此目前最可能的剩餘瓶頸是 Helper fine-loop 的量化／欠阻尼 limit-cycle，而不是 Step1–4B、JTAG transport 或 position accounting。下一輪應保持 observer accounting 修正，並只改一個可隔離的 Helper actuator/PI operating-point 參數；不得用放寬 lock threshold 取代真正的穩定性。

## 原始資料

    raw-observer.tar.gz
    SHA256 = 583b0c67b0e5653a5645bffe0883a4715a2a77164f54c29aaef9b174ac9cbfc2

封存內容包含 Master/Slave build identity 與 build logs、programming summary、燒錄後 preflight log，以及完整 3600-snapshot observer log。

## 判定

    STEP5 = NOT PASS
    MERGE_APPROVED = NO
