# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-HELPER-KP-MINUS75-20260912

## 判定

**Step 5：NOT COMPLETE（尚未通過）**

本輪是有效的 upstream-ready Step5 測試，但 Kp=-75 沒有改善控制；Helper 最終落在 high rail，沒有形成 Main/phase/PSTAT lock。因此本輪是反例，不能宣告 PASS，也不能 merge。

## 實驗目的

上一輪 bootstrap=3388、Helper Kp=-150、Ki=-1 已把工作點帶到接近零誤差，但出現 underdamped hunting。依 Astra 建議，本輪只降低比例控制權，測試較柔和的回授是否能抑制 hunting。

唯一 functional 變因：

- Helper Kp：-150 -> -75

保留：

- bootstrap steps = 3388
- Helper Ki = -1
- Helper lock threshold = 2000
- Helper lock samples = 1000
- normal HPLL cooldown = 0
- HPLL physical/code step = 64
- Main PI、delock floor、DCO page/mask、reset tree 與 Step4B FSM

## 版本與 build

- Branch：exp/step5-softpll-lock
- Source commit：d44b4f9（d44b4f9816f5a13d81aeb6536573c1fe3b579084）
- Master build：PASS，timing_closed=NO
- Slave build：PASS，timing_closed=NO
- Master SOF SHA256：543e0407742721d777c2b7bd17cccfd9792797ef6e97145f4f91a026535301af
- Slave SOF SHA256：29bcfd3b7e935789ae24308cb5ae9d3a59b08d1549dd351f4e278107f00784a8

## Programming 與 upstream

Programming 順序遵守 Master -> 45 秒 -> Slave，兩次 configuration 均成功。第一次 preflight 的 Slave 仍在啟動 recovery，Step2 尚未 ready；重新燒錄 Slave 並等待完整 120 秒後，得到有效窗口：

- Master Step1 / Step2 / Step3 / Step4A：PASS
- Slave Step1 / Step2 / Step3：PASS
- Slave Step4B：PASS
- Helper update count 持續增加

因此後續 observer 不是 upstream-blocked 測試。

## 3600-sample coherent observation

Observer：

    samples=3600
    gap_ms=100
    bootstrap_steps=3388
    code_per_physical_step=64
    helper kp=-75
    helper ki=-1
    helper threshold=2000
    helper lock_samples=1000
    normal_hpll_cooldown_loads=0
    dco accounting=adjacent-snapshot-lower-bound modulo16

主要結果：

    COHERENT_MEASUREMENT_SNAPSHOTS=3600
    REJECTED_EPOCH_SNAPSHOTS=0
    REJECTED_ACCOUNTING_CANDIDATES=118
    MEASUREMENT_ACCOUNTING_FAILS=0
    POSITION_SNAPSHOTS=3600
    POSITION_INVARIANT_FAILS=0
    TRANSACTION_INVARIANT_FAILS=0
    DCO_TOTAL_LOWER_BOUND_FAILS=0
    MEASUREMENT_COHERENCE=PASS
    POSITION_ACCOUNTING=FAIL
    RESET_STABLE=PASS

    FREQ_ERROR_MEAN=-2.15472222222
    FREQ_ERROR_RMS=10.8976679462
    FREQ_ERROR_MIN=-36
    FREQ_ERROR_MAX=32

    HELPER_ERROR_MEAN=-150000.0
    HELPER_ERROR_RMS=150000.0
    HELPER_ERROR_MAX_ABS=150000
    FRACTION_ABS_ERROR_LE_200=0.0
    LOW_RAIL_FRACTION=0.0
    HIGH_RAIL_FRACTION=1.0
    NO_RAIL_FRACTION=0.0

    LOCK_COUNT_MAX=56
    LOCK_COUNT_FINAL=14
    LOCK_COUNT_RISE_EVENTS=13
    LOCK_COUNT_FALL_EVENTS=13
    ERROR_BAND_EXIT_EVENTS=0
    ACTUATOR_HUNT_OBSERVED=NO
    HELPER_DYNAMICS=STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT

    TARGET_FINAL=65531
    APPLIED_FINAL=65541
    EXPECTED_APPLIED_ABSOLUTE=65541
    NORMAL_REQ_DELTA_OBSERVED=0
    NORMAL_COMPLETED_DELTA=0
    FINC_DELTA=0
    FDEC_DELTA=0
    DCO_STEP_DELTA=0
    BOOTSTRAP_COMPLETED_FINAL=3388
    BOOTSTRAP_DONE_FINAL=1

    HELPER_LOCKED_SEEN=0
    HELPER_LOCKED_FINAL=0
    FIRST_HELPER_LOCK_SAMPLE=NONE
    MAIN_ENABLED_FINAL=0
    MAIN_FREQ_LOCKED_FINAL=0
    MAIN_PHASE_LOCKED_FINAL=0
    MAIN_LOCKED_FINAL=0
    PSTAT_LOCKED_FINAL=0

    FULL_CHAIN_MAX_SECONDS=0.000
    FULL_CHAIN_300S=0
    STEP5_CHAIN_RESULT=NOT_COMPLETE
    SPLL_DELOCK_COUNT_FIRST=0
    SPLL_DELOCK_COUNT_MAX=252
    SPLL_DELOCK_COUNT_FINAL=0

    RESET_BOOT_GENERATION_DELTA=0
    RESET_CPU_DELTA=0
    RESET_WR_CORE_DELTA=0
    RESET_SI_CONFIG_DELTA=0

## Interpretation

這個結果排除了「只要降低 Kp 就能抑制 3388 工作點 hunting」的假設：

- 雖然 raw FREQ_ERROR 仍接近零，Helper error 卻固定在 -150000 clamp。
- Helper output 長時間為 high rail，沒有 normal DCO request 或完成交易。
- Helper 從未達到 lock；Main 沒有 enable，整條 chain 維持 0 秒。
- position accounting 仍失敗，但 transaction invariant 與 DCO lower-bound invariant 沒有因觀測器 coherence 而失敗。

因此 Kp=-75 不是較穩定的工作點，而是控制權不足或 PI 起始狀態與此 operating point 不相容。這也說明 Kp=-150 的有效性不能直接用「減半增益」改善；下一輪不應再盲目降低 Kp。

## 原始資料

- Raw archive：EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-HELPER-KP-MINUS75-20260912-raw.tgz
- Raw archive SHA256：1b282e39260e5f8eece02c66bb5834254c4002c7279cd1a179aad3c64272a0ee
- 同目錄 raw/ 保存 build、program、recovery、preflight 與 observer logs。

## 下一輪

回到已證明能驅動 actuator 的 baseline：bootstrap=3388、Kp=-150、Ki=-1、cooldown=0。不要把 Kp=-75 合入 baseline。

下一個 isolated A/B 應改查控制器的起始條件與 actuator authority，而不是繼續單向縮小 Kp：先保留 Kp=-150，增加最小化的 PI trace/target/applied/physical transaction 對照，確認 Helper 在 bootstrap 完成後的第一個有效 target、integrator、輸出與 target-to-step admission 是否一致。若要修改功能，必須只選一個明確的 anti-windup 或 startup reseed 行為，並以同一套 3600-sample observer 驗證。

Step 5 仍須同時滿足 continuous 300 秒、Helper/Main/PSTAT lock、position accounting PASS 與 reset delta=0，才可宣告 PASS。
