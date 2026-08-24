# EXP-WRPC-STEP23-REGRESSION-READONLY-20260824

## 實驗識別

- 實驗日期：2026-08-24
- 實驗名稱：Step 2 / Step 3 唯讀回歸與 dashboard 可靠性確認
- 本機 branch：`exp/step4-softpll-enable`
- 本機 HEAD：`4d7eaffac1fa843f4c43d3c0783736b1a9386c09`
- pain checkout：detached `4d7eaffac1fa843f4c43d3c0783736b1a9386c09`
- 實驗性質：read-only JTAG；沒有 Quartus compile、沒有 program FPGA

## 目的

確認目前 dashboard 能否將兩片 DE5a 的 Step 1～Step 3 runtime 狀態完整輸出，並確認無效 mailbox 值不會被當成硬體失敗。另嘗試執行既有 focused regression script；若 script 沒有在合理時間完成，只記為診斷未完成，不把它解讀成硬體故障。

## 唯一操作變因

本輪沒有修改 RTL、firmware、MIF、PTP、WR signaling、SoftPLL、DDMTD、PHY、DCO 或 SI5340。只使用目前 branch 的既有 Tcl dashboard 與 focused read-only scripts。

## 執行設定

- Quartus：17.0.0 Build 595
- dashboard：`scripts/jtag/read_wb_runtime.tcl`
- focused Step 2/3 嘗試：
  - `read_step23_register_reliability.tcl 30 500 all`
  - `read_wr_handshake_focused.tcl 30 500`
- 兩個 focused command 都只讀取 JTAG probe / Wishbone mailbox，沒有寫入 control register。

## 原始證據

- dashboard 輸出：`raw/EXP-WRPC-READONLY-REGRESSION-20260824/read_wb_runtime_4d7eaff.log`
- 遠端 checkout 證據：該 raw log 開頭包含 `REMOTE_HEAD=4d7eaffac1fa843f4c43d3c0783736b1a9386c09`
- Tcl 結束訊息：`Evaluation of Tcl script ... was successful`、`0 errors, 0 warnings`
- pain 預存未追蹤檔案 `"\\"` 未修改、未刪除。

## Dashboard 結果

### Master：DE5 [1-11.1]

- Step 1 PHY / Link：pass
- Step 2 Endpoint / MiniNIC / PTP：pass
- MAC：`02:00:22:33:44:01`
- MODE：`2 MASTER`
- PTP：`6 MASTER`
- PTP/MiniNIC counter：PTP RX `Δ=12`、PTP TX `Δ=24`、MiniNIC TX `Δ=30`、MiniNIC RX `Δ=17`
- RXERR：`Δ=0`

### Slave：DE5 [1-11.2]

- Step 1 PHY / Link：pass
- Step 2 Endpoint / MiniNIC / PTP：pass
- Step 3 WR Handshake：pass
- MAC：`02:00:22:33:44:02`
- MODE：`3 SLAVE`
- PTP：`9 SLAVE`
- PTP/MiniNIC counter：PTP RX `Δ=20`、PTP TX `Δ=2`、MiniNIC TX `Δ=15`、MiniNIC RX `Δ=25`
- RXERR：`Δ=0`
- Foreign Master：`1/1`
- parentIsWRnode：`1`
- parentCalibrated：`1`
- WR RX：`LOCK count=1`
- WR TX：`SLAVE_PRESENT count=1`
- LOCK_ENABLE：`4`
- SoftPLL dashboard：RCER `1`，但 DMTD REF/FB、TAG、TRR、IRQ、HELPER 的短窗口 delta 均為 `0`，Step 4 顯示 `error`

## focused script 結果

兩個 focused script 在 30 samples / 500 ms 設定下沒有於本次工作階段的合理時間內返回輸出。為避免留下多個 JTAG session，已中止本次啟動的遠端 `quartus_stp` process；沒有重新開機、沒有燒錄、沒有編譯。這只能標記為：

```text
FOCUSED_SCRIPT_RESULT = INCOMPLETE / RETEST_REQUIRED
HARDWARE_FIRMWARE_FAILURE = NOT_ESTABLISHED
JTAG_SCRIPT_RELIABILITY = NEEDS_FOLLOW-UP
```

這次 focused script 未產生可接受的 sample series，因此沒有用它覆寫 dashboard 的 Step 2/3 結果，也沒有把逾時直接判成 Step 2/3 FAIL。

## 結論

本次 dashboard 的 read-only snapshot 支持：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS（dashboard snapshot；focused series 尚未完成）
STEP4_ALLOWED = CONDITIONAL / RETEST_REQUIRED
```

Step 4 尚未通過。現有證據只支持 Slave 已有 Step 2/3 的 endpoint、MiniNIC、PTP、foreign master 與 signaling 活動；不支持 DMTD accepted event、tag/TRR/IRQ/helper 已持續活動，也不支持 SoftPLL lock 或 `time_valid=1`。

## 下一步

1. 先修正或縮小 focused script 的讀取範圍與每次 mailbox transaction 的總等待時間，讓它在逾時時能輸出 `TIMEOUT/INVALID` 並正常結束。
2. 重新取得可完成的 Step 2/3 accepted time-series；在此之前不做 Step 4 functional A/B。
3. 若 focused regression 通過，再依單一變因規則進行下一個 Step 4 read-only 觀測。
