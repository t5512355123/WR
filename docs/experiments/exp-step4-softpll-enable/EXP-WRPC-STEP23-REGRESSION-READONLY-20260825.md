# EXP-WRPC-STEP23-REGRESSION-READONLY-20260825

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP23-REGRESSION-READONLY-20260825`
- 日期：2026-08-25
- Git repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- Git HEAD：`3f0296619acea825adb7de4945104b0a75f74843`
- 參考 functional baseline：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- 實驗類型：JTAG read-only regression / dashboard reliability

## 實驗目的

本輪只確認目前硬體上的 Step 1、Step 2、Step 3 是否仍有可重複、可接受的唯讀證據，並確認 JTAG mailbox 的無效讀值不會被 dashboard 當成硬體失敗。Step 2、Step 3 通過前，不允許進行 Step 4 functional experiment。

## 本輪限制與實際動作

要求的功能限制是：不修改 Master/Slave role、PTP、WR signaling、SoftPLL、DDMTD、PI、lock threshold、DCO、SI5340 或 PHY 行為；不 program FPGA；不以單一 dashboard snapshot 宣稱硬體成功或失敗。

本次實際執行：

- 使用既有 focused JTAG scripts 進行 read-only sampling。
- 使用 `read_step23_register_reliability.tcl` 連續驗證 critical registers。
- 使用 `read_wb_runtime.tcl` 確認極簡 dashboard 可完整結束，且沒有 Tcl exception。
- 使用 `read_step4_startup_focused.tcl` 讀取既有硬體的 WAIT_STABLE_0 max counter；此結果不是 fresh SOF 的驗證。
- 本次沒有 program FPGA。

本機保存的原始資料：

`docs/experiments/exp-step4-softpll-enable/raw/20260825-readonly-regression/`

## Read-only script 與參數

```text
read_master_ptp_slave_parent_long.tcl  20 samples, 500 ms
read_wr_handshake_focused.tcl          30 samples, 500 ms, 25 retries
read_step23_register_reliability.tcl   10 samples, 250 ms, all, 25 retries
read_wb_runtime.tcl                    one dashboard run
read_step4_startup_focused.tcl         30 samples, 100 ms, events
```

所有 script 的 Quartus SignalTap 執行結果均為 Tcl evaluation successful，沒有因 `TIMEOUT`、`INVALID` 或 `DECREASED` 中止後續輸出。

## Step 1 / Step 2 / Step 3 結果

### Step 1：QSFP / Native PHY

Dashboard 在兩片板都觀察到：

- `si_config_done=1`
- `wr_ready=1`
- `core_tm_link_up=1`
- `core_link_ok=1`
- `wr_rx_ready=1`
- `wr_tx_ready=1`
- `core_phy_rst=0`
- `si_id_error=0`
- `wr_rx_enc_err=0`
- `wr_tx_enc_err=0`
- `CPU_RESET_n=1`
- `wr_rx_locked_to_data=1`

結果：`STEP1_REGRESSION = PASS`

### Step 2：Endpoint / MiniNIC / PTP

Master dashboard snapshot：

- MAC：`02:00:22:33:44:01`
- `WDIAGS_MODE=2 MASTER`
- `WDIAGS_PTP=6 MASTER`
- `WDIAGS_PTP_RX` delta：`8`
- `WDIAGS_PTP_TX` delta：`26`
- `WDIAGS_TX` delta：`34`
- `WDIAGS_RX` delta：`15`
- `WDIAGS_RXERR` delta：`0`

Slave focused repeated sampling：

- valid samples：`30/30`
- invalid samples：`0`
- counter decrease：`0`
- `MODE=3`
- `PTP=9`
- PTP RX/TX、MiniNIC TX/RX 均持續增加
- `RXERR=0`

Slave reliability sampling 也得到：

```text
STEP2_INDEPENDENT result=PASS
```

結果：`STEP2_REGRESSION = PASS`

### Step 3：WR Parent / Signaling Handshake

Slave focused repeated sampling 的 30 個有效 sample 都包含：

- Foreign Master：`foreign=1/0`
- parent is WR：`parent=1/...`
- parent calibrated：`1`
- WR RX message：`0x1001`，count `>0`
- WR TX message：`0x1000`，count `>0`
- `LOCK_ENABLE=4`
- `RCER=0x00000001`

reliability sampling 也得到：

```text
FOREIGN_META  valid=10 invalid=0 distinct=1 value=03000001
WR_RX_SIGNAL  valid=10 invalid=0 value=10010001
WR_TX_SIGNAL  valid=10 invalid=0 value=10000001
LOCK_ENABLE   valid=10 invalid=0 value=00000004
STEP3_INDEPENDENT result=PASS
```

但同一批 sample 的 live WR state 是：

```text
local_state=0 next_state=0
STATE_EVIDENCE=READ_INCONSISTENT
POST_STEP3_LOCK_STAGE=TIMEOUT
```

因此本紀錄保留兩個事實：signaling/lock-enable 的 Step 3 acceptance evidence 成立；live state 與這些 evidence 不一致，不能把它延伸解讀成 WR lock 或 Step 4 成功。

結果：`STEP3_REGRESSION = PASS`，附帶 `STATE_EVIDENCE = READ_INCONSISTENT`。

## JTAG / dashboard reliability 結果

`read_step23_register_reliability.tcl` 對 critical register 進行重試並拒絕 stale/filler pattern。此次 Slave 10-sample 統計為：

- `FOREIGN_META`：valid `10`、invalid `0`
- `PARSE_META`：valid `10`、invalid `0`
- `WR_RX_SIGNAL`：valid `10`、invalid `0`
- `WR_TX_SIGNAL`：valid `10`、invalid `0`
- `LOCK_ENABLE`：valid `10`、invalid `0`
- `WR_FAILURE_DEBUG`：valid `10`、invalid `0`
- `WDIAGS_TEMP`：valid `10`、invalid `0`

本次沒有把 `0xA5A51330` 類似值當成合法 `WDIAGS_PTP`。`TIMEOUT`、`INVALID`、`DECREASED` 會保留為 measurement status，不會先進入數值比較，也不會中止整份 dashboard。

## Step 4 只讀觀測

這部分只讀目前已在板上的硬體，沒有用新候選 SOF 重新 program，因此不能當作 fresh HEAD 的 Step 4 acceptance。

觀察到：

```text
DE5 [1-11.1] ref_max=25088 fb_max=6272 threshold=1000 ref_ge=1 fb_ge=1
DE5 [1-11.2] ref_max=26112 fb_max=6528 threshold=1000 ref_ge=1 fb_ge=1
```

這表示目前讀到的 WAIT_STABLE_0 state-gated counter 曾高於 threshold；但因為硬體 provenance 不是本次 fresh candidate SOF，且 dashboard 同時觀察到 Slave `OCER=TIMEOUT`、DMTD/tag/TRR/IRQ/helper event delta 為 `0`，本次不能宣稱 Step 4 PASS，也不能只由這些資料確定 SoftPLL functional root cause。

結果：`STEP4_RESULT = NOT_EVALUATED_ON_FRESH_SOF`

## Regression barrier 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_EVALUATED_ON_FRESH_SOF
```

目前證據支持：

- Step 1 PHY/link 沒有顯示硬體失敗。
- Step 2 Endpoint/MiniNIC/PTP packet path 通過 repeated read-only gate。
- Step 3 parent/signaling/lock-enable evidence 通過 repeated read-only gate。

目前證據不支持：

- fresh HEAD SOF 已成功重現 Step 2/3，因為本輪沒有 program FPGA。
- SoftPLL 已 enable 並持續工作。
- SoftPLL 已 lock。
- Slave `time_valid=1`。

### 硬體/firmware failure 與量測問題的區分

本輪沒有足夠證據宣稱 Hardware/Firmware Failure。Slave `WRS_IDLE` 與 `SLAVE_PRESENT/LOCK/LOCK_ENABLE` 的並存是 `READ_INCONSISTENT` / post-Step-3 state evidence，應繼續用 source-backed focused sampling 追查；不能把單一或互相矛盾的 mailbox snapshot 直接當作 SoftPLL 根因。

## Fresh build provenance（候選資料，未燒錄）

本機在本輪前序流程已產生候選 clean build，但沒有拿它 program FPGA。以下只作 provenance 保存，不作 runtime acceptance：

- Quartus：Version `17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master MIF SHA256：`f6ffe5f7a1189dbb3c12ecd087aab78eb904468cbe4e37b1ee6cf2328dd17347`
- Slave MIF SHA256：`beb96f8ac9a77dae1b4919101efe6713e795e639ce7c6b64d551b16011971d96`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`1698557faf930bf476ed7cd8390859e868234de64fbb7857a7a8afe853bf034e`
- Slave SOF SHA256：`f303b92134af2f672128013a846ed910b5b8f9858fca6db537af0fab2acfc8b5`
- Programmer log/checksum：本輪未執行，因此不存在 programmer success/checksum 證據。

## 下一步

1. 保持 Step 2/3 barrier，不修改 role、PTP、WR signaling 或 SoftPLL algorithm。
2. 若要開始 Step 4，先以 `3f02966` 的 fresh SOF 完成雙板 program，再重新跑相同 Step 2/3 focused gate。
3. 只有 fresh current hardware 再次通過 Step 2/3，才比較 fresh SOF 的 WAIT_STABLE_0 max、WAIT_EDGE_ENTRY 與 downstream event counters。

## 原始檔案

所有原始輸出與候選 build provenance 位於：

`docs/experiments/exp-step4-softpll-enable/raw/20260825-readonly-regression/`

