# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-MAIN-KP300-20260912

## 判定

Step 5：NOT COMPLETE（尚未通過）。

本輪的 Main Kp=+300 確實讓 Main phase/full lock 與 PSTAT lock 出現，但 Helper 仍然反覆離開 lock、造成 full-chain 連續時間不足；因此不能宣告 Step 5 PASS，也不能 merge。

## 實驗目的與唯一功能變因

前一輪 Main PI trace 顯示：

- Main PI output 約 10906，沒有 rail saturation。
- Main PI input 約 7838，長期高於 phase threshold 1200。
- Main phase lock ever/final=0。

本輪只將 WR node Main PI Kp 從 +150 改為 +300，保留：

- Main Ki = +1
- Main phase threshold = 1200
- Main phase lock samples = 1000
- Helper Kp/Ki = -150/-1
- bootstrap = 3388
- HPLL code per physical step = 64
- cooldown = 0
- reset、DCO page/mask、absolute target/applied 與 Step4B FSM

沒有放寬 lock threshold，也沒有 bypass Helper gate。

## 版本與 build

- Branch：exp/step5-softpll-lock
- Source commit：c7abc0f082576d14767ead1fdebc314df48a8254
- Master build：PASS，timing_closed=NO
- Slave build：PASS，timing_closed=NO
- Master SOF SHA256：086c58e934d849a12221b1b3f47acc926a0f9e970c19ad68263c886ecefff299
- Slave SOF SHA256：8ca042384fbefd099262dbda3ca93bd80d913b9ad6844aca5092a1cad37a0ed3

## Programming 與 upstream

依 Master -> 45 秒 -> Slave 順序燒錄完成。等待 120 秒後的 settled preflight：

- Master Step1 / Step2 / Step3 / Step4A：PASS
- Slave Step1 / Step2 / Step3 / Step4B：PASS
- Helper lock：1
- Main enabled：1
- Main frequency lock：1
- Main phase lock：0（preflight 時點）
- PSTAT lock：0（preflight 時點）
- first inactive boundary：MAIN_PHASE_LOCK

因此後續 observer 是 upstream-ready 的有效窗口。

## 600-sample Main quick confirmation

這個短 observer 用來確認 Main Kp 變更方向，設定為 600 samples、100 ms cadence：

    SAMPLES=600
    ELAPSED_MS=110903
    TRACE_VALID=600
    TRACE_UNIQUE=72
    TRACE_DEDUP_SKIPPED=528
    FRAME_VALID=558
    INVALID=0
    FREQ_ERROR_MEAN=17.7083333333
    FREQ_ERROR_RMS=27.3838456028
    FREQ_ERROR_MIN=-13
    FREQ_ERROR_MAX=60
    FRACTION_ABS_FREQ_ERROR_LE_50=0.930555555556
    PRELOCK_ERROR_MISMATCHES=0
    MEASUREMENT_FAILS=1
    PI_LOW_RAIL_FRACTION=0.0
    PI_HIGH_RAIL_FRACTION=0.0
    PI_NO_RAIL_FRACTION=0.986111111111

短窗口最終狀態：

    MAIN_FREQ_LOCKED_EVER=1
    MAIN_FREQ_LOCKED_FINAL=1
    MAIN_PHASE_LOCKED_EVER=1
    MAIN_PHASE_LOCKED_FINAL=1
    MAIN_LOCKED_EVER=1
    MAIN_LOCKED_FINAL=1
    PSTAT_LOCKED_EVER=1
    PSTAT_LOCKED_FINAL=1
    HELPER_LOCKED_EVER=1
    HELPER_LOCKED_FINAL=1
    SPLL_DELOCK_MAX=0
    RESET_STABLE=PASS
    MAIN_PI_X_FINAL=-119
    MAIN_PI_OUTPUT_FINAL=8329

這證明 Kp=+300 能把 Main phase input 拉入 ±1200 並啟動完整 lock chain；但 600 samples 約 111 秒，不能取代 300 秒 continuous closure。

## 3600-sample coherent closed-loop result

完整 observer 的摘要：

    SAMPLES=3600
    COHERENT_MEASUREMENT_SNAPSHOTS=3600
    REJECTED_EPOCH_SNAPSHOTS=0
    REJECTED_ACCOUNTING_CANDIDATES=113
    MEASUREMENT_ACCOUNTING_FAILS=0
    POSITION_SNAPSHOTS=3495
    POSITION_INVARIANT_FAILS=0
    TRANSACTION_INVARIANT_FAILS=0
    DCO_TOTAL_LOWER_BOUND_FAILS=0
    MEASUREMENT_COHERENCE=PASS
    POSITION_ACCOUNTING=FAIL

頻率與 Helper dynamics：

    FREQ_ERROR_MEAN=2.16111111111
    FREQ_ERROR_RMS=11.0115343567
    FREQ_ERROR_MIN=-146
    FREQ_ERROR_MAX=37
    HELPER_ERROR_MEAN=-2648.91583333
    HELPER_ERROR_RMS=19588.9726636
    HELPER_ERROR_MAX_ABS=150000
    FRACTION_ABS_ERROR_LE_200=0.0711111111111
    LOW_RAIL_FRACTION=0.000555555556
    HIGH_RAIL_FRACTION=0.0213888888889
    NO_RAIL_FRACTION=0.978055555556
    LOCK_COUNT_MAX=1000
    LOCK_COUNT_FINAL=1000
    LOCK_COUNT_RISE_EVENTS=573
    LOCK_COUNT_FALL_EVENTS=365
    ERROR_BAND_EXIT_EVENTS=167
    ACTUATOR_HUNT_OBSERVED=YES
    HELPER_DYNAMICS=UNDERDAMPED_OR_OVERAGGRESSIVE

DCO transaction：

    TARGET_FINAL=61677
    APPLIED_FINAL=61701
    EXPECTED_APPLIED_ABSOLUTE=61701
    NORMAL_REQ_DELTA_OBSERVED=13600
    NORMAL_COMPLETED_DELTA=13600
    FINC_DELTA=6798
    FDEC_DELTA=6802
    DCO_STEP_DELTA=21319
    BOOTSTRAP_COMPLETED_FINAL=3388
    BOOTSTRAP_DONE_FINAL=1

Lock chain：

    HELPER_LOCKED_SEEN=1034
    HELPER_LOCKED_FINAL=1
    FIRST_HELPER_LOCK_SAMPLE=508
    MAIN_ENABLED_FINAL=1
    MAIN_FREQ_LOCKED_FINAL=1
    MAIN_PHASE_LOCKED_FINAL=1
    MAIN_LOCKED_FINAL=1
    PSTAT_LOCKED_FINAL=1
    FULL_CHAIN_MAX_SECONDS=12.685
    FULL_CHAIN_300S=0
    STEP5_CHAIN_RESULT=NOT_COMPLETE

健康與 reset：

    SPLL_DELOCK_COUNT_FIRST=1
    SPLL_DELOCK_COUNT_MAX=245
    SPLL_DELOCK_COUNT_FINAL=2
    RESET_BOOT_GENERATION_DELTA=0
    RESET_CPU_DELTA=0
    RESET_WR_CORE_DELTA=0
    RESET_SI_CONFIG_DELTA=0
    RESET_STABLE=PASS

## Interpretation

本輪確認兩個重要事實：

1. Main Kp=+300 是正確方向的功能改善。短窗口與完整窗口都看到 Main phase/full lock、PSTAT lock；Main phase input 已能進入 lock band。
2. Step 5 的剩餘瓶頸是 Helper stability，不是 Main phase admission。完整窗口中 Helper error 有 16.7% band exit，high rail 約 2.14%，full-chain 最長只有 12.685 秒，無法達到 300 秒。

因此目前不能把「最後 snapshot 的所有 lock bit=1」誤認為 Step5 pass。continuous full-chain、Helper stability 與 position accounting 仍未通過。

注意：coherent observer 的 CONFIG 行仍殘留 main_kp=150 舊 metadata，但已燒錄硬體的 Main trace 明確回報 MAIN_PI_KP=300，且短 observer 的 lock 結果與 Kp=300 一致。下一輪必須先修正此 provenance，再作功能 A/B。

## 下一輪

保留已證明有效的 Main Kp=+300，只將 Helper Kp 從 -150 受控下調至 -125，Ki=-1、bootstrap=3388、cooldown=0 與所有 Main 設定保持不變。這是針對本輪 Helper underdamped/high-rail 症狀的單一比例 authority refinement；若重新出現 high-rail 或失去 Helper lock，立即回到 -150 baseline，不再繼續盲掃。

同時修正 coherent observer 的 Main metadata 為 main_kp=300，並使用同一個 3600-sample coherent closure 與同一套 Step5 門檻。

## 原始資料

- Raw archive：raw-observer.tar.gz
- Raw archive SHA256：659b4e66ec1d9ddf4132688e2c9bb2ff543eff02dce3bf1784b4f1603fc447d7
- archive 內含 quick Main observer、coherent closure、preflight、settled preflight、build 與 programming logs。
