# EXP-WRPC-STEP5-MAIN-ABSOLUTE-TARGET-FDEC5632-20260908

## 結論

本輪驗證了 Main 的 absolute target/applied tracker，並以 I²C provenance
observer 核對 runtime 四筆交易。Step4B 在反向 recovery programming 後通過，
但 Helper 仍固定在低 rail，Main 沒有啟用，因此 Step5 未完成。

```text
SOURCE_COMMIT = 84006533fac04993642b736d7cf92dea3c7a8449
STEP1_TO_STEP3 = PASS (reverse-recovery preflight 2)
STEP4B = PASS
MAIN_ABSOLUTE_TARGET_ACCOUNTING = PASS
I2C_PROVENANCE = PASS (FPGA-side command/ACK evidence)
STEP5 = NOT_PASS
STEP5_RESULT = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

## 唯一功能修改

保留 HPLL 的 unsigned absolute target 語意與既有 page/mask runtime path，新增
Main DPLL 的獨立 absolute target/applied position tracker：

- target 使用 Main PI 的 16-bit unsigned DAC code；
- applied 從 SI5340 Main 的 midscale `32768` 建立獨立座標；
- 每筆成功完成的 DPLL 四筆 I²C transaction 才將 applied 移動一個 `16` code
  physical step；
- target 不再改變時，仍會持續排空 residual；
- Main 與 Helper 的 pending、applied、completion accounting 分離。

沒有修改 PI gain、lock threshold、DMTD、PTP/PHY、reset policy 或 SoftPLL
event chain。

## Build、program 與 recovery

離線 page-aware contract test 通過。Master/Slave firmware rebuild、Quartus
full compile 與兩張板子的 programming 均成功；timing 仍未 closed。

```text
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
MASTER_SOF_SHA256 = 0d46fd7bfe54f993ddf2c128ba695b1f38ceff4bc4f44e2fbc241907f0e60562
SLAVE_SOF_SHA256  = 4c6839e21624a06e0e47ec1158a2d05c623bce1cfd875284715f220f79a9dea1
TIMING_CLOSED = NO
```

實體斷電後第一次讀取沒有有效觀測核心，重新燒錄同一映像的
Master → Slave 順序仍未恢復 link。接著以不改映像的 Slave → Master 順序
重新配置，preflight 1 先恢復 Link 但 Slave 尚在 `UNCALIBRATED`；等待後的
preflight 2 才是正式有效窗口：

```text
Master core_tm_link_up/core_link_ok = 1/1
Slave  core_tm_link_up/core_link_ok = 1/1
Master PTP = MASTER, PTP_RX delta > 0
Slave  PTP = SLAVE, PTP_RX delta > 0
Slave  WR_RX_SIGNAL = LOCK
Slave  LOCK_ENABLE_COUNT = 4
Slave  SPLL_INIT_COUNT = 1
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
```

燒錄先後順序對 cold/warm recovery 的影響仍存在；這是啟動／校準問題，
不應誤判成這輪 Main tracker 的 Step5 failure。

## Main tracker coherent observation

使用 1200 個 coherent snapshots，實際 elapsed window 約 137.1 秒。觀測期間
沒有 accounting、position 或 reset 穩定性失敗：

```text
COHERENT_MEASUREMENT_SNAPSHOTS = 1200
POSITION_SNAPSHOTS = 1197
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

Main position 與 transaction 結果為：

```text
TARGET_FINAL = 5
APPLIED_FINAL = 5
EXPECTED_APPLIED_ABSOLUTE = 5
NORMAL_REQ_DELTA_OBSERVED = 1440
NORMAL_COMPLETED_DELTA = 1442
FINC_DELTA = 1442
FDEC_DELTA = 0
DCO_STEP_DELTA = 1442
```

這證明 Main residual 會被繼續處理，且 completion 後才更新 applied；但這只
證明 FPGA-side tracker/transaction accounting，不能單獨證明 SI5340 輸出頻率
已達目標。

## I²C provenance observation

I²C observer 取得 1200 samples，正式窗口的命令 provenance 為：

```text
I2C_SEQ0 = address 0x01, data 0x03       (select page 3)
I2C_SEQ1 = address 0x39, data 0x0D       (HPLL/N1 mask)
I2C_SEQ2 = address 0x01, data 0x00       (restore page 0)
I2C_SEQ3 = address 0x1D, data 0x01       (FINC)
I2C_PHASE_SEEN = 0xF
I2C_ACK_ERROR = 0
I2C_DCO_ERROR = 0
NORMAL_TRANSACTION_ACCOUNTING = PASS
RESET_DELTAS = 0
```

有效 frame 為 1188、invalid frame 為 12；invalid snapshot 沒有被計入 Helper
統計。以上是 FPGA-side presented command 與 bus ACK evidence，不是 SI5340
register readback，也不是物理 frequency response 的證明。

## Helper、Main 與 Step5 判定

Coherent observer 的正式結果：

```text
HELPER_ERROR_MEAN = 150000.0
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
HELPER_OUTPUT_FINAL = 5
LOW_RAIL_FRACTION = 1.0
HIGH_RAIL_FRACTION = 0.0
HELPER_LOCK_COUNT_MAX = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
SPLL_DELOCK_COUNT_MAX = 5
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

因此目前最早失效邊界仍是 `HELPER_LOCK`。Main tracker 已排除「重複同一
target 只送一次 step」這個介面問題，但沒有解決 Helper 的 physical operating
point／控制方向／有效頻率響應問題。這輪不能宣稱 Step5 PASS，也不能 merge。

## 下一步

既有 I²C sequence 與 ACK evidence 已支持 page/mask command path，但尚缺
SI5340 silicon readback 或獨立頻率量測。下一輪優先測試歷史上最接近零誤差的
coarse-to-fine operating point：Slave `STEP5_BOOTSTRAP_STEPS=6272`、
`HPLL_TRACKER_CODE_PER_PHYSICAL_STEP=64`，保留本輪 Main tracker 與所有
provenance telemetry，並使用相同的 reverse recovery procedure。這是單一
HPLL control 變因，不與 PI 或 lock detector 同時修改。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

所有原始紀錄位於本資料夾的 `raw/`：

- `preflight-reverse-2.log`
- `observer-main-absolute-target-1200.log`
- `i2c-provenance-1200.log`
- `sof-sha256.txt`
- `contract.log`
- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`

另外保留各次 cold/recovery programming 與 preflight raw，供區分啟動恢復與
Step5 控制行為。
