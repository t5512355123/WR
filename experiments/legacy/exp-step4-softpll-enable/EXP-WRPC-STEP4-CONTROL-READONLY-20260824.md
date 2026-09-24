# EXP-WRPC-STEP4-CONTROL-READONLY-20260824

## 實驗識別

- 日期：2026-08-24
- 實驗名稱：control image 的 Step 2/3 barrier 與 Step 4 T0 唯讀觀測
- Tcl source branch：`exp/step4-softpll-enable`
- Tcl source commit：`cb5f2f3070bb62d9af706be1360d0461fefcecda`
- pain checkout：`cb5f2f3`
- Quartus：17.0.0 Build 595
- 實驗性質：read-only；本輪沒有 firmware build、Quartus compile 或 FPGA program

## 目的

在不改變硬體的情況下，確認 timeout 修正後的 focused regression 能完成，並重新觀察 control image 的 Step 4 第一個無活動邊界。

## 執行設定

```text
read_wr_handshake_focused.tcl 20 500 25
read_step4_startup_focused.tcl 10 500 events
```

`25` 是每次 mailbox transaction 的最大 poll 次數；無效讀值仍會依既有 validation/retry 規則處理。

## 原始證據

- `raw/EXP-WRPC-READONLY-REGRESSION-20260824/wr_handshake_focused_20x500_cb5f2f3.log`
- `raw/EXP-WRPC-STEP4-CONTROL-20260824/step4_t0_cb5f2f3.log`

兩個 Tcl 均回報 `Evaluation of Tcl script ... was successful`、`0 errors, 0 warnings`。

## Step 2 / Step 3 結果

### Master：DE5 [1-11.1]

- valid samples：20/20，invalid：0
- `MAC=02:00:22:33:44:01`
- `MODE=2`、`PTP=6`
- PTP RX、MiniNIC TX/RX 持續增加，`RXERR=0`
- `STEP2_REGRESSION=PASS`
- Step 3：Master 不適用

### Slave：DE5 [1-11.2]

- valid samples：20/20，invalid：0
- `MAC=02:00:22:33:44:02`
- `MODE=3`、`PTP=9`
- `FOREIGN_META=1/0`、parent WR/calibrated flags=1/0/1
- RX `0x1001`、TX `0x1000`、`LOCK_ENABLE=4`
- PTP RX、MiniNIC TX/RX 持續增加，`RXERR=0`
- `STEP2_REGRESSION=PASS`
- `STEP3_REGRESSION=PASS`
- live state 讀值為 `WRS_IDLE`；focused script 將其保留為 `STATE_EVIDENCE=READ_INCONSISTENT`，沒有覆寫已成立的 signaling evidence

## Step 4 T0 結果

兩板都觀察到：

- DMTD native clock 約 125 MHz 且持續活動
- REF/FB D0 transition 持續增加，約為 DMTD edge 的 0.99～1.00 倍
- REF/FB accepted event：`delta=0`
- DMTD event、tag pending/grant/valid、TRR write、IRQ、helper update：全部 `delta=0`
- `STEP4_EVENT_BOUNDARY=DMTD_SAMPLED_TRANSITION_TO_DEGLITCH_ACCEPT`

本次 T0 的 `D0 stable-hit` 欄位受到既有 CDC/readback classification 影響，部分列標為 `INVALID`；但 accepted event 與下游 counters 的全零結果在兩板均一致，不能因此宣稱 Step 4 已通過。

## Provenance 限制

本輪沒有重新產生或燒錄 SOF，因此這是「以 cb5f2f3 Tcl 讀取現有板上 image」的唯讀觀測。實際板上 SOF 必須追溯到先前有完整 MIF/SOF hash 的硬體實驗，不能把本輪 source commit 當成 fresh SOF provenance。

## 結論

```text
STEP1_REGRESSION = PASS（由 dashboard / focused evidence 支持）
STEP2_REGRESSION = PASS（20/20 accepted samples）
STEP3_REGRESSION = PASS（Slave 20/20 signaling evidence）
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_PASS
```

目前最強的 read-only evidence 仍是：DMTD input/first sampler 活動正常，但沒有形成可被 deglitch 接受的事件，因此事件鏈沒有進入 tag、TRR、IRQ 或 helper。

## 下一步

從本 control source 建立 fresh 的 DIVIDE-ONLY A/B：

```text
g_reverse_dmtds = false（保持）
g_divide_input_by_2 = true（control）
g_divide_input_by_2 = false（B 的唯一 functional 變因）
```

B 必須先經過 fresh firmware、clean Quartus build、雙板 program 與 20～30 samples Step 2/3 barrier；只有 barrier PASS 才能量 Step 4 T0/T1。
