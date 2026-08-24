# EXP-WRPC-STEP23-READONLY-REGRESSION-20260825

## 實驗識別

- 日期：2026-08-25
- 實驗名稱：Step 2 / Step 3 read-only regression barrier
- Git branch：`exp/step4-softpll-enable`
- Git commit：`0a4fbe20c475ed2b73c506286b0167edda24cdec`
- 目的：在不改變任何 FPGA 功能行為的前提下，重新確認 Step 2 與 Step 3 是否仍有可靠的現場證據，並判斷是否允許進入 Step 4。

## 本次限制

- 只執行 JTAG read-only diagnostics。
- 沒有 program FPGA。
- 本次 regression gate 沒有使用 fresh SOF 重新宣稱硬體成功；JTAG 讀值代表當下板卡已載入的 bitstream。
- 沒有修改 Master / Slave role、PTP、WR signaling、SoftPLL、DDMTD、PI、lock threshold、DCO、SI5340 或 PHY functional behavior。
- Tcl 修改只涉及 mailbox read validation、counter 特殊值處理與已存在診斷欄位的 packed-field 解碼。

## 執行的唯讀測試

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl
quartus_stp -t scripts/jtag/read_master_ptp_slave_parent_long.tcl 25 500
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 30 500 25
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 50 100 mapping
```

Quartus 回報上述 Tcl scripts 均 `successful`、`0 errors`。原始輸出保存於：

```text
docs/experiments/exp-step4-softpll-enable/raw/20260825_regression_0a4fbe2/
```

包含：

- `dashboard.log`
- `step2_parent_long.log`
- `step3_handshake_focused.log`
- `step4_mapping.log`
- `provenance.txt`

## Step 1：PHY / Link

兩片板在 dashboard 與 focused samples 中均觀察到：

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

判定：`STEP1_REGRESSION = PASS`

## Step 2：Endpoint / MiniNIC / PTP

### Master：DE5 [1-11.1]

- MAC：`02:00:22:33:44:01`
- `WDIAGS_MODE=2`
- `WDIAGS_PTP=6`
- focused samples：`valid_samples=30`、`invalid_samples=0`
- `PTP_TX_DELTA=104`
- MiniNIC TX/RX counter 持續增加
- `RXERR` 沒有增加

### Slave：DE5 [1-11.2]

- MAC：`02:00:22:33:44:02`
- `WDIAGS_MODE=3`
- `WDIAGS_PTP=9`
- focused samples：`valid_samples=30`、`invalid_samples=0`
- `PTP_TX_DELTA=11`
- MiniNIC TX/RX counter 持續增加
- `RXERR` 沒有增加
- `FOREIGN_META=0x03000001`，即 foreign count 1、best index 0

短時間內若單一 counter delta 為 0，這次沒有直接當成硬體失敗；本次 focused repeated samples 的整體 packet activity 仍成立。

判定：`STEP2_REGRESSION = PASS`

## Step 3：WR Parent / Signaling

Slave 的 30 筆 focused samples 全部為有效 mailbox read，觀察到：

- Foreign Master：`1/0`
- parent metadata：`parentIsWRnode=1`、`parentWrModeOn=0`、`parentCalibrated=1`
- RX WR message：`0x1001`，count 持續可見
- TX WR message：`0x1000`，count 持續可見
- `LOCK_ENABLE=4`
- focused gate：`STEP3_REGRESSION=PASS`

但同一批 samples 中：

- `local_state=0`
- `next_state=0`
- `state_idle=30`
- `state_good=0`
- `STATE_EVIDENCE=READ_INCONSISTENT`

因此不能把 current-state 欄位直接寫成「Step 3 硬體失敗」。目前較保守、符合證據的描述是：parent、signaling、lock-enable 證據成立，但 state 欄位與其他 mailbox snapshot 不一致，仍需後續釐清是 state 真正回到 idle，或是 mailbox snapshot / read timing 的觀測差異。

判定：`STEP3_REGRESSION = PASS`

附註：`READ_INCONSISTENT` 是量測證據品質標記，不是功能失敗標記。

## Step 4 mapping audit

本次使用 50 samples、100 ms 間隔，並依 source-backed mapping 將 `QUAL_REACHED_8` 取 bits 31..16 後再計算 delta。

### Master

```text
REF_GOT_EDGE_ENTRY_MAPPING delta=0
REF_QUAL8_MAPPING          delta=4
REF_ACCEPT_MAPPING         delta=0
FB_GOT_EDGE_ENTRY_MAPPING  delta=0
FB_QUAL8_MAPPING           delta=0
FB_ACCEPT_MAPPING          delta=0
```

### Slave

```text
REF_GOT_EDGE_ENTRY_MAPPING delta=0
REF_QUAL8_MAPPING          delta=0
REF_ACCEPT_MAPPING         delta=0
FB_GOT_EDGE_ENTRY_MAPPING  delta=0
FB_QUAL8_MAPPING           delta=0
FB_ACCEPT_MAPPING          delta=0
```

所有 mapping series 都有 50/50 valid samples、沒有 timeout；部分 raw 32-bit 欄位出現 decrease 記號，但這不是本次判斷功能失敗的依據，因為欄位可能是 packed value、reset/CDC 或 mailbox snapshot 差異。

這次 mapping 結果不足以證明 SoftPLL 已進入閉迴路，也不足以證明 SoftPLL 功能故障。

## 回歸總結

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_FUNCTIONAL_RESULT = NOT_TESTED
HARDWARE_FIRMWARE_FAILURE = NOT_PROVEN
JTAG_DASHBOARD_MEASUREMENT = READ_INCONSISTENT
```

## 結論

本次 read-only repeated evidence 支持 Step 1、Step 2、Step 3 regression gate 通過，因此 barrier 允許後續進入 Step 4。這個結論只代表：PHY/link、Endpoint/MiniNIC/PTP packet activity、Foreign Master、WR signaling 與 `LOCK_ENABLE` 的現場讀值成立。

本次沒有進行 Step 4 functional experiment，也沒有因 `PSTAT.locked`、`time_valid` 或 mapping counter 不活動而修改 SoftPLL。因為 current state 長時間讀到 idle，且 mapping counters 的來源/跨時脈讀值仍有觀測不一致，Step 4 的第一個真正 functional blocker 尚未被證明。

## 下一步

1. 保持目前 Master / Slave / PHY / PTP / signaling functional baseline 不變。
2. 在下一輪先針對 Step 4 的 source-backed observability 做 read-only audit，確認 `RCER`、sequencer、DMTD、tag、TRR、IRQ、helper update 與 correction request 的定義和讀取一致性。
3. 若後續需要 program，必須先建立獨立 commit，使用 exact HEAD 做 clean firmware/Quartus provenance，並在燒錄後立即新增完整實驗紀錄。

