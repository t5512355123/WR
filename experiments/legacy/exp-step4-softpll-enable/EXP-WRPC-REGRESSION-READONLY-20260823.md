# EXP-WRPC-REGRESSION-READONLY-20260823

## 實驗基本資料

- Experiment ID：`EXP-WRPC-REGRESSION-READONLY-20260823`
- 日期：2026-08-23
- 目的：在進入 Step 4 之前，重新建立 Step 1、Step 2、Step 3 的唯讀回歸關卡，並區分硬體/韌體失敗與 JTAG 量測失真。
- 本機 branch：`exp/step4-softpll-enable`
- 本機 HEAD：`6c9fe1913e3acab41a3c2ffbe15f3bd88dc2582f`
- pain checkout：`688b152b2551ca51c58b8ec0a40967f5d7e8dca0`，當時為 detached HEAD。
- 使用者指定 functional baseline：`51864b8743759bc20bea817af4bcd19ea81ab4ac`

## 本輪變因與限制

本輪沒有修改任何 RTL、firmware、MIF、PHY、PTP、WR signaling、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO 或 SI5340 行為。沒有 Quartus compile、沒有產生新 SOF、沒有 program FPGA，也沒有寫入 Wishbone control register。

本輪唯一操作是使用既有 JTAG read-only diagnostics 取樣，保存 raw output 與判定結果。因此本輪不能宣稱產生了新的 `HEAD -> MIF -> SOF` provenance；實際板上 SOF 的 SHA256 與 programmer checksum 沒有在本輪重新量測，不能把 historical SOF 或指定的 `51864b874...` 直接當成本輪新硬體證據。

## 執行環境

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard
- JTAG 工具：`quartus_stp`
- 使用命令：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_step23_register_reliability.tcl 8 250 all
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl 20 500
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl
```

三次 STP 執行都完整結束，回報 `Evaluation ... successful` 與 0 errors、0 warnings。

## Tcl reliability audit

本輪重新 audit 現有 read-only Tcl；目前 branch 的診斷實作已包含本輪要求的防護，因此沒有再修改 Tcl source：

- `read_wb_runtime.tcl` 會拒絕 `A5A5xxxx` stale/filler word，critical register 最多 retry 5 次；`TIMEOUT`、`INVALID`、`DECREASED` 在數值比較前會先分流。
- `read_wr_handshake_focused.tcl` 對 critical enum/status 要求連續兩次 source-valid read；counter 會做兩次 read，無法穩定或出現 decrease 就標記 measurement invalid/retest。
- `read_step23_register_reliability.tcl` 的 mailbox read 也最多 retry 5 次，`FOREIGN_META`、`PARSE_META`、WR state/message、`LOCK_ENABLE` 等欄位會先做 source-backed validity check。
- 短窗口單一 `PTP_TX` delta=0 不會單獨推翻 Step 2；只要 PTP RX、MiniNIC TX/RX 活動且 RXERR 沒增加，focused regression 仍可通過。

因此本輪觀察到的 reliability script 跨欄位輸出，不是因為 dashboard 將 `A5A5A51330` 當成合法 PTP state；它是在另一個逐欄位 read path 中顯示出 mailbox snapshot/read consistency 問題，已由 focused accepted-sample gate 隔離。

## Raw evidence

本輪 raw log 已保存於：

- `docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-REGRESSION-READONLY-20260823/step23_register_reliability.log`
- `docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-REGRESSION-READONLY-20260823/wr_handshake_focused.log`
- `docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-REGRESSION-READONLY-20260823/read_wb_runtime_dashboard.log`

## Step 1～Step 3 回歸結果

### Step 1：PHY / Link

Dashboard 兩片板均觀測到 ready/link/RX/TX/CPU reset 正常，RX lock-to-data=1，PHY reset=0，SI ID error=0，RX/TX encoding error=0。

```text
STEP1_REGRESSION = PASS
```

### Step 2：Endpoint / MiniNIC / PTP

`read_wr_handshake_focused.tcl 20 500` 的兩片板各有 20/20 valid samples、0 invalid samples、0 counter decrease。

Master：

- MAC=`02:00:22:33:44:01`
- MODE=2
- PTP=6
- PTP RX/TX 與 MiniNIC RX/TX counters 持續增加
- RXERR=0

Slave：

- MAC=`02:00:22:33:44:02`
- MODE=3
- PTP=9
- PTP RX/TX 與 MiniNIC RX/TX counters 持續增加
- RXERR=0
- FOREIGN_META=`03000001`

因此目前有 repeated accepted samples 支持 Endpoint、MiniNIC、PPSI/PTP packet path 正常運作。

```text
STEP2_REGRESSION = PASS
```

### Step 3：WR Parent / Signaling Handshake

Slave focused 20 samples 中，所有 accepted samples 都觀測到：

- Foreign Master=`1/0`
- parent is WR=`1`
- parent calibrated=`1`
- RX WR message=`0x1001`（LOCK）
- TX WR message=`0x1000`（SLAVE_PRESENT）
- LOCK_ENABLE=`4`
- RXERR=0

同一組取樣的 `local_state=0`、`next_state=0` 與上述 handshake evidence 不一致，因此原始結果保留為：

```text
STATE_EVIDENCE = READ_INCONSISTENT
POST_STEP3_LOCK_STAGE = TIMEOUT
```

這表示 current-state/shadow 欄位和 handshake counter/message evidence 之間有讀取或 shadow 一致性問題；它不能單獨推翻連續 20 次都成立的 Step 3 必要 evidence。依 focused script 的 regression gate，Step 3 通過。

```text
STEP3_REGRESSION = PASS
```

## JTAG measurement issue

`read_step23_register_reliability.tcl 8 250 all` 顯示每個欄位本身都回報 valid，但 Slave 部分 output 出現跨欄位交錯樣式，例如 PTP_RX、PTP_TX、RXERR 的列值與 focused script 同時段讀值不一致；該 script 也因此將 Slave `STEP3_INDEPENDENT` 標成 `INVALID`。

這與 focused 20-sample script 的 20/20 accepted samples、正確 MAC/role/PTP、FOREIGN_META、WR message 與 LOCK_ENABLE evidence 不一致。因而本輪對這支 reliability script 的結論是：

```text
JTAG/DASHBOARD_MEASUREMENT_FAILURE = PRESENT_IN_ONE_READ_PATH
HARDWARE/FIRMWARE_FAILURE = NOT_ESTABLISHED
```

這不是把 `INVALID` 讀值當成硬體 FAIL；後續應修正或隔離該 read path，再用 accepted samples 重新判定。

## Step 4 barrier

Step 1、Step 2、Step 3 都已由 focused repeated read-only evidence 通過，因此 regression barrier 允許後續進入 Step 4 實驗規劃：

```text
STEP4_ALLOWED = YES
```

本輪沒有執行任何 Step 4 functional change，也沒有宣稱 SoftPLL 已 lock 或 time_valid 已成立。

## 結論

目前最保守且有證據支持的結論是：

1. 兩片 DE5a 的 PHY/link、Endpoint/MiniNIC/PTP packet path 仍有可靠活動證據。
2. Slave 已反覆建立 Foreign Master，並反覆觀測到 `SLAVE_PRESENT`、`LOCK` 與 `LOCK_ENABLE=4`，所以 Step 3 regression gate 通過。
3. `local_state=WRS_IDLE` 與 handshake evidence 的衝突應標記為 `READ_INCONSISTENT`，不可直接寫成 Step 3 hardware failure。
4. 一支 register reliability read path 有跨欄位交錯/不一致輸出，屬於 JTAG measurement issue；需要修正量測可靠性，但本輪沒有改功能邏輯。
5. 本輪沒有新 SOF、MIF 或 programmer provenance，不能把本輪結果宣稱為 `51864b874...` 的 fresh hardware reproduction。

## 下一步

在使用者允許進行 Step 4 functional experiment 前，先保留本輪 barrier 與 raw evidence。若要改善診斷，下一個低風險方向是只修 read-only mailbox grouping/validation，讓所有 status、enum、counter 都採 accepted sample 與明確的 invalid/timeout 標記；不要修改 WR functional behavior。
