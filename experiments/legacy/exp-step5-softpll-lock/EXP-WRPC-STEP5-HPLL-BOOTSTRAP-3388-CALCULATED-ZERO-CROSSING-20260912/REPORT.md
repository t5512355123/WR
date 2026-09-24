# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-3388-CALCULATED-ZERO-CROSSING-20260912

## 判定

**Step 5：NOT COMPLETE（尚未通過）**

本輪不是 upstream failure，也不是觀測器失效。Step 1–4B 已通過，並且已經觀察到 Main frequency lock、Main phase lock、Main lock 與 PSTAT.locked；但是完整 closed-loop lock 沒有維持要求的 300 秒，故不能宣告 Step 5 PASS。

## 實驗目的

上一輪以 STEP5_BOOTSTRAP_STEPS=3372 觀測到 Helper 長時間卡在 high rail。依上一輪量測的工作點斜率：

- FREQ_ERROR_MEAN = -3.531
- 每個 physical FINC step 約 +0.216 frequency-error count
- 計算得到需要增加約 16 steps

本輪將 bootstrap 工作點由 3372 改為計算出的 3388，只驗證 operating point 是否能把 Helper 拉回可控制區域。

## 版本與範圍

- Branch：exp/step5-softpll-lock
- Source commit：acbe3d1（acbe3d18961816980ff9fda02fb21d37edd7acda）
- Functional change：STEP5_BOOTSTRAP_STEPS 3372 -> 3388
- Observer provenance：同步更新實驗名稱與 bootstrap_steps=3388
- 未修改：Helper/Main PI、lock threshold、DCO page/mask sequence、frequency delock floor、reset tree、Step4B FSM、正常 HPLL tracker semantics

## Build / program

兩張 DE5a 均以同一個 source commit fresh build：

| Image | Build | SOF SHA256 |
|---|---|---|
| Master | PASS | 5d430d5e1579a3eabeae25ff00553beede1d5ea92379163a22757ba3988b4e61 |
| Slave | PASS | 147039c8940987cdf99bb08b032153e4b68bb17bbac8a472d4e80e6e8203dda4 |

Timing closure 仍為 NO，與本輪 functional lock stability 判定分開記錄。

Programming sequence：

1. Master programming：PASS
2. 等待 45 秒
3. Slave programming：PASS
4. 等待 120 秒後做 settled preflight

## Upstream preflight

Programming 後的第一次 preflight 中 Slave 暫時為 PTP=8 UNCALIBRATED，所以當下 Step 2 尚未 ready。等待 120 秒後重新讀取：

- Master：Step 1 / Step 2 / Step 3 = PASS
- Slave：PTP=9 SLAVE，Step 1 / Step 2 / Step 3 = PASS
- Step 4B：PASS
- LOCK_ENABLE_COUNT=4

Settled snapshot 曾同時得到：

    HELPER locked=1
    MAIN enabled=1
    MAIN locked=1
    MAIN frequency locked=1
    MAIN phase locked=1
    PSTAT_locked=1
    STEP5_RESULT=LOCK_ACQUIRED_NOT_STABLE
    first inactive boundary=STABILITY_WINDOW

這個 snapshot 證明初始化與 downstream path 可以進入 lock，不代表已達成 Step 5 的持續穩定條件。

## Coherent closed-loop observation

Observer configuration：

    samples=3600
    gap_ms=100
    bootstrap_steps=3388
    code_per_physical_step=64
    helper kp=-150
    helper ki=-1
    helper threshold=2000
    helper lock_samples=1000
    main frequency threshold=50
    dco accounting=adjacent-snapshot-lower-bound modulo16

結果：

    COHERENT_MEASUREMENT_SNAPSHOTS=3600
    REJECTED_EPOCH_SNAPSHOTS=0
    MEASUREMENT_ACCOUNTING_FAILS=0
    POSITION_SNAPSHOTS=3600
    POSITION_INVARIANT_FAILS=0
    TRANSACTION_INVARIANT_FAILS=0
    DCO_TOTAL_LOWER_BOUND_FAILS=0

    FREQ_ERROR_MEAN=0.111138888889
    FREQ_ERROR_RMS=9.25225197812
    FREQ_ERROR_MIN=-36
    FREQ_ERROR_MAX=32

    HELPER_ERROR_MEAN=7.98777777778
    HELPER_ERROR_RMS=595.916295856
    HELPER_ERROR_MAX_ABS=1986
    FRACTION_ABS_ERROR_LE_200=0.254166666667
    LOW_RAIL_FRACTION=0.0
    HIGH_RAIL_FRACTION=0.0
    NO_RAIL_FRACTION=1.0

    LOCK_COUNT_MAX=1000
    LOCK_COUNT_FINAL=1000
    LOCK_COUNT_RISE_EVENTS=22
    LOCK_COUNT_FALL_EVENTS=22
    ERROR_BAND_EXIT_EVENTS=463
    ACTUATOR_HUNT_OBSERVED=YES
    HELPER_DYNAMICS=UNDERDAMPED_OR_OVERAGGRESSIVE

    NORMAL_REQ_DELTA_OBSERVED=10229
    NORMAL_COMPLETED_DELTA=10229
    FINC_DELTA=5103
    FDEC_DELTA=5126
    DCO_STEP_DELTA=31787
    BOOTSTRAP_COMPLETED_FINAL=3388
    BOOTSTRAP_DONE_FINAL=1

    HELPER_LOCKED_SEEN=3351
    HELPER_LOCKED_FINAL=1
    FIRST_HELPER_LOCK_SAMPLE=2
    MAIN_ENABLED_FINAL=1
    MAIN_FREQ_LOCKED_FINAL=1
    MAIN_PHASE_LOCKED_FINAL=1
    MAIN_LOCKED_FINAL=1
    PSTAT_LOCKED_FINAL=1

    FULL_CHAIN_MAX_SECONDS=35.998
    FULL_CHAIN_300S=0
    STEP5_CHAIN_RESULT=NOT_COMPLETE
    SPLL_DELOCK_COUNT_FIRST=1
    SPLL_DELOCK_COUNT_MAX=250
    SPLL_DELOCK_COUNT_FINAL=1

    RESET_BOOT_GENERATION_DELTA=0
    RESET_CPU_DELTA=0
    RESET_WR_CORE_DELTA=0
    RESET_SI_CONFIG_DELTA=0
    MEASUREMENT_COHERENCE=PASS
    POSITION_ACCOUNTING=FAIL
    RESET_STABLE=PASS

## Interpretation

3388 明顯優於 3372：

- Helper 平均誤差已接近零，且不再碰到 high/low rail。
- NORMAL_REQ_DELTA 與 NORMAL_COMPLETED_DELTA 一致，表示 normal DCO request 有被完成。
- Main downstream path 能啟動，並在觀測結束時保持各 lock bits 為 1。
- 不需要用 reset 或 upstream workaround 解釋結果；四個 reset delta 都是 0。

但仍不能判定 PASS：

- 3600 個 100 ms snapshots 中，完整 chain 最長只有 35.998 s，遠小於 300 秒。
- Helper lock 有 22 次 rise 與 22 次 fall，error band exit 有 463 次。
- Helper 被判定為 UNDERDAMPED_OR_OVERAGGRESSIVE，與 hunting 一致。
- SPLL_DELOCK_COUNT_MAX=250，表示過程中存在明顯的 lock/delock 活動。
- POSITION_ACCOUNTING=FAIL；雖然底層 DCO lower-bound 與 transaction invariants 通過，仍需在宣告 Step 5 前釐清此觀測一致性問題。

因此，FREQ_ERROR_MEAN 接近零、最後一個 snapshot 全部 lock bits 為 1，都不足以取代持續 300 秒的證據。

## 原始資料

- Raw archive：EXP-WRPC-STEP5-HPLL-BOOTSTRAP-3388-CALCULATED-ZERO-CROSSING-20260912-raw.tgz
- Raw archive SHA256：b51e211aa9b8f7c4511022371f771a7a72bdc4050aa6b710381815d23cb38a86
- 同目錄 raw/ 保存 build、program、preflight 與 coherent observer logs。

## 下一輪

保留 bootstrap=3388，只對控制動態做一個 isolated A/B。優先測試小幅增加 HPLL normal transaction cooldown（例如 16 loads），以降低目前無 cooldown 時的 actuator hunting；不要再調大 lock threshold，也不要把最後 lock bits 當成 PASS。

下一輪必須重新 build、program，並以相同 coherent observer 重新確認：

1. Helper 不碰 rail；
2. lock/delock rise/fall 顯著下降；
3. POSITION_ACCOUNTING 回到 PASS；
4. 完整 chain 達成 300 秒；
5. reset deltas 維持 0。

在上述條件全部成立前，Step 5 維持 NOT COMPLETE。
