# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-HELPER-RESEED-BIAS63252-20260912

## 判定

**Step 5：NOT COMPLETE（尚未通過）**

本輪最後是在 upstream-ready 狀態下完成 3600-sample observer，但 Helper 仍固定在 high rail，沒有 normal DCO transaction，也沒有啟動 Main。因此本輪不能宣告 PASS，也不能 merge。

另需注意：本輪是在同一個實體通電週期內，接續前一輪 Kp=-75 high-rail 反例做 warm reprogram。這使得外部 SI5340 殘留狀態可能污染 reseed-bias A/B；結果可作為失敗證據，但不能當成乾淨的 startup bias 因果結論。

## 實驗目的

3388、Kp=-150、Ki=-1 的 cold-power-cycle baseline 能將 Helper 帶到可控制區域，但仍有 hunting。Kp=-75 反例則固定在 high rail。依 Astra 建議，本輪保留已證明能驅動 actuator 的 Kp=-150，只把 coarse bootstrap 後的 Helper reseed 初始 bias 改為上一輪量到的 fine-loop target 63252，避免從 DAC rail 重新開始。

唯一 functional 變因：

- CONFIG_WR_NODE 下的 helper_reseed bias：使用 63252

保留：

- bootstrap steps = 3388
- Helper Kp = -150
- Helper Ki = -1
- Helper lock threshold = 2000
- Helper lock samples = 1000
- normal HPLL cooldown = 0
- HPLL physical/code step = 64
- Main PI、delock floor、DCO page/mask、reset tree 與 Step4B FSM

## 版本與 build

- Branch：exp/step5-softpll-lock
- Source commit：fa60ee2（fa60ee2cbb5480dcb6c36275bde74f9fd8f93103）
- Master build：PASS，timing_closed=NO
- Slave build：PASS，timing_closed=NO
- Master SOF SHA256：52429c72fc8032844c04e1f3ef4d8160c54413fdc3f99a54428bd2d2493de3f4
- Slave SOF SHA256：77eb95161382c2a21b1d47bc7fa5e6b972a43dd9cccf2e0f6184211d1da9916c

## Programming 與 upstream recovery

Programming 遵守 Master -> 45 秒 -> Slave，兩端 configuration 均成功。初次與第一次 Slave recovery 後仍停在 IRQ -> helper_update；再依已成功過的完整 warm-recovery 順序重新配置 Master -> 45 秒 -> Slave，等待 120 秒後得到有效窗口：

- Master Step1 / Step2 / Step3 / Step4A：PASS
- Slave Step1 / Step2 / Step3：PASS
- Slave Step4B：PASS
- Slave Helper update count：持續增加

因此最後的 observer 是 upstream-ready，但它不是實體斷電後的獨立 startup A/B。

## 3600-sample coherent observation

Observer：

    samples=3600
    gap_ms=100
    bootstrap_steps=3388
    code_per_physical_step=64
    helper kp=-150
    helper ki=-1
    reseed_bias=63252
    helper threshold=2000
    helper lock_samples=1000
    normal_hpll_cooldown_loads=0
    dco accounting=adjacent-snapshot-lower-bound modulo16

主要結果：

    COHERENT_MEASUREMENT_SNAPSHOTS=3600
    REJECTED_EPOCH_SNAPSHOTS=0
    REJECTED_ACCOUNTING_CANDIDATES=145
    MEASUREMENT_ACCOUNTING_FAILS=0
    POSITION_SNAPSHOTS=3600
    POSITION_INVARIANT_FAILS=0
    TRANSACTION_INVARIANT_FAILS=0
    DCO_TOTAL_LOWER_BOUND_FAILS=0
    MEASUREMENT_COHERENCE=PASS
    POSITION_ACCOUNTING=FAIL
    RESET_STABLE=PASS

    FREQ_ERROR_MEAN=-7.37027777778
    FREQ_ERROR_RMS=11.125633565
    FREQ_ERROR_MIN=-40
    FREQ_ERROR_MAX=23

    HELPER_ERROR_MEAN=-150000.0
    HELPER_ERROR_RMS=150000.0
    HELPER_ERROR_MAX_ABS=150000
    FRACTION_ABS_ERROR_LE_200=0.0
    LOW_RAIL_FRACTION=0.0
    HIGH_RAIL_FRACTION=1.0
    NO_RAIL_FRACTION=0.0

    LOCK_COUNT_MAX=54
    LOCK_COUNT_FINAL=14
    LOCK_COUNT_RISE_EVENTS=19
    LOCK_COUNT_FALL_EVENTS=19
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
    SPLL_DELOCK_COUNT_MAX=253
    SPLL_DELOCK_COUNT_FINAL=0

    RESET_BOOT_GENERATION_DELTA=0
    RESET_CPU_DELTA=0
    RESET_WR_CORE_DELTA=0
    RESET_SI_CONFIG_DELTA=0

## Interpretation

這輪沒有證明 63252 reseed bias 有效：

- raw FREQ_ERROR 仍接近零，但 Helper phase error 固定在 -150000 clamp。
- Helper output 全程 high rail，target=65531、applied=65541，兩者差距不足以再提交 normal physical step。
- Helper 從未 lock；Main 沒有 enable；完整 chain 維持 0 秒。
- 觀測 coherence 與 transaction invariants 通過，但 position accounting 仍失敗。

與 Kp=-75 反例相同的 high-rail 症狀，顯示主要問題不只是 reseed bias 數值。最可能的解釋是這個 warm run 的外部 SI5340 physical position 已與 FPGA 內部 virtual position 不一致，或 reseed 後第一個有效 tag 的 phase history/target contract 仍未對齊；需要 cold-power-cycle 與更細的 post-reseed trace 才能區分。

## 原始資料

- Raw archive：EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-HELPER-RESEED-BIAS63252-20260912-raw.tgz
- Raw archive SHA256：0d62394b001f9bcf3a91889799495ba07de2d14ead81ff96da2e6475120efa71
- 同目錄 raw/ 保存 build、program、recovery、preflight 與 observer logs。

## 下一輪

不要再直接掃 Kp、cooldown 或 threshold。先做實體斷電後的 clean rerun，確認 3388 baseline 是否可重現；若要再改功能，只加入 post-reseed 的最小 trace，記錄第一個有效 tag、raw/preclamp error、PI bias、target、applied 與第一筆 normal transaction，並維持 Kp=-150、Ki=-1、bootstrap=3388。

Step 5 必須同時滿足 continuous 300 秒、Helper/Main/PSTAT lock、position accounting PASS 與 reset delta=0，才可宣告 PASS。
