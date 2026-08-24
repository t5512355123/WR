# EXP-WRPC-DASHBOARD-RETEST-20260824

## 實驗摘要

- Experiment ID：`EXP-WRPC-DASHBOARD-RETEST-20260824`
- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- Dashboard/JTAG commit：`5e5b5b4`
- 實驗類型：read-only dashboard reliability 與 Step 2/3 regression retest
- 是否重新 compile：否
- 是否重新 program FPGA：否
- 本次使用的板上硬體：前一輪 `7cda07f` fresh SOF，未被本輪替換

## 本輪唯一修改

只修改 `scripts/jtag/read_wb_runtime.tcl`：

1. `INVALID` mailbox/status read 顯示為 `[invalid]`，不再與普通 `[info]` 混淆。
2. `WDIAGS_RXERR delta>0` 會合併到 Step 2 summary，避免訊號列顯示 error、Step 2 卻顯示 pass。
3. 單次 dashboard snapshot 的 Step 2/3 非 PASS 統一輸出 regression `INVALID`，必須由 focused repeated sampling 才能宣稱 FAIL。
4. Step 1 仍可由 direct PHY probe 做直接 gate；Step 2/3 不把單次 mailbox snapshot 當成硬體失敗。

沒有修改 register address、Wishbone 行為、FPGA RTL、firmware、PTP、WR signaling 或 SoftPLL。

## Read-only 語法與 runtime 驗證

在 pain 使用 exact commit `5e5b5b4` checkout 後執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wb_runtime.tcl
```

結果：

- Quartus Prime SignalTap II：script evaluation successful
- errors：0
- warnings：0
- 沒有 program FPGA
- 沒有 Quartus compile

## Dashboard 結果

### Master DE5 [1-11.1]

- Step 1：pass
- Step 2：pass
- `MAC=02:00:22:33:44:01`
- `MODE=2 MASTER`
- `PTP=6 MASTER`
- PTP RX/TX、MiniNIC TX/RX delta 均大於 0
- RXERR delta=0

### Slave DE5 [1-11.2]

- Step 1：pass
- Step 2：invalid
- Step 3：invalid
- `MAC=02:00:22:33:44:02`
- `MODE=3 SLAVE`
- 本次 snapshot 的 `WDIAGS_PTP=6 MASTER`，預期為 `9 SLAVE`
- PTP RX/TX、MiniNIC TX/RX delta 有活動
- `RXERR delta=8`，預期為 0
- Foreign Master `0/255`，預期 `1/0`
- `parentIsWRnode=0`、`parentCalibrated=0`
- WR state `WRS_IDLE`，並標示 `READ_INCONSISTENT`
- Step 4：error；DMTD、tag、TRR、TRR POP、IRQ、helper update delta 均為 0

dashboard summary 現在已與 signal line 一致，沒有再出現「欄位 error、Step 2 pass」的矛盾。

## Focused Step 2/3 regression

執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wr_handshake_focused.tcl 20 500 25
```

### Master

```text
valid_samples=20
invalid_samples=0
counter_decreased=0
PTP_TX_DELTA=39
STEP2_REGRESSION=PASS
```

20 筆 accepted samples 都維持 `MODE=2`、`PTP=6`、正確 MAC、Foreign=1/0、RXERR=0。

### Slave

```text
valid_samples=8
invalid_samples=12
counter_decreased=0
PTP_TX_DELTA=6
STEP2_REGRESSION=FAIL
STEP3_REGRESSION=FAIL
STATE_EVIDENCE=READ_INCONSISTENT
```

8 筆 accepted samples 一致觀察到：

- `MODE=3`
- `PTP=4 LISTENING`
- `FOREIGN=0/255`
- `parent=0/0/0`
- `local_state=0`、`next_state=0`
- `LOCK_ENABLE=16`
- `RXERR` 持續由約 1053 增加到 1067

另有 12 筆 mailbox/status read 被 validation reject；這些 invalid samples 不納入 accepted counter 判定，也不單獨當成硬體 FAIL。

## Regression barrier 結果

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = INVALID
STEP3_REGRESSION = INVALID
STEP4_ALLOWED    = NO
```

判定理由：Master 通過；Slave 的 accepted samples 已有一致的功能異常證據，但未達 `20/20 valid`，且存在 12 筆 invalid JTAG samples。因此正式 gate 以 `INVALID/RETEST` 保守標示，不把 invalid mailbox read 偽裝成硬體失敗。

## Failure classification

- JTAG/DASHBOARD_MEASUREMENT_FAILURE：已確認存在，包含 12/20 invalid focused samples，以及先前 dashboard aggregation 誤判；本輪已修正 aggregation。
- HARDWARE/FIRMWARE FAILURE：Slave accepted samples 中 `PTP=4`、Foreign=0/255、state idle、RXERR 持續增加，對功能 regression 提供實質支持；但因 accepted coverage 未達 20/20，仍不宣稱已完全排除 measurement contribution。

## Conclusion

這一輪成功修正了 dashboard 的誤判與 invalid 顯示，但沒有恢復 Slave 的 Step 2/3 regression。Step 4 仍被 barrier 阻擋，沒有開始任何 Step 4 functional experiment。

## Next Step

按照 reviewer 建議，以已知成功的 `7dd298bb` / `48ba8b1` functional tree 與 current tree 做 source-only delta isolation；在完成新的 source recovery、fresh build/program 與 20/20 accepted Step 2/3 gate 前，不進入 Step 4。下一輪若要燒錄，必須另立 commit、保存 MIF/SOF/provenance、program log、JTAG raw log 與本資料夾內的實驗紀錄。

