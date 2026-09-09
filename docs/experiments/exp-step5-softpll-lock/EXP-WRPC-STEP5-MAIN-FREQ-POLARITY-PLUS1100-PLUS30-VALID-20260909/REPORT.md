# EXP-WRPC-STEP5-MAIN-FREQ-POLARITY-PLUS1100-PLUS30-VALID-20260909

## 判定

本輪依指定流程完成 laptop push、Pain pull、Master/Slave firmware build、
Quartus full compile、燒錄與有效 runtime 觀測。第一次採 Master→Slave 載入
仍因啟動順序造成 link down；在不改變映像的前提下改採 Slave→Master 載入後，
取得有效的 Step1–4B upstream window。Main frequency polarity A/B 確實被執行，
頻率誤差由上一輪的千級單邊 rail 狀態縮小到零點附近，但尚未達到 Main lock。

```text
SOURCE_BRANCH = exp/step5-softpll-lock
SOURCE_HEAD = 998472d
FUNCTIONAL_CHANGE = b25e77d (Main PI polarity +1100/+30)
MASTER_SOF_SHA256 = 12c8ac912c53befa0e31638b6d4c9e0638d20a9f1523dd81b3605e3ad740dcd0
SLAVE_SOF_SHA256  = 9573f0bdcf797fa2f38a69a9de31640c9ff313ab6716379e4cce04bc43e0df6a
TIMING_CLOSED = NO
PROGRAM_ORDER_VALID_WINDOW = SLAVE_THEN_MASTER
STEP1_TO_STEP3 = PASS
STEP4B = PASS
STEP5 = NOT_COMPLETE
MERGE_APPROVED = NO
```

## 本輪設定

```text
Main PI: KP=+1100, KI=+30, SHIFT=12, BIAS=32768
Main frequency threshold=50, lock_samples=50
Helper threshold=2000, lock_samples=1000
Slave bootstrap=3360, reverse=1
HPLL code per physical step=64
DPLL code per physical step=16
HPLL cooldown=0
```

既有 page/mask sequence、absolute target/applied tracker、static-FSM completion
gate fix 與 Helper 方向修正均保留；本輪只變更 Main PI 的 polarity。

## Upstream recovery evidence

Master→Slave 初次載入的 preflight 顯示兩端 `core_link_ok=0`，Slave 停在
LISTENING，故該窗口不可用於 Step5。其後以同一組 SOF 重新採 Slave→Master
載入，取得有效窗口：

```text
Master core_tm_link_up/core_link_ok = 1/1
Slave  core_tm_link_up/core_link_ok = 1/1
Master PTP = MASTER, RX/TX deltas > 0
Slave  PTP = SLAVE, RX/TX deltas > 0
Slave  WR_RX_SIGNAL = LOCK
LOCK_ENABLE_COUNT = 4
SPLL_INIT_COUNT = 1
STEP1 = PASS
STEP2 = PASS
STEP3 = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
```

有效窗口中 DMTD、TAG、TRR write/pop、IRQ 與 Helper update 均增加；
`BOOT_GENERATION`、CPU reset、WR-core reset、SI-config drop 均無新增。

## Main frequency pre-lock observation

使用 600 筆 coherent observer samples，實際耗時約 108.81 秒：

```text
TRACE_VALID = 600
TRACE_UNIQUE = 58
TRACE_DEDUP_SKIPPED = 542
FRAME_VALID = 571
INVALID = 0
MEASUREMENT_FAILS = 0
RESET_STABLE = PASS
```

Main frequency error 統計如下。這裡的 `FREQ_ERROR` 是目前 SoftPLL 的 DMTD
內部誤差單位，不是外部頻率計的 Hz：

```text
FREQ_ERROR_MEAN = 12.7586206897
FREQ_ERROR_RMS = 104.2457300914
FREQ_ERROR_MIN = -142
FREQ_ERROR_MAX = 190
FREQ_ERROR_MAX_ABS = 190
FREQ_ERROR_FINAL = 137
FRACTION_ABS_FREQ_ERROR_LE_50 = 0.0
```

相較於上一輪 `KP=-1100, KI=-30` 的高 rail，方向翻轉後誤差已進入零點
附近；但誤差仍在約 ±100 等級的離散循環中，未形成 50-sample lock window。

PI / lock 結果：

```text
MAIN_ENABLED_FRACTION = 1.0
MAIN_FREQ_LOCK_COUNT_MAX_SEEN = 0
MAIN_FREQ_LOCKED_EVER = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_EVER = 0
MAIN_LOCKED_EVER = 0
PSTAT_LOCKED_FINAL = 0
HELPER_LOCKED_EVER = 1
HELPER_LOCKED_FINAL = 1
MAIN_PI_LOW_RAIL_FRACTION = 0.448275862069
MAIN_PI_HIGH_RAIL_FRACTION = 0.0
MAIN_PI_NO_RAIL_FRACTION = 0.551724137931
MAIN_PI_OUTPUT_FINAL = 5
MAIN_PI_CLAMP_SIDE_FINAL = -1
```

觀測軌跡顯示，正誤差時控制輸出落到低 rail，負誤差時短暫回到中間區域；
因此 polarity 已正確，但目前 `+1100/+30` 的迴路尺度／積分狀態仍造成
零點兩側的 limit-cycle 與低 rail wind-up。這不是 Step5 PASS，也不能以
放寬 threshold 取代實際收斂。

## 結論與下一輪

```text
MAIN_POLARITY_CORRECTED = SUPPORTED_BY_THIS_RUN
MAIN_FREQUENCY_LOCK = NOT_REACHED
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

下一輪只做一個可歸因的控制變因：保留正確 polarity，降低 Main PI 的控制
尺度並觀察是否能在零點附近保持中間輸出，而不是反覆撞 rail。優先測試
一組保守 operating point（例如 `KP=+150, KI=+1`），維持 threshold、
lock_samples、bootstrap、DCO page/mask 與 tracker 不變；先用 30–60 秒
有效窗口判斷誤差趨勢，再決定是否進入長時間 Step5 lock window。若仍在
rail，下一步應檢查 Main PI integrator reset/anti-windup 與 DPLL 實體
position，而不是繼續盲掃相鄰增益。

## Raw evidence

本資料夾 `raw/` 保存本輪 build、program、兩次 preflight 與 600 筆 observer
原始輸出；遠端 archive 位於 laptop `artifacts/`：

```text
EXP-WRPC-STEP5-MAIN-FREQ-POLARITY-PLUS1100-PLUS30-VALID-20260909-raw.tgz
SHA256 = 61c903f65e00c2dbf005cd5df594607771066deaaa394dc392cf5c94eed11443
```
