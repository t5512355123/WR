# EXP-WRPC-STEP4-ACCEPT-COUNT-20260822

## 實驗基本資料

- 實驗名稱：Step 4 DMTD 完整 accept 計數器邊界唯讀驗證
- 日期：2026-08-22
- Git branch：`exp/step4-softpll-enable`
- Git commit：`693b4ad5dfbeddb500856d2bba87ff967b037e56`
- 實驗目的：確認 DMTD accepted event 是否在 fresh HEAD 硬體上持續產生，並辨識它與既有 DMTD event、tag、TRR、IRQ、helper 計數器之間的第一個無活動邊界。
- 唯一變因：新增兩個完整 32-bit、read-only 的 DMTD-domain accept counter 觀測欄位；沒有修改任何功能控制路徑。

## 本次明確沒有修改

本次沒有修改 Master/Slave role switching、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional RTL，也沒有寫入任何 runtime Wishbone control register。

新增的 `DMTD_REF_ACCEPT_COUNT` 與 `DMTD_FB_ACCEPT_COUNT` 只讀取既有 `dbg_deglitch_accept_count`，用來區分：

```text
clk_sampled / deglitch accept
        -> post-CDC DMTD event
        -> tag / TRR / IRQ / helper
```

## Fresh build provenance

本次由 pain 在 exact HEAD `693b4ad5dfbeddb500856d2bba87ff967b037e56` 執行 firmware build、Quartus clean compile，並使用 fresh SOF 燒錄兩片 DE5a。Quartus 版本為 `17.0.0 Build 595 04/25/2017 SJ Standard Edition`。

### Master

- Project：`DE5a_wr_master_jtag`
- QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`c52b05da936871439793cc31f80e15772104d24be6020c68c4e7694f259f5535`
- SOF SHA256：`3f5ece5048c91eefab3b40b87d25d32c3e4f5dbef1cbcd44649168056aee954a`
- Programmer checksum：`0x30A338D2`
- Compile：`Full Compilation was successful`
- Timing：`TIMING_CLOSED=NO`，worst setup slack `-0.184 ns`

### Slave

- Project：`DE5a_wr_slave_jtag`
- QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`1f6acd6c6faaa8e88344ae04df97a3e657fe10b9554d53dc2bf288851def406d`
- SOF SHA256：`15a845237fb6eb720f11143a6a55b703bd40145e5567d8a43f17fd5eba7310b3`
- Programmer checksum：`0x30A53865`
- Compile：`Full Compilation was successful`
- Timing：`TIMING_CLOSED=NO`，worst setup slack `-0.242 ns`

## 燒錄結果

- Master 使用 `DE5 [1-11.1]`：`Configuration succeeded`，0 errors，0 warnings。
- Slave 使用 `DE5 [1-11.2]`：`Configuration succeeded`，0 errors，0 warnings。
- 燒錄後等待約 30 秒，再執行所有 read-only runtime tests。

原始 programmer logs：

- `raw/program_accept_count_693b4ad_master_20260822.log`
- `raw/program_accept_count_693b4ad_slave_20260822.log`

## Step 1～Step 3 regression

### Step 1：PHY / Link

Fresh SOF 的 repeated JTAG evidence 顯示兩片板的 CPU、PHY、RX/TX ready、timing link 與 encoding-error 條件正常；CPU `reset=0`、`fault=0`、`im_valid=1`，marker 為 `0xB004` 且 `seen=1`。

結果：`STEP1_REGRESSION=PASS`

### Step 2：Endpoint / MiniNIC / PTP

Fresh repeated sampling 顯示：

| 項目 | Master | Slave |
|---|---|---|
| MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` |
| MODE | `2` | `3` |
| PTP | `6` | `9` |
| PTP/MiniNIC counter | 持續有 activity | 持續有 activity |
| RXERR | 未見持續增加 | 未見持續增加 |
| FOREIGN_META | 不適用 | `0x03000001` |

`FOREIGN_META=0x03000001` 依 source mapping 表示已建立一筆 foreign master，best index 為 0。無效 mailbox 讀值沒有混入 focused gate 判定。

結果：`STEP2_REGRESSION=PASS`

### Step 3：WR Parent / Signaling Handshake

Slave focused repeated sampling 共 30 個有效 samples，`invalid_samples=0`、`signal_good=30`、`signal_bad=0`，並持續觀察到：

- Foreign master exists、best index `0`
- parent is WR 與 parent calibrated 欄位成立
- TX `0x1000`（`SLAVE_PRESENT`）
- RX `0x1001`（`LOCK`）
- `LOCK_ENABLE=4`
- `WR_SIGNAL_REJECT=0`

同時，`WDIAGS_TEMP` 所代表的 live state shadow 在本次窗口讀到 `WRS_IDLE`，因此 script 將狀態列為 `STATE_EVIDENCE=READ_INCONSISTENT`；這個單一 shadow 與完整 focused handshake evidence 不一致，不能單獨推翻已取得的 signaling evidence。

結果：`STEP3_REGRESSION=PASS`，並保留 `STATE_EVIDENCE=READ_INCONSISTENT` 作為觀測注意事項。

原始 regression logs：

- `raw/regression_accept_count_step23_693b4ad_20260822.log`
- `raw/regression_accept_count_handshake_693b4ad_20260822.log`

## Step 4 DMTD boundary 結果

執行：

```text
quartus_stp -t scripts/jtag/read_step4_dmtd_boundary.tcl 20 500
```

共觀測 20 samples，sample 間隔 500 ms。Tcl 執行成功，Quartus SignalTap II 回報 0 errors、0 warnings。

### Master

第一個與最後一個 sample 的主要值相同：

```text
ACCEPT_REF = 0x00682A7F -> 0x00682A7F，delta=0
ACCEPT_FB  = 0x0243869D -> 0x0243869D，delta=0
REF event  = 0x001C7FC9 -> 0x001C7FC9，delta=0
FB event   = 0x009E6613 -> 0x009E6613，delta=0
VALID/TRR_WRITE = 0，沒有持續 activity
RCER = 0
```

### Slave

第一個與最後一個 sample 的主要值相同：

```text
ACCEPT_REF = 0x0D6535EC -> 0x0D6535EC，delta=0
ACCEPT_FB  = 0x0F3773D6 -> 0x0F3773D6，delta=0
REF event  = 0x03AEA34C -> 0x03AEA34C，delta=0
FB event   = 0x0420F4E7 -> 0x0420F4E7，delta=0
VALID/TRR_WRITE = 0，沒有持續 activity
RCER = 1
```

兩片板的 accept counter 都是非零，表示 counter 過去曾累積過 accepted event；但在本次 10 秒觀測窗口中沒有任何增加。`DMTD_BOUNDARY_TAG`、`DMTD_BOUNDARY_OUTPUT`、`TRR_WRITE` 等 downstream evidence 也沒有形成持續 delta。

## 判讀

本次結果不是 JTAG 讀取失敗：

- Tcl 完整執行完畢，沒有 exception。
- 新增的 32-bit accept counter 可以被讀出，而且數值穩定。
- Step 2/3 focused scripts 已取得有效 samples。

目前證據支持：

1. `ACCEPT_REF/ACCEPT_FB` 在歷史上有非零累積值。
2. Fresh hardware 的本次觀測窗口沒有新的 DMTD accepted event。
3. 由於 accept counter、post-CDC event、tag/TRR/IRQ/helper 皆沒有增加，尚不能把第一個 blocker 精確縮小到 accept 與 post-CDC 之間；可以確定的是「本次窗口沒有新的 DMTD event chain」。
4. 因此 Step 4 尚未通過，但目前沒有足夠證據宣稱 PTP、WR signaling 或 SoftPLL 演算法本身已找到根因。

## Regression barrier

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_REGRESSION = NOT_PASS
STEP4_ALLOWED    = NO  （本次 Step 4 gate 尚未通過）
```

這次的結果屬於「fresh runtime 尚未出現 Step 4 所需 activity」，不是把 invalid JTAG mailbox sample 誤判成 hardware failure。Step 4 仍不得進行演算法、threshold、polarity、PI、DCO 或 SI5340 修改。

## 原始證據位置

- Build logs：`raw/build_accept_count_693b4ad_master_20260822.log`、`raw/build_accept_count_693b4ad_slave_20260822.log`
- Build provenance：`raw/build_info_accept_count_693b4ad_master_20260822.txt`、`raw/build_info_accept_count_693b4ad_slave_20260822.txt`
- Firmware hashes：`raw/firmware_accept_count_693b4ad_master_20260822.sha256`、`raw/firmware_accept_count_693b4ad_slave_20260822.sha256`
- Programmer logs：`raw/program_accept_count_693b4ad_master_20260822.log`、`raw/program_accept_count_693b4ad_slave_20260822.log`
- Step 2/3 reliability：`raw/regression_accept_count_step23_693b4ad_20260822.log`
- Step 3 focused handshake：`raw/regression_accept_count_handshake_693b4ad_20260822.log`
- Step 4 boundary：`raw/regression_accept_count_step4_boundary_693b4ad_20260822.log`
- 先前 0cc755b control boundary：`raw/regression_step4_dmtd_boundary_0cc755b_20260822.log`；此檔只作歷史對照，不作本次 fresh HEAD 的 provenance 或 gate 判定。

## Next Step

先保留本次 fresh evidence，請 White Rabbit 技術專家針對「accept counter 非零但 10 秒內 delta=0，且兩板狀態不同」做 source/runtime review。下一個實驗仍應是單一、可追溯且不改演算法的診斷變因；在取得 Step 4 PASS 前，不進行 functional tuning，也不 merge `main`。
