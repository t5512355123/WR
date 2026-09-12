# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-BASELINE-REPRO-20260912

## 判定

Step 5：NOT COMPLETE（尚未通過）。

本輪是冷開機、upstream-ready 的 bootstrap=3388 baseline 重現。它重現了 Helper lock 與持續 DCO transaction，但 Main phase lock 沒有成立，因此不能宣告 Step 5 PASS，也不能 merge。

## 實驗目的

確認前一輪有效 baseline 是否能在實體斷電重開後重現，排除熱機殘留或外部 SI5340 狀態造成的假象。

保留的 baseline：

- bootstrap steps = 3388
- Helper Kp = -150
- Helper Ki = -1
- normal HPLL cooldown = 0
- HPLL physical/code step = 64
- Helper lock threshold = 2000
- Helper lock samples = 1000
- 已存在的 DCO page/mask isolation、absolute target、frequency delock floor 與 static-FSM fix

## 版本與 build

- Branch：exp/step5-softpll-lock
- Source commit：164cd75e7257129f52fe5169a0bd98398cf41ee9
- Master build：PASS，timing_closed=NO
- Slave build：PASS，timing_closed=NO
- Master SOF SHA256：edd9eba04cc522db56b8d82d31543d3c86e619750f98dded02e2639fa7fbb715
- Slave SOF SHA256：62dc6d09f1cf7cfa51b51a9161448c2dd6d366939c5daad253d1c414bb71eb9c

## Programming 與 upstream

實體斷電後重新 clone、compile，並依 Master -> 45 秒 -> Slave 順序燒錄。兩張板的 programming 均完成。

等待啟動 recovery 後的 settled preflight：

- Master Step1 / Step2 / Step3 / Step4A：PASS
- Slave Step1 / Step2 / Step3 / Step4B：PASS
- Slave mode = 3（SLAVE）
- SoftPLL sequencer = SEQ_WAIT_MAIN
- Helper update count 持續增加

因此本輪 3600-sample observer 是有效的 Step5 測試窗口，不是 upstream-blocked。

## 3600-sample coherent observation

Observer 設定：

- samples = 3600
- gap = 100 ms
- bootstrap = 3388
- code per physical step = 64
- Helper Kp = -150
- Helper Ki = -1
- lock threshold = 2000
- lock samples = 1000
- adjacent-snapshot lower-bound modulo16 accounting

量測品質與 reset 穩定性：

    COHERENT_MEASUREMENT_SNAPSHOTS=3600
    REJECTED_EPOCH_SNAPSHOTS=0
    REJECTED_ACCOUNTING_CANDIDATES=110
    MEASUREMENT_ACCOUNTING_FAILS=0
    POSITION_SNAPSHOTS=3331
    POSITION_INVARIANT_FAILS=0
    TRANSACTION_INVARIANT_FAILS=0
    DCO_TOTAL_LOWER_BOUND_FAILS=0
    MEASUREMENT_COHERENCE=PASS
    POSITION_ACCOUNTING=FAIL
    RESET_STABLE=PASS

頻率誤差：

    FREQ_ERROR_MEAN=0.116388888889
    FREQ_ERROR_RMS=8.15548554314
    FREQ_ERROR_MIN=-34
    FREQ_ERROR_MAX=31
    FREQ_ERROR_FIRST=-1
    FREQ_ERROR_LAST=2

Helper dynamics：

    HELPER_ERROR_MEAN=0.329722222222
    HELPER_ERROR_RMS=782.520084762
    HELPER_ERROR_MAX_ABS=2371
    FRACTION_ABS_ERROR_LE_200=0.190277777778
    LOW_RAIL_FRACTION=0.0
    HIGH_RAIL_FRACTION=0.000555555556
    NO_RAIL_FRACTION=0.999444444444
    LOCK_COUNT_MAX=1000
    LOCK_COUNT_FINAL=1000
    LOCK_COUNT_RISE_EVENTS=32
    LOCK_COUNT_FALL_EVENTS=27
    ERROR_BAND_EXIT_EVENTS=423
    ACTUATOR_HUNT_OBSERVED=YES
    HELPER_DYNAMICS=UNDERDAMPED_OR_OVERAGGRESSIVE

DCO transaction：

    TARGET_FINAL=65265
    APPLIED_FINAL=65285
    EXPECTED_APPLIED_ABSOLUTE=65285
    NORMAL_REQ_DELTA_OBSERVED=5438
    NORMAL_COMPLETED_DELTA=5438
    FINC_DELTA=2738
    FDEC_DELTA=2700
    DCO_STEP_DELTA=15647
    BOOTSTRAP_COMPLETED_FINAL=3388
    BOOTSTRAP_DONE_FINAL=1

Lock chain：

    HELPER_LOCKED_SEEN=3455
    HELPER_LOCKED_FINAL=1
    FIRST_HELPER_LOCK_SAMPLE=1
    MAIN_ENABLED_FINAL=1
    MAIN_FREQ_LOCKED_FINAL=1
    MAIN_PHASE_LOCKED_FINAL=0
    MAIN_LOCKED_FINAL=0
    PSTAT_LOCKED_FINAL=0
    FULL_CHAIN_MAX_SECONDS=0.000
    FULL_CHAIN_300S=0
    STEP5_CHAIN_RESULT=NOT_COMPLETE

    SPLL_DELOCK_COUNT_FIRST=0
    SPLL_DELOCK_COUNT_MAX=202
    SPLL_DELOCK_COUNT_FINAL=0

    RESET_BOOT_GENERATION_DELTA=0
    RESET_CPU_DELTA=0
    RESET_WR_CORE_DELTA=0
    RESET_SI_CONFIG_DELTA=0

## Interpretation

這輪確認 bootstrap=3388、Kp=-150、Ki=-1 的 baseline 在冷開機後可重現：

- upstream 正常，Step4B 正常。
- Helper 很快進入 lock，並在大部分觀測窗口保持 lock。
- Main frequency lock 成立，但 Main phase lock 全程為 0。
- DCO normal request 與 completed transaction 一致，且 reset delta 維持 0。
- 頻率誤差平均值接近 0，但 error-band exit 次數高，顯示控制迴路仍有 underdamped hunting。
- position accounting 仍為 FAIL；雖然 transaction invariant 與 DCO lower-bound invariant 沒有失敗，仍不足以作為 Step5 證據。

因此目前真正的瓶頸已收斂為「Main phase lock / phase convergence」與控制器的 hunting，不是 VUART、upstream、bootstrap 或 DCO transaction delivery。

本輪也排除了「前一輪結果只是熱機污染」的解釋；冷開機仍得到相同方向的結果。Step 5 必須同時具備 continuous 300 秒、Helper/Main/PSTAT lock、phase convergence、position accounting PASS 與 reset delta=0，本輪不符合。

## 下一輪

依 Astra 建議，下一輪先增加最小 PI trace 與 target -> applied -> physical transaction 的 persistent 對照，至少記錄 bootstrap 後第一個有效 target、raw/preclamp error、PI bias、輸出、target admission 與第一筆 normal transaction。現有 observer 明確顯示 PI_TRACE_AVAILABLE=NO，這是目前最重要的可觀測性缺口。

在取得這些證據前，不再盲目掃描 Kp、Ki 或 cooldown；尤其 Kp=-75 已證明會失去 actuator authority。下一輪仍應只做一個隔離變因，並沿用本輪 cold/upstream-ready、3600-sample coherent observer 與同一份 Step5 判定門檻。

## 原始資料

- Raw archive：raw-observer.tar.gz
- Raw archive SHA256：c658f9568a76228fe342ee607b69eb1623388ea6390ffa827b45ff7d2f53be51
- archive 內含 observer、settled preflight、build 與 programming logs。
