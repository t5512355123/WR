# 實驗紀錄：Step 4 JTAG bounded-group measurement reliability

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-STEP4-JTAG-BOUNDED-20260823`
- 日期：2026-08-23（Asia/Taipei）
- 分支：`exp/step4-softpll-enable`
- Git commit：`64341ca1785bbcf606cb32fa6129bd80b993662a`
- pain checkout：detached `64341ca`

## 目的

修正 Step 4 focused Tcl 量測程式的可靠性，讓單一 Wishbone mailbox timeout 不會讓整支 script 卡住數分鐘，也不會把未完成的量測誤當成 SoftPLL/硬體失敗。

## 唯一修改變因

只修改 `scripts/jtag/read_step4_startup_focused.tcl`：

1. 改為 sample-major 的 bounded register groups。
2. 每個 group 明確輸出 `VALID`、`TIMEOUT`、`INVALID` 或 `PARTIAL`。
3. `wb_read_once`、mailbox sync 與 validation retry 加入 read-only exception handling。
4. 沒有修改 register address、判定規則、Wishbone control write、TRR read、RTL、firmware 或 SoftPLL 行為。

## 硬體與 provenance

- Quartus compile：未執行。
- FPGA program：未執行。
- 本輪沒有新的 MIF/SOF/checksum 或 programmer log。
- 板上 image 沿用前一輪 `0c3fbea` fresh SOF；其完整 provenance 仍見：
  `EXP-WRPC-STEP4-QUALIFICATION-ABORT-20260823.md`

## 原始 log

位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-JTAG-BOUNDED-20260823/`

- `step4_bounded.log`
- `step23_bounded.log`
- `dashboard_bounded.log`

## 執行結果

### Step 4 focused measurement

執行：

```text
quartus_stp -t read_step4_startup_focused.tcl 10 500 events
```

結果：

- 兩板均正常結束。
- Quartus STP：`Evaluation of Tcl script ... successful`、0 errors、0 warnings。
- 四個 group：`DMTD_BOUNDARY=VALID`、`TAG_ARBITRATION=VALID`、`DOWNSTREAM=VALID`、`EVENT_TIMING=VALID`。
- 所有 series 均 `timeout=0`、`invalid=0`。
- 執行時間約 41 秒，不再出現前一輪超過三分鐘的未完成狀態。

觀測值：

- Master sampled reference/feedback delta > 0，accept delta=0。
- Slave sampled reference/feedback delta > 0，accept delta=0。
- 兩板 DMTD event、tag pending/grant/valid、TRR、IRQ、state transition、helper update 均沒有 sustained delta。
- `STEP4_EVENT_BOUNDARY` 兩板均為 `DMTD_DEGLITCH_ACCEPT`。

### Step 2 / Step 3 regression

`read_wr_handshake_focused.tcl 20 250`：

- Master：valid=20、invalid=0、Step 2 PASS、`PTP_TX_DELTA=45`。
- Slave：valid=20、invalid=0、Step 2 PASS、Step 3 PASS、`PTP_TX_DELTA=8`。
- Slave：`FOREIGN=1/0`、parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`、signal_good=20、signal_bad=0。

### Dashboard

`read_wb_runtime.tcl` 完整結束且回報 successful、0 errors、0 warnings。兩板 Step 1/2 PASS，Slave Step 3 PASS；Slave Step 4 顯示 DMTD event 與下游 counters 沒有 delta。短窗口 Slave `PTP_TX delta=0` 只列資訊，沒有使 Step 2 fail。

## 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
JTAG_MEASUREMENT_PIPELINE = PASS
```

本輪成功修復量測管線；現在可以把 `sampled transition > 0`、`accept/event/tag/TRR/IRQ/helper = 0` 當作完整 read-only Step 4 evidence。這仍然不能單獨證明 SoftPLL/PHY/clock 的根因，只能把第一個已觀測 inactive boundary 保持在 `clk_sampled -> deglitch qualification/accept`。

## 下一步

進行下一個獨立 hardware diagnostic round：新增 REF/FB 32-bit non-saturating HIGH qualification-abort cumulative counters，直接觀察既有 `GOT_EDGE && clk_sampled=0` 的 abort condition。不得修改 threshold、FSM、DDMTD polarity、SoftPLL algorithm、WR signaling、PI、lock threshold、DCO、SI5340 或 PHY。
