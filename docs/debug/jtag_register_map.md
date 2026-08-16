# JTAG 執行期暫存器觀測

## 用途

`quartus/jtag_runtime_diag` 是只增加 JTAG Wishbone mailbox 的診斷版本。mailbox 讓 pain 主機可以透過 Quartus 17 的 JTAG（Joint Test Action Group，聯合測試行動組）讀取 `xwr_core` 既有暫存器；它不會參與 QSFP 資料傳輸，也不會成為 White Rabbit 的同步線。

## 固定介面

| JTAG instance | 用途 |
|---:|---|
| 0 | 既有 64-bit WR 狀態 probe |
| 1 | JTAG Wishbone mailbox，送出一次讀取命令並回收 32-bit 結果 |
| 7 | 只讀時鐘域活動 probe：reference、DMTD 與 transceiver RX clock |

只有燒錄 `jtag_runtime_diag` 的 SOF 時，instance 1 才存在。正式 `rs422_uart_diag` SOF 沒有這個介面，執行 mailbox 腳本出現 `No In-System Sources and Probes instance was found` 是預期結果。

instance 7 的 64-bit probe 僅用於診斷：低 16 位元是 `QSFPA_REFCLK_p` 活動計數，bits 16..31 是 `QSFPB_REFCLK_p` 活動計數，bits 32..47 是 transceiver `wr_rx_clk` 活動計數；bits 48..53 是三個同步後 toggle 與 PHY ready/lock 狀態。每個時鐘域每 256 個 clock 週期翻轉一次標記，再由 50 MHz 系統時鐘同步與計數。此 probe 不寫入任何 WR 控制暫存器，也不參與同步。

## 目前使用的 WRPC 暫存器

| 位址 | 名稱 | 讀取意義 |
|---:|---|---|
| `0x00100300` | `PPS_CR` | PPS（Pulse Per Second，每秒脈衝）控制狀態 |
| `0x0010031C` | `PPS_ESCR` | 外部同步與時間有效相關狀態 |
| `0x00100200` | `SPLL_CSR` | SoftPLL（軟體鎖相迴路）控制/狀態 |
| `0x00100204` | `SPLL_ECCR` | SoftPLL 外部時鐘控制 |
| `0x00100210` | `SPLL_OCCR` | SoftPLL 輸出通道控制 |
| `0x00100400` | `SYSC_RSTR` | WRPC 系統 reset 狀態 |
| `0x00100404` | `SYSC_GPSR` | WRPC 一般狀態 |
| `0x00100B80` | `CPU_DBGSTAT` | uRV CPU debug 狀態 |
| `0x00100B88` | `CPU_DBGREADY` | uRV CPU debug ready 狀態 |
| `0x00100B90` | `CPU_MBX` | uRV CPU mailbox 狀態 |
| `0x00100B00` | `CPU_RESET` | uRV CPU 內部 reset 暫存器；bit 0 為 1 時代表 CPU 被保持在 reset |

## WRPC 內建診斷區

WRPC（White Rabbit PTP Core，White Rabbit 精密時間同步核心）本身有一個由韌體每秒更新的診斷區。它位於 `0x00100900`，不是額外加入同步路徑的自訂訊號。以下位址是診斷腳本目前讀取的欄位：

| 位址 | 名稱 | 讀取意義 |
|---:|---|---|
| `0x00100900` | `WDIAGS_VER` | 診斷區版本，正常 WRPC 為 2 |
| `0x00100904` | `WDIAGS_CTRL` | 診斷資料是否有效 |
| `0x00100908` | `WDIAGS_SSTAT` | WR 模式與伺服器狀態 |
| `0x0010090C` | `WDIAGS_PSTAT` | Link 與 SoftPLL lock 狀態 |
| `0x00100910` | `WDIAGS_PTP` | PTP/WR 協定狀態 |
| `0x00100918` / `0x0010091C` | `WDIAGS_TX` / `WDIAGS_RX` | PTP 封包傳送與接收計數 |
| `0x00100920` / `0x00100924` / `0x00100928` | `WDIAGS_SEC_H` / `WDIAGS_SEC_L` / `WDIAGS_NS` | WR 本地 TAI 時間 |
| `0x0010092C` / `0x00100930` | `WDIAGS_MU_H` / `WDIAGS_MU_L` | 往返延遲的皮秒值 |
| `0x00100934` / `0x00100938` | `WDIAGS_DMS_H` / `WDIAGS_DMS_L` | Master-Slave 延遲的皮秒值 |
| `0x0010093C` | `WDIAGS_ASYM` | 連線非對稱延遲 |
| `0x00100940` | `WDIAGS_CKO` | 時鐘偏移 |
| `0x00100944` | `WDIAGS_SETP` | 相位設定值 |
| `0x00100948` | `WDIAGS_UCNT` | 伺服器更新計數 |
| `0x0010094C` | `WDIAGS_TEMP` | 診斷版啟動階段標記；正式溫度感測器啟用時回復為溫度欄位 |
| `0x00100964` | `WR_RX_SIGNAL_DEBUG` | 高 16 位為最後收到的 WR signaling message ID，低 16 位為成功解析計數 |
| `0x00100968` | `WR_TX_SIGNAL_DEBUG` | 高 16 位為最後送出的 WR signaling message ID，低 16 位為成功送出計數 |
| `0x00100960` | `WDIAGS_RXERR` | WRPC RX 錯誤計數 |
| `0x0010096C` | `WR_HANDSHAKE_FAIL_DEBUG` | 高 8 位為失敗前 role，中間 8 位為失敗前 WR state，低 16 位為 failure 計數；本診斷版不使用原 restart 欄位 |
| `0x0010098C` | `WR_LOCK_RESULT_DEBUG` | 低 8 位為最後 locking_poll 結果（0=locked、1=unlocked、2=t24p calibration fail），bit8 為當下 spll_check_lock 結果 |
| `0x00100990` | `WR_LOCK_POLL_COUNT` | `locking_poll()` 累計呼叫次數 |
| `0x00100994` | `WR_LOCK_UNLOCKED_COUNT` | `spll_check_lock(0)=false` 的累計次數 |
| `0x00100998` | `WR_LOCK_CALIBRATION_FAIL_COUNT` | `calib_t24p()` 失敗累計次數 |
| `0x0010099C` | `WR_LOCK_ENABLE_COUNT` | `locking_enable()` 累計呼叫次數 |
| `0x001009A0` | `WR_SPLL_STATE_DEBUG` | 低 8 位 `seq_state`、次 8 位 `align_state`、次 8 位 SoftPLL mode、最高 8 位 `delock_count` |
| `0x001009A4` | `WR_SPLL_OCER_DEBUG` | SoftPLL output tag enable register 的唯讀 shadow |
| `0x001009A8` | `WR_SPLL_RCER_DEBUG` | SoftPLL reference tag enable register 的唯讀 shadow |
| `0x001009AC` | `WR_SPLL_OCCR_DEBUG` | SoftPLL output channel control/status 的唯讀 shadow |
| `0x001009B0` | `WR_SPLL_TRR_CSR_DEBUG` | tag receiver FIFO 狀態；bit 17 為 empty |
| `0x001009B4` / `0x001009B8` | `WR_SPLL_DAC_HPLL_DEBUG` / `WR_SPLL_DAC_MAIN_DEBUG` | helper/main DAC 輸出的唯讀 shadow |
| `0x001009BC` | `WR_SPLL_HELPER_LOCKDET` | bit0 helper locked、bit1 lock_changed、bits8..15 ref channel、bits16..31 lock counter |
| `0x001009C0` | `WR_SPLL_HELPER_LIMITS` | 低 16 位 threshold、高 16 位 lock_samples |
| `0x001009C4` | `WR_SPLL_MAIN_LOCKDET` | main enabled/locked/frequency locked/phase locked 與頻率、相位 lock counter |
| `0x001009C8` / `0x001009CC` | `WR_SPLL_MAIN_FREQ_LIMITS` / `WR_SPLL_MAIN_PHASE_LIMITS` | main 頻率/相位 lock detector threshold 與 lock_samples |
| `0x001009D0` / `0x001009D4` | `WR_SPLL_REF_COUNT` / `WR_SPLL_TAG_COUNT` | SoftPLL 自 `spll_init()` 後處理的 reference/main tag 累計數 |
| `0x001009D8` / `0x001009DC` | `WR_SPLL_HELPER_ERROR` / `WR_SPLL_HELPER_OUTPUT` | helper PI 最近一次 error (`pi.x`) 與輸出 (`pi.y`) |
| `0x001009E0` | `WR_SPLL_STATE_VISIT_MASK` | sticky sequence state visit mask；bit N 表示曾經進入 state N |
| `0x001009E4` / `0x001009E8` | `WR_SPLL_STATE_TRANSITIONS` / `WR_SPLL_LAST_STATE` | sequence state transition 累計次數與最後 state |
| `0x001009EC` | `WR_SPLL_IRQ_COUNT` | SoftPLL interrupt handler 進入次數；唯讀 shadow，不代表每次 IRQ 都含有有效 tag |
| `0x001009F0` / `0x001009F4` | `WR_SPLL_IRQ_MASK` / `WR_SPLL_IRQ_STATUS` | SoftPLL EIC 的 interrupt mask/status 唯讀 shadow；不寫入、不清除 status |
| `0x00100970` | `WDIAGS_SLIDE` | Transceiver bitslide 值 |
| `0x00100984` / `0x00100988` | `WDIAGS_SPLL_HY` / `WDIAGS_SPLL_MY` | SoftPLL 輔助與主 DAC 值 |

單一 session 的時間序列腳本會同時讀取 `SPLL_CSR/ECCR/OCCR` 與 `WDIAGS_SPLL_HY/MY`。這些欄位目前只作觀測，不能單獨當成 SoftPLL lock；仍要搭配 `WDIAGS_PSTAT` bit 1、`WDIAGS_SSTAT` 的 state field 與 PPS/time-valid 欄位。

`WDIAGS_PSTAT` 的 bit 0 是 link，bit 1 是 SoftPLL lock；`WDIAGS_CTRL` 的 bit 0 是韌體填入資料是否有效。這些欄位需要搭配兩次、間隔約一秒以上的讀值觀察，不能只看單次快照。

## 讀取方式

在 pain 上執行：

```bash
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl
```

先看 `status_probe` 的低 16-bit 是否仍是 `0x82CF`，再看 PPS、SoftPLL 與 CPU 狀態。這個順序可以避免把 JTAG 介面問題誤判成 WR 光路問題。

## 唯讀時間序列觀測

若要觀察 Slave 是否從 servo 初期逐步進入 `TRACK_PHASE`，可在 pain 上使用：

```bash
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_timeseries.tcl 60 1000 \
  2>&1 | tee /home/b10504072/04_WR/build/artifacts/EXP-WRPC-SERVO-TIMESERIES-20260816.log
```

其中 `60` 是完整 snapshot 次數，`1000` 是兩次 snapshot 之間的最小等待毫秒數。每次 snapshot 都會重新讀取兩片 JTAG mailbox，輸出 `WDIAGS_SSTAT`、`WDIAGS_PSTAT`、`WDIAGS_PTP`、時間有效位元、`DMS`、`CKO`、`SETP`、`UCNT` 與 parent/foreign metadata。

這個腳本只讀取既有 register，不會寫入 WR 設定，也不會改變 QSFP、PHY、PTP 或 SoftPLL 控制流程。需要注意的是，一次完整的 JTAG snapshot 本身也需要時間，因此 `gap_ms` 是兩次 snapshot 之間的等待時間，不保證 sample timestamp 恰好相隔一秒。

## 單一 JTAG session 版本

若要避免每個 sample 重新建立 source probe，可使用：

```bash
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_timeseries_session.tcl 60 1000 3 \
  2>&1 | tee /home/b10504072/04_WR/build/artifacts/EXP-WRPC-SERVO-TIMESERIES-SESSION-20260816.log
```

這個版本每張板只開啟一次 JTAG source probe，並在每列輸出 `CTRL_BEGIN`、`CTRL_END`、`FRAME_VALID` 與 retry 次數。只有兩端資料有效位都為 1 且值一致時，該列才標記為有效；遇到 timeout 或 mailbox 欄位不是 32-bit 十六進位值時，最多重讀 3 次，仍失敗才標記為 invalid。這是讀取證據的品質標記，不代表 FPGA 內部 register 更新本身是硬體原子 snapshot。

目前腳本另以相同方式對父節點欄位做 block 雙讀：

```text
PARENT_BLOCK_VALID =
    (PTP_META_A == PTP_META_B) &&
    (FOREIGN_META_A == FOREIGN_META_B) &&
    (PARSE_META_A == PARSE_META_B)
```

只有 `PARENT_BLOCK_VALID=1` 才把 `foreign_count`、`foreign_best`、`parentDetection`、`parentWrConfig`、`parentIsWRnode`、`parentWrModeOn` 與 `parentCalibrated` 列入 accepted frame。這是 host-side 觀測一致性檢查，不會改變 WRPC 的 parent selection 或 servo 行為。
