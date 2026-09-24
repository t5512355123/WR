# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-5632-PLUS-64-MAIN-ABSOLUTE-TARGET-20260908

## 結論

本輪以目前 page/mask isolation、Main absolute target/applied tracker 與
HPLL normal tracker 版本，測試 Slave `bootstrap=5632`、HPLL `64 code/physical
step`。Step1–3 與 Step4B 在有效的第二次 preflight 通過，但 Step5 沒有鎖定。

```text
SOURCE_COMMIT = c65fc9296fedc2ed149ade97630ecaded5666d3a
STEP1_TO_STEP3 = PASS (preflight 2)
STEP4B = PASS (preflight 2)
STEP5 = NOT_PASS
STEP5_RESULT = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

## 唯一功能變因

相較上一輪，只把 Slave 的 coarse bootstrap 由 `6272` 改回 `5632`；保留
HPLL tracker `64 code/physical step`、Main DPLL absolute tracker `16
code/physical step`、四筆 page/mask runtime sequence、PI、lock detector、DMTD、
PTP/PHY 與 reset policy。

```text
STEP5_BOOTSTRAP_STEPS = 5632
HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 64
DPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 16
```

## 編譯與燒錄

Pain 已從 GitHub 拉取 `c65fc92`。Master/Slave firmware 與完整 Quartus fit 均
成功，兩張板子以 Slave→Master 順序 programming 成功且 0 errors；timing 仍未
closed。

```text
MASTER_SOF_SHA256 = ef80cf0b71bf168a51f21067d6ddb7c25d7ed20a70c7bf3e3f86987b6b336cf9
SLAVE_SOF_SHA256  = 2da501f4c783605d007083a49b5909a9e1a39c31c7c504266f368c9edb458be6
TIMING_CLOSED = NO
PROGRAM_ORDER = SLAVE_THEN_MASTER
```

## Upstream gate

第一次 preflight 的 Slave PTP 尚在 `UNCALIBRATED`，因此不採用其 Step4B 結果。
等待後的 preflight 2 是有效窗口：

```text
Master core_tm_link_up/core_link_ok = 1/1
Slave  core_tm_link_up/core_link_ok = 1/1
Master PTP = MASTER, PTP_RX/PTP_TX delta > 0
Slave  PTP = SLAVE, PTP_RX/PTP_TX delta > 0
Slave  WR_RX_SIGNAL = LOCK
Slave  LOCK_ENABLE_COUNT = 4
Slave  SPLL_INIT_COUNT = 1
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP5_RESULT = NEVER_LOCKED
```

## 1200-sample coherent Step5 observation

正式 observer 取得 1200 個 coherent measurement snapshots，總觀測時間約
135.6 秒。measurement、position、transaction、DCO 與 reset accounting 均
通過；這表示本輪的失敗不是 JTAG 讀取不一致或 runtime transaction 遺失。

```text
COHERENT_MEASUREMENT_SNAPSHOTS = 1200
REJECTED_EPOCH_SNAPSHOTS = 0
REJECTED_ACCOUNTING_CANDIDATES = 0
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_SNAPSHOTS = 1199
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

Bootstrap 與 HPLL normal tracker 都確實完成交易：

```text
BOOTSTRAP_COMPLETED_FINAL = 5632
BOOTSTRAP_DONE_FINAL = 1
TARGET_FINAL = 65531
APPLIED_FINAL = 65477
EXPECTED_APPLIED_ABSOLUTE = 65477
NORMAL_REQ_DELTA_OBSERVED = 1023
NORMAL_COMPLETED_DELTA = 1023
FINC_DELTA = 0
FDEC_DELTA = 1023
DCO_STEP_DELTA = 1023
```

## Helper 結果

```text
FREQ_ERROR_MEAN = -2476.79166667
FREQ_ERROR_RMS = 2478.84788528
FREQ_ERROR_MIN = -2630
FREQ_ERROR_MAX = -2374
HELPER_ERROR_MEAN = 33750.0
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
HELPER_OUTPUT_FINAL = 65531
LOW_RAIL_FRACTION = 0.6125
HIGH_RAIL_FRACTION = 0.385833333333
NO_RAIL_FRACTION = 0.00166666667
LOCK_COUNT_MAX = 1
LOCK_COUNT_FINAL = 1
LOCK_COUNT_RISE_EVENTS = 1
LOCK_COUNT_FALL_EVENTS = 0
ERROR_BAND_EXIT_EVENTS = 0
HELPER_DYNAMICS = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
SPLL_DELOCK_COUNT_MAX = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

時間序列顯示 Helper 先維持低 rail `5`，約在觀測中段跨過 phase error 零點後
切到高 rail `65531`；切換後約 55 秒仍維持高 rail，而 frequency error 始終約
`-2.5k`，沒有進入 `|helper_error| <= 200` 的鎖定帶。這不是單純 bootstrap
數值未完成，也不是 tracker 沒有動；它指向目前 Helper PI 與實際 HPLL
致動器工作方向/可用範圍仍未閉合。

## 判定與下一步

本輪不能宣稱 Step5 PASS，也不能 merge。Astra 建議的下一步不應再盲掃
bootstrap/HPLL code，而是進入 A4 的 isolated plant identification：在不讓
Helper PI 繼續累積的條件下，對 HPLL 的 FINC 與 FDEC 各做受控、短時間的實體
階躍，量測 coherent `FREQ_ERROR` 的方向與斜率，並以 Helper PI trace 同時
確認 `x / integrator / unclamped output / clamp side`。這能直接判斷：

1. HPLL A/B polarity 是否與目前 normal tracker 假設一致；
2. HPLL 物理範圍是否足以跨過目前約 `-2.5k` 的頻率誤差；
3. 是否是 PI 符號/量化而非 bootstrap operating point 造成 rail saturation。

只有在這個 plant sign/authority 證據成立後，才進行一次最小幅度的 PI 修正或
工作點變更，再回到完整 Step5 lock gate。若兩個方向都不能改善 frequency
error，應停止 PI 掃描，改查 SI5340 N1/N0 實體輸出與板級 clock routing。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

本資料夾 `raw/` 保存：

- `preflight-1.log`、`preflight-2.log`
- `observer-coherent-1200.log`
- `program-slave.log`、`program-master.log`
- `build_info_jtag_master.txt`、`build_info_jtag_slave.txt`
- `compile-master.log`、`compile-slave.log`
- `sof-sha256.txt`
