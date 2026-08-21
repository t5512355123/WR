# EXP-WRPC-STEP2-STEP3-READONLY-REGRESSION-20260821

## 實驗識別

- 日期：2026-08-21
- 實驗類型：JTAG read-only regression
- Git branch：`exp/step4-softpll-enable`
- Git HEAD：`6f97d07502015c7e8d5259bab3e59be71f78b998`
- 本次 commit：`修正 JTAG 讀值例外容錯`
- Quartus：Quartus Prime 17.0 Build 595
- 硬體操作：未燒錄 FPGA
- Quartus compile：未執行
- Merge main：未執行

本次只驗證 JTAG/Tcl 讀值可靠性與 Step 2/Step 3 regression gate。現場 FPGA 維持原本已燒錄的 bitstream；本次沒有取得新的 SOF，也沒有宣稱 current HEAD 已完成 fresh SOF hardware qualification。因此本紀錄是「目前硬體上的唯讀 runtime 證據」，不是新的 HEAD-to-SOF provenance 證明。

## 本次唯一修改

只修改下列 read-only Tcl：

- `scripts/jtag/read_wb_runtime.tcl`
- `scripts/jtag/read_wr_handshake_focused.tcl`
- `scripts/jtag/read_master_ptp_slave_parent_long.tcl`

修改內容只有：

1. JTAG API exception 轉成 `TIMEOUT`，讓單次 mailbox/direct probe 例外不會中止整個觀測序列。
2. 非 hexadecimal direct probe 轉成 `INVALID`。
3. Wishbone mailbox write/read timeout 保留為無效證據，不轉成數值 0。
4. 保留原有 critical register validation、retry、counter decrease handling 與 read-only 行為。

沒有修改 role switching、PTP、WR signaling、SoftPLL、DDMTD、PI gain、lock threshold、DCO、SI5340、PHY、RTL 或 firmware。

## 執行命令

pain 先從 GitHub checkout exact commit：

```text
git fetch origin
git checkout --detach 6f97d07502015c7e8d5259bab3e59be71f78b998
```

接著只執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wb_runtime.tcl

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wr_handshake_focused.tcl 30 500

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_master_ptp_slave_parent_long.tcl 30 500
```

三個 Tcl 的 Quartus STP exit code 都是 `0`，每個輸出也都出現：

```text
Info (23030): Evaluation of Tcl script ... was successful
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

## 證據檔案

| 檔案 | 內容 | SHA256 |
|---|---|---|
| `regression_dashboard_6f97d07_20260821.log` | 兩板 dashboard 摘要 | `2BAD2E37B4ED3ACF3C55E67FC45E84C35601ACBCE630BF0E2680F42582131381` |
| `regression_focused_6f97d07_20260821.log` | 兩板 30 samples、500 ms focused evidence | `2A10287A009127D2A212BAE31E4B0A08416FAE68DC6EECA9F8FD275B855F4DD5` |
| `regression_long_6f97d07_20260821.log` | 兩板 30 samples、500 ms long observation | `0156CCC8BB17FD6F4342520844B15AC47ACDD4AE6472CCD07C49C284408E0BD0` |

## Step 1：PHY / Link

| 板卡 | 結果 | 觀察 |
|---|---|---|
| Master `DE5 [1-11.1]` | PASS | dashboard 顯示 silicon interface、WR ready、timing link、link OK、RX/TX ready、RX lock-to-data 正常，encoding error 為 0 |
| Slave `DE5 [1-11.2]` | PASS | 同上，沒有被單次無效 mailbox 讀值判成 failure |

## Step 2：Endpoint / MiniNIC / PTP

### Master

- MAC：`02:00:22:33:44:01`
- `WDIAGS_MODE=2`
- `WDIAGS_PTP=6`
- focused valid samples：`30/30`
- invalid samples：`0`
- counter decrease：`0`
- focused `PTP_TX_DELTA=108`
- `WDIAGS_PTP_RX`、MiniNIC TX/RX 都持續增加
- RXERR 維持 0

### Slave

- MAC：`02:00:22:33:44:02`
- `WDIAGS_MODE=3`
- `WDIAGS_PTP=9`
- focused valid samples：`30/30`
- invalid samples：`0`
- counter decrease：`0`
- focused `PTP_TX_DELTA=15`
- `WDIAGS_PTP_RX`、MiniNIC TX/RX 都持續增加
- RXERR 維持 0
- `FOREIGN_META=0x03000001`，表示 foreign count 1、best index 0

短窗口內個別 PTP counter 為 0 不再單獨造成 failure；本次 30 samples 的 PTP/MiniNIC activity 與 RXERR 證據均支持 packet path 正常活動。

**Step 2 判定：PASS。**

這是目前硬體上的 repeated accepted-sample 結果，不是 fresh HEAD SOF 的新 provenance 證明。

## Step 3：WR Parent / Signaling Handshake

Slave focused 30 samples 的重點結果：

- foreign master：`1/0`，持續可讀
- parent is WR：`1`
- parent calibrated：`1`
- RX WR message：`0x1001 LOCK`，大部分樣本成立
- TX WR message：`0x1000 SLAVE_PRESENT`，大部分樣本成立
- `LOCK_ENABLE=4`
- `RCER=1`
- `signal_good=28`
- `signal_bad=2`
- `state_idle=30`
- `state_good=0`
- `STATE_EVIDENCE=READ_INCONSISTENT`
- `POST_STEP3_LOCK_STAGE=TIMEOUT`

這表示 parent/signaling/lock-enable 的正向證據存在，但 current WR state shadow 在本次 30 samples 全部呈現 idle。由於正向 signaling 證據與 state 欄位互相矛盾，本紀錄不把它直接寫成 hardware/firmware failure；同時也不把 state 欄位當作已完全通過。它目前是需要後續 source-backed mapping 或更專用 state readout 釐清的 measurement inconsistency。

目前 focused script 的 gate 結果為 `STEP3_REGRESSION=PASS`，原因是 handshake positive evidence 與 `LOCK_ENABLE>0` 成立，且腳本將 post-step3 timeout 分支視為已觀測的後續階段。這個 PASS 的範圍只涵蓋 parent/signaling/lock-enable evidence；`WRS_IDLE` state shadow 仍標記為 `READ_INCONSISTENT`。

**Step 3 判定：PASS（附帶 READ_INCONSISTENT state evidence）。**

## Step 4 barrier

本輪沒有進行 Step 4 functional experiment。dashboard 仍可能顯示既有硬體的 SoftPLL/DMTD event 狀態，但那些讀值不是本輪的修改或實驗結果，也沒有被拿來改寫 Step 2/Step 3 gate。

因為本次 repeated read-only evidence 的 Step 2 與 Step 3 gate 均為 PASS：

```text
STEP4_ALLOWED = YES
```

這只表示可以在下一輪另開 Step 4 實驗；不表示 Step 4 已通過，也不表示本輪已改動或驗證 SoftPLL。

## 失敗分類

```text
HARDWARE/FIRMWARE_FAILURE = 未由本輪 Step 2/Step 3 證據支持
JTAG/DASHBOARD_MEASUREMENT_FAILURE = 本輪沒有 repeated invalid/timeout 造成 gate failure
```

已觀察到的 `READ_INCONSISTENT` 只限定在 Slave WR state shadow 與 signaling positive evidence 的互相矛盾，不能擴大解讀成整個硬體或 firmware 失敗。

## 最終 regression gate

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
```

## 下一步

下一輪若要開始 Step 4，只能先保持本次功能 baseline 不變，並針對 SoftPLL enable/startup 做單一變因的 read-only source/runtime audit。特別要先保留本次 Slave 的 `READ_INCONSISTENT` state evidence，確認它是 state mapping/ mailbox snapshot 問題，還是 handshake 完成後的實際狀態回落；不可在 Step 4 實驗中順便修改 WR signaling 或 SoftPLL 演算法。
