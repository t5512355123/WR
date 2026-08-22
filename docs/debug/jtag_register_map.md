# DE5a White Rabbit JTAG 可觀測性與暫存器地圖

最後整理：2026-08-19

本文件說明目前 DE5a bring-up 版本如何透過 JTAG 觀察 White Rabbit（WR）系統。它是**唯讀觀測介面文件**，不會改變 WR、PTP（Precision Time Protocol，精確時間協定）、SoftPLL（Software Phase-Locked Loop，軟體鎖相迴路）、PHY（Physical Layer，實體層）或 SI5340 DCO（Digitally Controlled Oscillator，數位控制振盪器）的控制行為。

文件的 source of truth 是目前 branch 內的：

- `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd`
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd`
- `quartus/jtag_runtime_diag/wr_jtag_wb_mailbox.vhd`
- `scripts/jtag/read_wb_runtime.tcl`
- `vendor/wrpc-sw/lib/task-diags.c`
- `vendor/wrpc-sw/dev/wdiags.c`
- `vendor/wrpc-sw/include/hw/wrc_diags_regs.h`

若實際燒錄的 SOF（SRAM Object File）不是這些 RTL 與 firmware 產生的版本，不能直接套用本文件的所有欄位解碼；請先看〈Source / SOF provenance 注意事項〉。

## 1. 整體架構：pain 如何讀到 FPGA 內部狀態

```text
┌──────────────────────────────┐
│ pain Linux                   │
│ quartus_stp                  │
│ scripts/jtag/read_wb_runtime │
└──────────────┬───────────────┘
               │ JTAG cable
               ▼
┌──────────────────────────────────────────┐
│ Intel In-System Sources and Probes       │
│                                          │
│ instance 0  Direct status probe          │
│ instance 1  JTAG Wishbone mailbox        │
│ instance 2..7 Direct CPU/clock probes    │
└──────────────┬───────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
  直接讀取訊號       mailbox 產生一次 WB read
  Direct Probe       Wishbone register read
                         │
                         ▼
                 ┌──────────────────┐
                 │ xwr_core WB bus  │
                 │                  │
                 │ Endpoint         │
                 │ MiniNIC          │
                 │ PPSI / WR diag   │
                 │ SoftPLL registers│
                 └──────────────────┘
```

### 1.1 Direct Probe

Direct Probe 是 RTL 直接接到 `altsource_probe` 的訊號向量。Tcl 只需要用 `read_probe_data -instance_index N` 讀取當下值，不需要提供暫存器位址，也不會在 Wishbone bus 上產生讀取交易。

目前 Direct Probe 用來觀察：

- PHY、link、time-valid、clock activity 等狀態。
- CPU PC、reset、fault、instruction-valid。
- boot marker、最後一次 internal store、exception。

### 1.2 JTAG Wishbone mailbox

Wishbone mailbox 是一個小型的 JTAG-to-Wishbone 轉接器。Tcl 把「讀取位址、byte select、讀寫方向」寫入 instance 1 的 source，再由 FPGA 內部同步到 `wr_jtag_wb_mailbox.vhd`。mailbox 對 xwr_core 的 Wishbone slave 發出一個交易，完成後把 32-bit 結果與完成 toggle 放回 instance 1 的 probe。

因此：

- Direct Probe 讀的是 RTL 已經準備好的訊號。
- Wishbone register read 讀的是 xwr_core bus 上某個實際 register 位址。
- 兩者都透過 JTAG 回到 pain，但資料來源與時序完全不同，不能混為一談。

目前 `read_wb_runtime.tcl` 只使用讀取命令，不會透過 mailbox 寫入 WR 設定。

## 2. JTAG instance mapping

以下 mapping 同時由 master/slave RTL 的 `sld_instance_index` 與 `read_wb_runtime.tcl` 的讀取方式確認。

| Instance | RTL instance | 寬度 | 用途 | 欄位格式 |
|---:|---|---:|---|---|
| 0 | `u_wr_sync_probe` | 64 bit | Direct status / PHY probe | 見 2.1 |
| 1 | `u_mailbox_probe` | probe 64 bit、source 96 bit | JTAG Wishbone mailbox | 見第 3 節 |
| 2 | `u_cpu_debug_probe` | 64 bit | CPU PC、reset、fault、im_valid | 見 2.2 |
| 3 | `u_cpu_marker_probe` | 64 bit | boot marker 與 seen | 低 32 bit marker、bit 32 seen |
| 4 | `u_cpu_store_probe` | 64 bit | 最後一次 CPU internal store | 低 32 bit address、高 32 bit data |
| 5 | `u_cpu_store_count_probe` | 64 bit | CPU internal store 次數 | 低 32 bit count |
| 6 | `u_cpu_exception_probe` | 64 bit | CPU exception | 低 32 bit mepc、高 32 bit mcause |
| 7 | `u_clock_activity_probe` | 64 bit | reference、DMTD、recovered RX clock activity | 見 2.3 |

目前 slave RTL 另外保留 instance 8 `u_dco_probe` 供 DCO 唯讀診斷；master RTL 沒有這個共用 instance，而目前 `read_wb_runtime.tcl` 也不讀 instance 8。因此本文件的共同 runtime mapping 以 0 至 7 為準。

### 2.1 Instance 0：status probe

RTL 使用 concatenation 將欄位放入 `sync_probe(63 downto 0)`。最低 16 bit 如下，bit 0 是最低有效位元：

| Bit | 欄位 | 1 的意義 |
|---:|---|---|
| 0 | `si_config_done` | Silicon Interface 設定完成 |
| 1 | `wr_ready` | WR core ready |
| 2 | `core_tm_link_up` | WR timing link up |
| 3 | `core_link_ok` | WR link check OK |
| 4 | `core_tm_time_valid` | WR time valid |
| 5 | `core_pps_valid` | PPS（Pulse Per Second，每秒脈波）有效 |
| 6 | `wr_rx_ready` | WR RX ready |
| 7 | `wr_tx_ready` | WR TX ready |
| 8 | `QSFPA_MOD_PRS_n` | active-low module-present pin 的原始訊號為高 |
| 9 | `QSFPA_INTERRUPT_n` | active-low interrupt pin 的原始訊號為高 |
| 10 | `core_phy_tx_disable` | PHY TX 被 disable |
| 11 | `core_phy_rst` | PHY 在 reset |
| 12 | `si_id_error` | Silicon Interface ID error |
| 13 | `wr_rx_enc_err` | WR RX encoding error |
| 14 | `wr_tx_enc_err` | WR TX encoding error |
| 15 | `CPU_RESET_n` | CPU reset 已解除 |

`MOD_PRS_n` 與 `INTERRUPT_n` 是 active-low 訊號；所以 bit 8 或 bit 9 為 1 只代表該 pin 為高，不能把它直接寫成「module present」或「interrupt asserted」。

其餘欄位：

- bits 16..23：`wr_rx_data`
- bits 24..27：`wr_rx_bitslide`
- bit 28：`wr_rx_data_k`
- bit 29：`wr_debug`
- bit 30：`core_phy_loopen`
- bit 31：固定 0
- bits 32..39：依序為 `wr_rx_locked_to_data`、`wr_rx_locked_to_ref`、`wr_rx_disperr`、`wr_rx_errdetect`、`wr_rx_syncstatus`、`wr_rx_patterndetect`、`wr_rx_pattern_ready`、`wr_rx_runningdisp`
- bits 40..47：`uart_toggle_count`
- bits 48..55：`sfp_scl_toggle_count`
- bits 56..59：`dac_dpll_count[3:0]`
- bits 60..63：`dac_hpll_count[3:0]`

### 2.2 Instance 2 至 6：CPU runtime probes

`read_wb_runtime.tcl` 的解碼方式如下：

| Instance | 低 32 bit | 高位欄位 |
|---:|---|---|
| 2 | `PC[31:0]` | bit 32 `reset`、bit 33 `fault`、bit 34 `im_valid` |
| 3 | `cpu_boot_stage_value` | bit 32 `cpu_boot_stage_seen` |
| 4 | `cpu_last_store_addr` | bits 32..63 `cpu_last_store_data` |
| 5 | `cpu_internal_store_count` | 目前為 0 |
| 6 | `cpu_mepc` | bits 32..63 `cpu_mcause` |

`marker=0xB004` 且 `seen=1` 是目前 firmware 已執行到 bring-up marker 的證據；它不單獨代表 PTP 或 WR synchronization 成功。

### 2.3 Instance 7：clock activity probe

`u_clock_activity_probe` 的 64-bit payload：

| Bits | 欄位 |
|---:|---|
| 0..15 | `ref_activity_count` |
| 16..31 | `dmtd_activity_count` |
| 32..47 | `rx_activity_count` |
| 48 | `ref_activity_sync` |
| 49 | `dmtd_activity_sync` |
| 50 | `rx_activity_sync` |
| 51 | `wr_ready` |
| 52 | `wr_rx_locked_to_ref` |
| 53 | `wr_rx_locked_to_data` |
| 54..63 | 保留值，固定為 `0`；不作為 clock/reset/link 判斷依據 |

counter 持續增加只能證明該 clock domain 有 activity；不能單獨證明 SoftPLL 已 lock。

## 3. Wishbone mailbox 讀取協定

`read_wb_runtime.tcl` 組出的 96-bit source command 與 mailbox RTL 完全對應：

| Bits | 欄位 |
|---:|---|
| 0 | request toggle；每筆命令切換一次 |
| 1 | `wb_we`，目前 runtime script 讀取時為 0 |
| 2..5 | `wb_sel`，目前讀取使用 `0xF` |
| 6..37 | 32-bit Wishbone address |
| 38..69 | 32-bit write data；目前讀取不使用 |

FPGA 回傳的 instance 1 probe 中：

- bits 0..31：Wishbone `dat`
- bit 35：完成 toggle `done_toggle`
- bit 36：mailbox active
- 其他回傳位元是 mailbox 狀態保留欄位，不能當成 register data。

Tcl 會等待 `done_toggle` 等於本次 request toggle 且 `active=0`，再取低 32 bit。若 timeout，該次 register read 沒有有效證據，不應以 0 或 `TIMEOUT` 自行推論硬體狀態。

## 4. Wishbone register map

除非另有註明，以下是 `read_wb_runtime.tcl` 使用的 xwr_core 絕對位址。`0x00100A00` 之後的診斷欄位是 WDIAGS（WR diagnostics）base 加上 `wrc_diags_regs.h` 的 offset；`0x00100B00..0x00100B28` 是本分支額外的 correlation shadow。

### 4.1 Endpoint、clock 與 CPU registers

| 位址 | Script 名稱 | 用途 |
|---:|---|---|
| `0x00100124` | `EP_MAC_H` | Endpoint MAC address 高 32 bit |
| `0x00100128` | `EP_MAC_L` | Endpoint MAC address 低 32 bit |
| `0x00100138` | `EP_DSR` | Endpoint data/status register |
| `0x00100200` | `SPLL_CSR` | SoftPLL control/status |
| `0x00100204` | `SPLL_ECCR` | SoftPLL event/control status |
| `0x00100210` | `SPLL_OCCR` | SoftPLL output channel control/status |
| `0x00100298` | `SPLL_DMTD_REF_EVENTS` | 唯讀：reference DDMTD/deglitcher event count，進入 tag arbitration 前的 `clk_sys` pulse 次數 |
| `0x0010029C` | `SPLL_DMTD_FB_EVENTS` | 唯讀：feedback DDMTD/deglitcher event count，進入 tag arbitration 前的 `clk_sys` pulse 次數 |
| `0x001002A0` | `SPLL_DMTD_REF_SEEN` | 唯讀封裝欄位：bits 31..17 為 reference `clk_sampled` transition counter 低 15 位；bits 16..2 為 reference deglitch accept counter 低 15 位；bit 1 保留；bit 0 保留原本 sticky seen 語意 |
| `0x001002A4` | `SPLL_DMTD_FB_SEEN` | 唯讀封裝欄位：bits 31..17 為 feedback `clk_sampled` transition counter 低 15 位；bits 16..2 為 feedback deglitch accept counter 低 15 位；bit 1 保留；bit 0 保留原本 sticky seen 語意 |
| `0x001002A8` | `SPLL_TAG_PENDING_COUNT` | 唯讀：`tags_req` 非零的 `clk_sys` cycle 次數 |
| `0x001002AC` | `SPLL_TAG_GRANT_COUNT` | 唯讀：`tags_grant_p` 非零的 arbitration grant 次數 |
| `0x001002B0` | `SPLL_DIAG_CURRENT_TICS` | 唯讀：診斷用 `clk_sys` cycle counter；只用來和下列 last-event 欄位比較 |
| `0x001002B4` | `SPLL_DMTD_REF_LAST_TICS` | 唯讀：最近一次 reference DDMTD event 發生時的診斷 tick |
| `0x001002B8` | `SPLL_DMTD_FB_LAST_TICS` | 唯讀：最近一次 feedback DDMTD event 發生時的診斷 tick |
| `0x001002BC` | `SPLL_TAG_REF_LAST_TICS` | 唯讀：最近一次 reference `tags_p` event 發生時的診斷 tick |
| `0x001002C0` | `SPLL_TAG_FB_LAST_TICS` | 唯讀：最近一次 feedback `tags_p` event 發生時的診斷 tick |
| `0x001002C4` | `SPLL_TAG_PENDING_REF_COUNT` | 唯讀：reference request pending 的 `clk_sys` cycle 次數 |
| `0x001002C8` | `SPLL_TAG_PENDING_FB_COUNT` | 唯讀：feedback request pending 的 `clk_sys` cycle 次數 |
| `0x001002CC` | `SPLL_TAG_PENDING_LAST_TICS` | 唯讀：最近一次任一 `tags_req` 非零時的診斷 tick |
| `0x001002D0` | `SPLL_TAG_GRANT_LAST_TICS` | 唯讀：最近一次任一 `tags_grant_p` 非零時的診斷 tick |
| `0x001002D4` | `SPLL_TAG_VALID_LAST_TICS` | 唯讀：最近一次 `tag_valid` 為 1 時的診斷 tick |
| `0x001002D8` | `SPLL_TRR_WRITE_LAST_TICS` | 唯讀：最近一次 tag FIFO write request 成立時的診斷 tick |
| `0x001002DC` | `SPLL_DMTD_STATE` | 唯讀：bits 1..0 reference state、bits 3..2 feedback state、bit 8/9 分別為 reference/feedback DMTD reset-active；bits 17..10 是 reference `stab_cntr(15 downto 8)` bucket，bits 25..18 是 feedback bucket，bit 26/27 是 reference/feedback threshold-reached sticky bit |
| `0x00100300` | `PPS_CR` | PPS generator control/status |
| `0x0010031C` | `PPS_ESCR` | PPS generator extended status/control |
| `0x00100400` | `SYSC_RSTR` | system reset register |
| `0x00100404` | `SYSC_GPSR` | system general-purpose/status register |
| `0x00100D00` | `CPU_RESET` | CPU reset register |
| `0x00100D80` | `CPU_DBGSTAT` | CPU debug status |
| `0x00100D88` | `CPU_DBGREADY` | CPU debug ready |
| `0x00100D90` | `CPU_MBX` | CPU mailbox |

這些 register 是 Wishbone read，不是 instance 0 的 Direct Probe。單次讀值要搭配 CPU instance 2、marker instance 3 與多次採樣解讀。

其中 `SPLL_DMTD_*` 是本 Step 4 診斷用的唯讀觀測值：它們只計數
`dmtd_with_deglitcher` 已經同步到 `clk_sys`、但尚未進入 SoftPLL tag
arbitration 的 event。`*_SEEN` 在第一次 event 後維持 1，直到 FPGA reset；這些
register 不會讀取或消費 TRR FIFO，也不會寫入 SoftPLL 設定。若 event count/seen
為 0，只能表示此觀測點沒有看到 event，不能單獨判定 PHY、clock source 或
DDMTD polarity 的根因。

`SPLL_TAG_PENDING_COUNT` 與 `SPLL_TAG_GRANT_COUNT` 用來區分 arbitration：前者
表示至少有 request pending，後者表示 round-robin grant 曾經發生；兩者都不是
TRR FIFO write count，必須和既有 `TAG_VALID`、`TRR_WRITE` 一起解讀。

新增的 `*_LAST_TICS` 欄位是 sticky last-event timestamp，不是 WR global time，也
不是 PPS timestamp；它們只是用 `clk_sys` cycle counter 記錄「最後一次看到事件」的
位置。把 `SPLL_DIAG_CURRENT_TICS` 減去某個 `*_LAST_TICS`，可以判斷事件是剛剛還在
發生，還是只在開機早期發生過。`SPLL_TAG_PENDING_REF_COUNT` 與
`SPLL_TAG_PENDING_FB_COUNT` 則把 request activity 分成 reference 與 feedback channel。
這些欄位只供分類 event source、request、grant、valid、TRR write 的停點，不會驅動
SoftPLL 狀態機、DAC 或 SI5340。

`SPLL_DMTD_STATE` 的 state 編碼為 `0=WAIT_STABLE_0`、`1=WAIT_EDGE`、
`2=GOT_EDGE`；這是 `dmtd_with_deglitcher` 的 source-defined state，並已同步到
`clk_sys` 後才提供給 Wishbone。reset-active bit 只表示 DMTD reset input 目前為低，
不代表 reset 的歷史次數。`stab_cntr` bucket 是目前 stability counter 的高 8 位，
不是完整 16-bit 計數值，只用來辨識 counter 是否有粗略累積活動。threshold-reached
bit 只在 DMTD clock domain 中於 counter 等於既有 threshold 時設為 1，直到該 DMTD
reset domain reset。本次沒有改 threshold 或 deglitch state transition。

### 4.2 WDIAGS standard / current bring-up map

| 位址 | 目前名稱 | Packing / 說明 |
|---:|---|---|
| `0x00100A00` | `WDIAGS_VER` | version，現行 firmware 寫入 2 |
| `0x00100A04` | `WDIAGS_CTRL` | bit 0 `DATA_VALID`；bit 8 `DATA_SNAPSHOT` |
| `0x00100A08` | `WDIAGS_SSTAT` | bit 0 WR mode；bits 8..11 servo state |
| `0x00100A0C` | `WDIAGS_PSTAT` | bit 0 link；bit 1 `spll_check_lock(0)` 結果 |
| `0x00100A10` | `WDIAGS_PTP` | PPSI PTP state：4 listening、6 master、9 slave |
| `0x00100A14` | `WDIAGS_ASTAT` | auxiliary clock state bitmap |
| `0x00100A18` | `WDIAGS_TX` | `minic_get_stats()` 的 TX frame counter |
| `0x00100A1C` | `WDIAGS_RX` | `minic_get_stats()` 的 RX frame counter |
| `0x00100A20` | `WDIAGS_SEC_H` | local time seconds 高 32 bit |
| `0x00100A24` | `WDIAGS_SEC_L` | local time seconds 低 32 bit |
| `0x00100A28` | `WDIAGS_NS` | local time nanoseconds |
| `0x00100A2C` | `WDIAGS_MU_H` | round-trip delay `mu` 高 32 bit |
| `0x00100A30` | `WDIAGS_MU_L` | round-trip delay `mu` 低 32 bit |
| `0x00100A34` | `WDIAGS_DMS_H` | master-slave delay `dms` 高 32 bit |
| `0x00100A38` | `WDIAGS_DMS_L` | master-slave delay `dms` 低 32 bit |
| `0x00100A3C` | `WDIAGS_ASYM` | link asymmetry，ps |
| `0x00100A40` | `WDIAGS_CKO` | clock offset，ps |
| `0x00100A44` | `WDIAGS_SETP` | phase setpoint，ps |
| `0x00100A48` | `WDIAGS_UCNT` | PPSI servo update counter |
| `0x00100A4C` | `WDIAGS_TEMP` | board temperature；DE5a 無溫度感測器時是 WR state shadow |
| `0x00100A50` | `WR_SIGNAL_REJECT` | current DE5a firmware 的 WR signal reject shadow |
| `0x00100A54` | `WDIAGS_PTP_RX` | PPSI-level PTP RX counter |
| `0x00100A58` | `WDIAGS_PTP_TX` | PPSI-level PTP TX counter |
| `0x00100A5C` | `WDIAGS_PTP_META` | bits 0..7 PTP state；8..15 `pdstate`；16..23 WR extension state；24..31 configured WRC mode |
| `0x00100A60` | `WDIAGS_RXERR` | MiniNIC RX error counter |
| `0x00100A64` | `WR_RX_SIGNAL_DEBUG` | current WR signaling RX message/counter shadow |
| `0x00100A68` | `WR_TX_SIGNAL_DEBUG` | current WR signaling TX message/counter shadow |
| `0x00100A6C` | `WR_FAILURE_DEBUG` | current firmware 的 WR failure shadow；standard schema 原名為 servo restart count |
| `0x00100A70` | `WDIAGS_SLIDE` | transceiver bitslide |
| `0x00100A74` | `WDIAGS_PTP_TYPES` | 四個 8-bit RX message-type counter，見 4.3 |
| `0x00100A78` | `WDIAGS_FOREIGN_META` | foreign master / parent metadata，見 4.3 |
| `0x00100A7C` | `WDIAGS_FILTER_META` | PTP prefilter counters，見 4.3 |
| `0x00100A80` | `WDIAGS_PARSE_META` | frame/announce parse counters 與 parent flags，見 4.3 |
| `0x00100A84` | `WDIAGS_SPLL_HY` | SoftPLL helper DAC shadow |
| `0x00100A88` | `WDIAGS_SPLL_MY` | SoftPLL main DAC shadow |

**重要區分：** `WDIAGS_TX` / `WDIAGS_RX` 是 `minic_get_stats()` 回報的 MiniNIC frame-level counter，不是 PTP 封包計數。`WDIAGS_PTP_RX` / `WDIAGS_PTP_TX` 是 `ppi->ptp_rx_count` / `ppi->ptp_tx_count` 的 PPSI-level PTP counter。兩組數字的計數單位不同，不能互相比較成同一種 packet count。

|  值 | PTP State      | 直覺意義                                      |
| -: | -------------- | ----------------------------------------- |
|  1 | `INITIALIZING` | PTP port 正在初始化                            |
|  2 | `FAULTY`       | PTP 發生錯誤，正常運作暫停                           |
|  3 | `DISABLED`     | PTP port 被停用                              |
|  4 | `LISTENING`    | 正在聽 Announce、建立 Foreign Master、等待 BMCA 決策 |
|  5 | `PRE_MASTER`   | 已準備成為 Master，但還在過渡等待期                     |
|  6 | `MASTER`       | 正式成為 PTP Master                           |
|  7 | `PASSIVE`      | 有參與 PTP/BMCA，但此 port 不當 Master 也不當 Slave  |
|  8 | `UNCALIBRATED` | 已被選成 Slave，但時間同步/servo 尚未準備完成             |
|  9 | `SLAVE`        | PTP state machine 正式進入 Slave              |


### 4.3 PTP 與 parent metadata packing

以下定義直接來自目前 `vendor/wrpc-sw/lib/task-diags.c` 的 bit shift；各 counter 每次 firmware diagnostic refresh 寫入，且每個 byte 只保留低 8 bit，因此長時間執行可能回捲。

#### `WDIAGS_PTP_META`（`0x00100A5C`）

由 `wdiags_write_ptp_debug()` 寫入：

```text
bits  0.. 7 = ppi->state
bits  8..15 = ppi->pdstate
bits 16..23 = ppi->extState
bits 24..31 = wrc_ptp_get_mode()
```

`WDIAGS_PTP` 與 `PTP_META` 的低 byte 都可對應 PPSI PTP state，但 `PTP_META` 還保留 parent-dataset state、WR extension state 與 configured WRC mode。

#### `WDIAGS_PTP_TYPES`（`0x00100A74`）

```text
bits  0.. 7 = RX Sync count
bits  8..15 = RX Announce count
bits 16..23 = RX Follow_Up count
bits 24..31 = RX Signaling count
```

這是依 PTP header message type 分類的接收計數，不是所有 Ethernet frame 的計數。

#### `WDIAGS_FOREIGN_META`（`0x00100A78`）

```text
bits  0.. 7 = frgn_rec_num
bits  8..15 = frgn_rec_best；沒有最佳候選時以 0xFF 表示
bits 16..23 = parentDetection（WR extension）
bits 24..31 = parentWrConfig（WR extension）
```

例如 `0x03000001` 表示 foreign record count 為 1、best index 為 0、parent detection 為 0、parent WR config 為 3。它表示 Slave 已看見並選到 foreign master record，並讀到父節點 WR configuration；它不等於 SoftPLL 已 lock。

#### `WDIAGS_FILTER_META`（`0x00100A7C`）

```text
bits  0.. 7 = wrong-domain prefilter count
bits  8..15 = alternate-master prefilter count
bits 16..23 = same-port prefilter count
bits 24..31 = same-clock prefilter count
```

#### `WDIAGS_PARSE_META`（`0x00100A80`）

```text
bits  0.. 7 = PTP frame parse error count
bits  8..15 = RX Announce processed count
bits 16..23 = RX Announce added count
bits 24      = parentIsWRnode
bit  25      = parentWrModeOn
bit  26      = parentCalibrated
bits 27..31  = 保留
```

`PARSE_META` 的高三個 parent flag 要與 `FOREIGN_META` 一起讀；只有看到 flag 並不代表 servo 已達到 `TRACK_PHASE` 或 SoftPLL lock。

### 4.4 目前 firmware 額外的唯讀 SoftPLL shadow

這些欄位由 `wdiags.c` 寫入，是觀測用 shadow；不會寫回 SoftPLL 控制邏輯。現行 `read_wb_runtime.tcl` 沒有逐一讀取它們。

| 位址範圍 | 內容 |
|---:|---|
| `0x00100A8C..0x00100AA0` | WR lock result、poll/unlocked/calibration-fail/enable counters、SoftPLL sequence shadow |
| `0x00100AA4..0x00100ACC` | SoftPLL hardware registers、DAC、helper/main lock detector shadow |
| `0x00100AD0..0x00100AF4` | reference/tag count、helper PI、state visit/transition、last state、IRQ mask/status |
| `0x00100AF8..0x00100AFC` | hardware `TAG_VALID_COUNT` 與 `TRR_WRITE_COUNT` |
| `0x00100B00` | `HELPER_LAST_TAG`：helper 最新一次接受的 tag |
| `0x00100B04` | `HELPER_EXPECTED_TAG`：helper 當次 setpoint |
| `0x00100B08` | `HELPER_PRECLAMP_ERROR`：clamp 前的 signed error |
| `0x00100B0C` | `HELPER_TAG_DELTA`：相鄰 tag 的 delta |
| `0x00100B10` | `HELPER_TAG_SOURCE`：tag source |
| `0x00100B14` | `HELPER_EXPECTED_DELTA`：預期的每週期 delta |
| `0x00100B18` | `HELPER_UPDATE_COUNT`：helper update 次數 |
| `0x00100B1C` | `HELPER_P_ADDER`：tag wraparound 累加器 |
| `0x00100B20` | `HELPER_TAG_D0`：前一個 tag |
| `0x00100B24` | `HELPER_P_SETPOINT`：下一個預期 tag |
| `0x00100B28` | `HELPER_REF_SRC`：helper reference source |

這些 `0x00100B00..0x00100B28` 欄位需要 private WDIAGS 的 peripheral window 至少涵蓋 `0x000..0x1FF`。目前 private WDIAGS base 是 `0x00100A00`，並且將 `0x00100B00` 保留給 correlation shadow；若實際 bitstream 仍使用舊的 `0x000..0x0FF` SDB window，讀值會落到後續 peripheral，造成欄位 alias；此時不能拿來判斷 helper 或 SoftPLL 行為。

若要解讀這段，必須同時固定 firmware commit、RTL commit 與實際 SOF；不能只依地址名稱猜測。

## 5. 如何從 JTAG 證明 Endpoint / MiniNIC / PTP packet path

### 5.1 建議判斷順序

1. Instance 0：`core_tm_link_up=1`、`core_link_ok=1`，且沒有持續 `wr_rx_enc_err`。
2. CPU instances：`CPU_RESET_n=1`、`fault=0`、`im_valid=1`、marker `0xB004 seen=1`，表示觀測 firmware 確實在執行。
3. Endpoint：兩片 `EP_MAC_H/EP_MAC_L` 形成不同 MAC，確認不是兩個節點使用同一個 clock identity。
4. MiniNIC：`WDIAGS_TX/WDIAGS_RX` 隨 frame traffic 增加，`WDIAGS_RXERR` 沒有異常增加。
5. PPSI/PTP：`WDIAGS_PTP` 進入預期 state，且 `WDIAGS_PTP_RX/WDIAGS_PTP_TX` 隨時間增加；必要時再看 `PTP_TYPES`、foreign 與 parse metadata。
6. 只有另外看到 `WDIAGS_PSTAT bit 1=1`、Slave servo state 前進，以及 `status_probe bit 4=1`，才可以進一步討論 SoftPLL lock 與 time valid。

### 5.2 2026-08-19 實測範例

以下數值是使用者在 2026-08-19 提供的同一次 runtime JTAG 讀取：

| 節點 | MODE | PTP state | MAC | PTP RX | PTP TX | FOREIGN_META |
|---|---:|---:|---|---:|---:|---:|
| Master | 2 | 6（PPS_MASTER） | `02:00:22:33:44:01` | `0x11042` | `0x267C0` | 未提供 |
| Slave | 3 | 9（PPS_SLAVE） | `02:00:22:33:44:02` | `0x267BF` | `0x062C2` | `0x03000001` |

這組證據支持以下結論：

- 兩端 Endpoint identity 不同，Master/Slave role 在 runtime 可辨識。
- Master 已進 PPS_MASTER，Slave 已進 PPS_SLAVE。
- 兩端 PPSI-level PTP RX/TX counter 都已有活動，Slave 也已取得一筆 foreign master metadata。
- 因此 **Step 2：Endpoint / MiniNIC / PTP packet path 可視為 PASS**。

但這組數值**不代表**：

- SoftPLL 已 lock；
- Slave `WDIAGS_PSTAT bit 1` 已為 1；
- Slave `time_valid` 已為 1；
- 兩端已完成可宣稱的 White Rabbit sub-ns synchronization。

### 5.3 執行唯讀 runtime script

在 pain 上：

```bash
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl
```

這個 script 會列出兩張 JTAG hardware 的 direct probes 與 Wishbone reads。若要做時間序列，請使用既有的 read-only timeseries script，並保存完整原始輸出；不要把一次讀取結果改寫成長時間穩定性結論。

## 6. Source / SOF provenance 注意事項

目前恢復成功的硬體實驗使用 historical `c88cc05` clean SOF，不是目前 branch HEAD 的 fresh build。特別是 firmware/RTL 後來增加過診斷欄位，因此不能直接用最新 branch 的 register mapping 去解釋所有 historical bitstream 欄位。

目前保存的 c88cc05 clean artifact：

| 節點 | SOF SHA256 | programmer checksum | MIF SHA256 |
|---|---|---|---|
| Master | `f565c0a209cf1567f048df25b0f3312e9db4bf45a3fc46914a87efefbf2b1abf` | `0x30A0A429` | `0705b4be17ed742fbd32860de8a8cbbebf91285c71e0e54465516a59e1b2dc7a` |
| Slave | `926d4a57f50dce0e39e437af7eba164a8ca1ec327c989b59d5f6480a038eb2cb` | `0x30A5A091` | `dbc19106386ebca90f3460309a8b41f09e5bde0694b91484e527ed4a56ef9d35` |

每一份 runtime log 至少要同時記錄：

1. 實際燒錄的 Master/Slave SOF SHA256 與 programmer checksum。
2. 產生 SOF 的 source commit、branch、Quartus 版本。
3. 使用的 `read_wb_runtime.tcl` commit，或至少保存該 script 的 Git blob SHA256。
4. JTAG hardware name、讀取時間、完整原始輸出。

只有這樣才能分辨「硬體沒有改變但 decode script 改了」與「實際 bitstream 改變」這兩種不同情況。

## 7. 解讀限制

- `DATA_VALID` 是 firmware 更新資料框的有效標記，不保證多個 Wishbone register 在同一個硬體 cycle 原子取樣。
- 一次讀取失敗、mailbox timeout 或值為 0，不可直接推論 PHY/CPU/PTP 已停止；應保存 raw output 並重讀。
- `WDIAGS_PTP_RX/TX` 是 PPSI counter；`WDIAGS_TX/RX` 是 MiniNIC frame counter；不要用錯欄位。
- `FOREIGN_META=0x03000001` 是 parent discovery 的證據，不是 SoftPLL lock 的證據。
- `PSTAT.locked=1`、servo state、`time_valid=1` 與 PPS 外部量測是不同層級的證據，必須分開報告。
