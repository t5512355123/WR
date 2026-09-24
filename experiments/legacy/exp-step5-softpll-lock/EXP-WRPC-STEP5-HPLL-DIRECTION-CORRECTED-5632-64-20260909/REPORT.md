# EXP-WRPC-STEP5-HPLL-DIRECTION-CORRECTED-5632-64-20260909

## 結論

本輪已成功編譯、燒錄並通過 upstream gate，但正式 Step5 observer 發現
Slave top-level 仍設定 `ENABLE_STEP5_HPLL_PLANT_TEST=1`。因此 normal HPLL
tracker 被刻意抑制，`735abce` 的方向修正沒有被執行；本輪是設定錯誤的
negative control，不能用來判定方向修正有效或無效。

```text
SOURCE_COMMIT = 735abce09a10b07aa2befeda5b7967323dc09a98
STEP1_TO_STEP3 = PASS (preflight 2)
STEP4B = PASS (preflight 2)
CONFIGURATION_VALID_FOR_CLOSED_LOOP = NO
DIRECTION_FIX_EXERCISED = NO
STEP5 = NOT_APPLICABLE
MERGE_APPROVED = NO
```

## 編譯與燒錄

Pain 已從 GitHub 拉取 `735abce`。Master/Slave firmware 與完整 Quartus fit
均成功，兩張板子 programming 成功且 0 errors；timing 仍未 closed。

```text
MASTER_SOF_SHA256 = 5b70df093b3688819db5abaa64f68fd419a6c70090e88444207b8a898389e111
SLAVE_SOF_SHA256  = e65677f12ec8774a284884fa3b4eb04b9cd0e20f5e6c3574b12a97edf31cce1a
TIMING_CLOSED = NO
PROGRAM_ORDER = MASTER_THEN_SLAVE
```

## Upstream gate

第一次 preflight 的 Slave 還在 `UNCALIBRATED`；等待後的 preflight 2 是有效
窗口：

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
STEP4B_RESULT = PASS
```

## Observer 結果

1200 筆 coherent observer 本身成功，但它證明的是 bootstrap 後「沒有 normal
tracker」的狀態：

```text
COHERENT_MEASUREMENT_SNAPSHOTS = 1200
POSITION_SNAPSHOTS = 1200
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0

BOOTSTRAP_COMPLETED_FINAL = 5632
BOOTSTRAP_DONE_FINAL = 1
TARGET_FINAL = 5
APPLIED_FINAL = 5
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
FINC_DELTA = 0
FDEC_DELTA = 0
DCO_STEP_DELTA = 0

FREQ_ERROR_MEAN = -2399.01916667
FREQ_ERROR_RMS = 2399.19320971
HELPER_ERROR_MEAN = 75000.0
HELPER_OUTPUT_FINAL = 5
LOW_RAIL_FRACTION = 0.7475
HIGH_RAIL_FRACTION = 0.25
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

這些資料不能拿來否定 `735abce`：`NORMAL_REQ_DELTA=0` 已直接證明方向修正
沒有進入實際 runtime path。

## 判定與下一步

本輪不宣稱 Step5 PASS，也不 merge。下一輪只做設定修正：

```text
ENABLE_STEP5_HPLL_PLANT_TEST => 0 (Slave)
```

保留 `735abce` 的 normal HPLL direction mapping、virtual position accounting、
bootstrap=5632 與 HPLL step=64，重新完整編譯、燒錄與 observer。只有在
`NORMAL_REQ_DELTA>0` 且 Helper output 離開 rail、`HELPER_LOCKED` 持續成立時，
才進行 Step5 PASS 判定。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

本資料夾 `raw/` 保存：

- `preflight-1.log`、`preflight-2.log`
- `observer-coherent-1200.log`
- `program-master.log`、`program-slave.log`
- `compile-master.log`、`compile-slave.log`
- `firmware-master.log`、`firmware-slave.log`
- `sof-sha256.txt`
