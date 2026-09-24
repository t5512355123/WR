# 實驗紀錄：Step 2/3 唯讀 regression barrier

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-STEP2-3-READONLY-20260823`
- 日期：2026-08-23（Asia/Taipei）
- 研究分支：`exp/step4-softpll-enable`
- Git commit：`c7c690bc5588a039c6fdf26606f9699ec182c9d9`
- pain checkout：detached `c7c690b`

## 本次想驗證什麼

重新建立 Step 2 / Step 3 的 read-only regression barrier，確認先前看到的 invalid mailbox value、counter delta=0 與 `WRS_IDLE` shadow 不會被 dashboard 誤判成硬體功能失敗。

本輪只允許：

- JTAG read-only script 執行
- dashboard / focused regression 輸出保存
- 實驗文件更新

本輪沒有修改 FPGA RTL、firmware、MIF、SoftPLL、PTP、WR signaling、PHY 或任何 Wishbone control register。

## 硬體與 provenance 邊界

- Quartus compile：未執行。
- FPGA program：未執行。
- 本輪沒有產生新的 MIF/SOF/checksum，也沒有新的 programmer log。
- 板上實際 image 沿用前一輪 `0c3fbea` fresh SOF；該 image 的 MIF/SOF hash、Quartus 版本與 programmer checksum 保存在：
  `EXP-WRPC-STEP4-QUALIFICATION-ABORT-20260823.md`
- 因此本紀錄只能宣稱「c7c690b scripts 對現有板上 image 的 read-only regression」，不能宣稱 fresh `c7c690b` hardware build 已通過。

## 執行項目

1. 在 pain 從 GitHub fetch 並 checkout exact `c7c690b`。
2. 執行 `read_wr_handshake_focused.tcl 20 250`，取得 20 個有效 samples。
3. 執行 `read_wb_runtime.tcl`，檢查 dashboard 是否完整輸出且無 Tcl exception。
4. 執行 `read_step4_startup_focused.tcl 10 500 events` 作為 read-only 觀察；該程序在後續 mailbox read 超時，停止並保存 partial log。

另外執行 `read_step23_register_reliability.tcl 10 500 all`。它的 Step 2 independent summary 通過；Slave 的 Step 3 independent summary 被該 broad script 標成 `INVALID`，原因是它對 `WR_FAILURE_DEBUG`/state shadow 採用較嚴格分類。這與 focused script 的 20 次 `STEP3_REGRESSION=PASS` 並存，因此本輪採 focused repeated evidence 作為 Step 3 gate，並把 broad-script disagreement 保留為 measurement/classification discrepancy。

## 原始 log

所有檔案位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP2-3-READONLY-20260823/`

- `step23_handshake_focused.log`
- `dashboard_readonly.log`
- `step23_register_reliability.log`
- `step4_startup_focused_partial.log`

## Step 2 結果

`read_wr_handshake_focused.tcl`：

- Master：`valid_samples=20`、`invalid_samples=0`、`counter_decreased=0`、`PTP_TX_DELTA=43`、`STEP2_REGRESSION=PASS`。
- Slave：`valid_samples=20`、`invalid_samples=0`、`counter_decreased=0`、`PTP_TX_DELTA=4`、`STEP2_REGRESSION=PASS`。
- Master：MAC=`02:00:22:33:44:01`、MODE=`2`、PTP=`6`，MiniNIC/PTP counter 有活動，RXERR=0。
- Slave：MAC=`02:00:22:33:44:02`、MODE=`3`、PTP=`9`，MiniNIC/PTP counter 有活動，RXERR=0。

dashboard 同時顯示兩板 Step 1 PASS 與 Step 2 PASS。這次沒有出現 `WDIAGS_PTP=0xA5A51330` 被當作合法 PTP state 的情況。

`read_step23_register_reliability.tcl` 的兩板 register series 都是 `valid=10/10`、`invalid=0`；Master 與 Slave 的 Step 2 independent summary 均為 PASS。該 script 對 Slave Step 3 顯示 INVALID，但 focused handshake script 的 source-backed repeated gate 顯示 PASS，故沒有把這個分類差異升格為硬體 failure。

## Step 3 結果

Slave 20 個 focused samples 均有效，並且：

- `FOREIGN=1/0`
- `parent=1/0/1`
- RX message=`0x1001`
- TX message=`0x1000`
- `LOCK_ENABLE=4`
- `signal_good=20`、`signal_bad=0`
- `STEP3_REGRESSION=PASS`

同時觀察到 `POST_STEP3_LOCK_STAGE=TIMEOUT`、`STATE_EVIDENCE=READ_INCONSISTENT`。這表示單一 current-state shadow 與其餘 handshake 證據不一致；由於 20 次有效樣本的 handshake 欄位持續成立，本輪不把它直接改判為 Step 3 failure。

## Step 4 read-only 觀察

`read_step4_startup_focused.tcl 10 500 events` 的 partial log 顯示 Master 已完成：

- `DMTD_REF_SAMPLED` 有大幅增加
- `DMTD_FB_SAMPLED` 有大幅增加
- `DMTD_REF_ACCEPT`、`DMTD_FB_ACCEPT` delta=0
- `DMTD_REF_SEEN`、`DMTD_FB_SEEN` 讀值為 `0x0000FFFF`，delta=0
- `TAG_PENDING_COUNT`、`TAG_GRANT_COUNT`、`TAG_VALID_COUNT`、`TRR_WRITE_COUNT`、`IRQ_COUNT`、`HELPER_UPDATE_COUNT` 已讀到 delta=0 的部分

程序在後續 mailbox read 超過三分鐘沒有完成；已停止並保存 partial log。這一段只證明該次 Tcl 讀取沒有可靠完成，不能據此宣稱 Step 4 或硬體失敗。

## 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
HARDWARE/FIRMWARE_FAILURE = NOT_ESTABLISHED
JTAG/DASHBOARD_MEASUREMENT_ISSUE = PRESENT
```

本輪成功重新建立 Step 2 / Step 3 barrier；Step 4 可以進入下一個獨立研究循環，但本輪沒有做 Step 4 functional experiment，也沒有 fresh compile/program 證據。Step 4 下一步應先修正 focused Tcl 的 mailbox timeout/分組讀取策略，或在取得明確許可後再做單一觀測變因的 fresh build；不能把本輪 partial timeout 當成 SoftPLL 根因。

## 下一步

1. 保留 `c7c690b` 與本紀錄，不 merge main。
2. 先修 read-only Step 4 Tcl 的 timeout handling，讓每個 register group 能在單一 mailbox timeout 後安全結束並輸出完整 summary，不讓整個程序長時間卡住。
3. 後續若要新增 32-bit qualification abort counter，必須另開一輪明確的 source/build/program 實驗，並重新保存完整 MIF/SOF provenance；不得把它混入本輪 regression barrier。
