# JTAG 執行期暫存器觀測

## 用途

`quartus/jtag_runtime_diag` 是只增加 JTAG Wishbone mailbox 的診斷版本。mailbox 讓 pain 主機可以透過 Quartus 17 的 JTAG（Joint Test Action Group，聯合測試行動組）讀取 `xwr_core` 既有暫存器；它不會參與 QSFP 資料傳輸，也不會成為 White Rabbit 的同步線。

## 固定介面

| JTAG instance | 用途 |
|---:|---|
| 0 | 既有 64-bit WR 狀態 probe |
| 1 | JTAG Wishbone mailbox，送出一次讀取命令並回收 32-bit 結果 |

只有燒錄 `jtag_runtime_diag` 的 SOF 時，instance 1 才存在。正式 `rs422_uart_diag` SOF 沒有這個介面，執行 mailbox 腳本出現 `No In-System Sources and Probes instance was found` 是預期結果。

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
| `0x00100960` | `WDIAGS_RXERR` | WRPC RX 錯誤計數 |
| `0x0010096C` | `WDIAGS_RESTART` | 伺服器重新啟動次數 |
| `0x00100970` | `WDIAGS_SLIDE` | Transceiver bitslide 值 |
| `0x00100984` / `0x00100988` | `WDIAGS_SPLL_HY` / `WDIAGS_SPLL_MY` | SoftPLL 輔助與主 DAC 值 |

`WDIAGS_PSTAT` 的 bit 0 是 link，bit 1 是 SoftPLL lock；`WDIAGS_CTRL` 的 bit 0 是韌體填入資料是否有效。這些欄位需要搭配兩次、間隔約一秒以上的讀值觀察，不能只看單次快照。

## 讀取方式

在 pain 上執行：

```bash
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl
```

先看 `status_probe` 的低 16-bit 是否仍是 `0x82CF`，再看 PPS、SoftPLL 與 CPU 狀態。這個順序可以避免把 JTAG 介面問題誤判成 WR 光路問題。
