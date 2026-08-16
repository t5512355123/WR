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

## 讀取方式

在 pain 上執行：

```bash
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl
```

先看 `status_probe` 的低 16-bit 是否仍是 `0x82CF`，再看 PPS、SoftPLL 與 CPU 狀態。這個順序可以避免把 JTAG 介面問題誤判成 WR 光路問題。
