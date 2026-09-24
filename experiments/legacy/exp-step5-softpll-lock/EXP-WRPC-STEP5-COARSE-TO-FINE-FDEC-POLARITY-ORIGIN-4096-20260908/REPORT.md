# EXP-WRPC-STEP5-COARSE-TO-FINE-FDEC-POLARITY-ORIGIN-4096-20260908

## 結論

本輪依 `Astra建議.md` 完成一次 coarse-to-fine 實體驗證。保留 page/mask
修正與 4096-step FDEC bootstrap，將 normal HPLL tracker 的 target-to-actuator
mapping 反向，並把 bootstrap 視為 physical origin、排除在 fine-loop applied
coordinate 之外。

硬體證明 normal tracker 確實送出並完成 4095 筆 normal transaction，且 position
與 transaction accounting 通過；但是 Helper 沒有進入 lock，`PSTAT.locked` 也仍為
0。因此本輪不是 Step5 pass。

```text
STEP1_TO_STEP3 = PASS
STEP4B = PASS
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
STEP5 = NOT_PASS
STEP5_RESULT = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

## 版本與唯一變因

```text
branch = exp/step5-softpll-lock
source_commit = a0f232aed39cb674d84e99e705344681a9aabc9e
bootstrap_steps = 4096
bootstrap_direction = FDEC (STEP5_BOOTSTRAP_REVERSE=0)
code_per_physical_step = 16
normal_hpll_tracker = 1
```

本輪 source 變更只有 HPLL fine tracker 的方向與座標語意：

- normal target mapping 改為高 target code → FDEC；
- fine-loop applied coordinate 對 FINC/FDEC 的更新方向同步反向；
- bootstrap/forced completion 不再灌入 fine-loop applied position。

沒有修改 PI、lock threshold、DMTD、PTP、PHY 或 reset policy。

## Build、program 與 preflight

```text
SIMULATION_RC = 0
FIRMWARE_MASTER_RC = 0
FIRMWARE_SLAVE_RC = 0
COMPILE_MASTER_RC = 0
COMPILE_SLAVE_RC = 0
PROGRAM_MASTER_RC = 0
PROGRAM_SLAVE_RC = 0
```

Quartus timing 仍為既有 `TIMING_CLOSED=NO` caveat。SOF SHA-256：

```text
MASTER = 2c5e3340138e94e312c50541d46b7ecc8b0d4e53b320c0d20dacac112d83d594
SLAVE  = 13aeeba3adf475b38c28b2f85f9a8b50a5cff115cb4c371c0f03e26eb08d4883
```

settled preflight 2：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

## 120-second coherent observer

1200 samples 的實際 elapsed window 為 146.237 秒；1199 個 coherent measurement
snapshots、1 個 rejected epoch snapshot。所有 measurement、position、transaction
與 DCO accounting 均通過，且觀測期間沒有新增 reset。

```text
SAMPLES = 1200
VALID_FRAMES = 1107
INVALID_FRAMES = 93
WINDOW_SECONDS = 146.237
POST_BOOTSTRAP_BASELINE_SAMPLE = 1
BOOTSTRAP_COMPLETED_FINAL = 4096
BOOTSTRAP_DONE_FINAL = 1
FORCED_COMPLETED_FINAL = 4096
NORMAL_REQ_DELTA_OBSERVED = 4095
NORMAL_COMPLETED_DELTA = 4095
FINC_DELTA = 4095
FDEC_DELTA = 0
DCO_STEP_DELTA = 4095
TARGET_FIRST = 65531
APPLIED_FIRST = 65525
TARGET_FINAL = 5
APPLIED_FINAL = 5
EXPECTED_APPLIED_ABSOLUTE = 5
POSITION_ACCOUNTING = PASS
MEASUREMENT_COHERENCE = PASS
RESET_STABLE = PASS
```

這輪的直接硬體結果是：bootstrap 後先看到 `TARGET=65531, APPLIED=65525`，之後
normal tracker 完成 4095 筆 FINC；觀測末端為 `TARGET=5, APPLIED=5`。因此 mapping
修改確實改變了 downstream transaction 行為，但 target code 在 16-bit 邊界附近
的變化顯示它不能直接被解讀成「已知的絕對 physical DAC position」。

## Helper 與 lock 結果

```text
FREQ_ERROR_MEAN = -2229.28690575
FREQ_ERROR_RMS = 2251.64959991
HELPER_ERROR_MEAN = 98707.2560467
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 0.827356130108
HIGH_RAIL_FRACTION = 0.170975813178
NO_RAIL_FRACTION = 0.00166805671393
HELPER_ERROR_FINAL = 150000
HELPER_OUTPUT_FINAL = 5
HELPER_LOCK_COUNT_MAX = 15
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_MAX_SECONDS = 0.000
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

`ERROR_BAND_EXIT_EVENTS=0`、`ACTUATOR_HUNT_OBSERVED=NO`，observer 將 dynamics
分類為 `STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT`。因此不能把短暫的 lock-count rise
誤判成 lock；Helper 仍主要落在 rail，Step5 的第一個可靠失敗邊界仍是
`HELPER_LOCK`。

## 判讀與下一步

本輪排除了「normal tracker 完全沒有送出 transaction」以及「只因 applied
position 沒有更新而停住」這兩種解釋；也確認 4096-step bootstrap 後的 coarse-to-fine
路徑會實際運作。但它沒有建立 target code 與 silicon 的絕對工作點契約，因為
target 在 `65531 → 5` 的邊界附近變動，而 final applied 也回到 5。

下一輪應先做一個受控的 target/applied contract 實驗：固定細調 target 或固定
細調 transaction 方向，讓 observer 能區分「PI target 產生器 wrap」與「實際
actuator 方向/範圍錯誤」。在 contract 未被證明前，不應再盲目增加 bootstrap
步數或調整 lock threshold。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

- [raw archive](raw/EXP-WRPC-STEP5-COARSE-TO-FINE-FDEC-POLARITY-ORIGIN-4096-20260908.tar.gz)
- [archive SHA-256](raw/EXP-WRPC-STEP5-COARSE-TO-FINE-FDEC-POLARITY-ORIGIN-4096-20260908.tar.gz.sha256)
- [closed-loop observer log](raw/closed-loop-120s.log)
- [preflight 2](raw/preflight-2.log)
