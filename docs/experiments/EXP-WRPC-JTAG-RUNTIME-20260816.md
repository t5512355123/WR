# 實驗：WRPC 執行期 JTAG 觀測介面

## 實驗名稱

`EXP-WRPC-JTAG-RUNTIME-20260816`：在不改變 QSFP-A White Rabbit 光路的前提下，建立 JTAG Wishbone mailbox，讀取 WRPC 執行期暫存器。

## 為了驗證什麼

本實驗要分辨兩個不同問題：

1. QSFP-A lane 0 的 PHY（Physical Layer，實體層）與 PCS（Physical Coding Sublayer，實體編碼子層）是否仍能建立 link。
2. WRPC（White Rabbit PTP Core，White Rabbit 精密時間同步核心）的 CPU、PTP（Precision Time Protocol，精密時間協定）與 SoftPLL 是否真的進入執行期。

原本正式 SOF 只有 64-bit 狀態 probe，沒有 JTAG Wishbone mailbox，因此只能看到 `0x82CF`，無法進一步讀取 PPS、SoftPLL 或 CPU 狀態。

## 目前已知基準

2026-08-16 以保存的正式 SOF 完成雙板燒錄：

```text
Master checksum: 0x3088011E
Slave  checksum: 0x308FFC95
兩片皆 Configuration succeeded / Successfully performed operation(s)
```

燒錄後 JTAG probe：

```text
Master: 000102E336BC82CF
Slave : 000102E136BC82CF
```

低 16-bit `0x82CF` 代表兩端目前都有 `phy_ready=1`、`tm_link_up=1`、`link_ok=1`、`rx_enc_err=0`、`tx_enc_err=0`；其中 `time_valid=0`、`pps_valid=0`，所以尚不能宣稱 White Rabbit 時間同步完成。

正式版本執行 Wishbone 讀取的結果：

```text
Master: ERROR: No In-System Sources and Probes instance was found.
Slave : ERROR: No In-System Sources and Probes instance was found.
```

這是介面不存在的證據，不是 WRPC 暫存器內容。

## 改了什麼

新增獨立的 `quartus/jtag_runtime_diag` 診斷工程：

- 由正式 Master/Slave top 複製出診斷 top。
- 保留 QSFP-A lane 0、`g_use_simple_wa => true`、125 MHz 參考時鐘、124.992 MHz DMTD（Digital Dual Mixer Time Difference，數位雙混頻時間差）時鐘與 SI5340 控制。
- 將 `xwr_core` 既有 Wishbone slave 介面接到 `wr_jtag_wb_mailbox`。
- 只增加 JTAG instance 1；instance 0 的既有 64-bit 狀態 probe 不變。
- 不新增 RS422、不新增 Common Reset、不新增 Common START，也不把 JTAG latency 放進 WR 同步路徑。
- 新增 `scripts/jtag/read_wb_runtime.tcl`，只讀取 PPS、SoftPLL、系統與 CPU debug 狀態，不寫入 CPU reset 或其他控制暫存器。

## 結果

本節在 pain 完成 Quartus 17 編譯與診斷版燒錄後填入。最低接受條件是：

1. Master/Slave 都 `Full Compilation was successful`。
2. 兩片診斷版都 `Configuration succeeded`。
3. JTAG instance 列出 instance 0 與 instance 1。
4. `read_wb_runtime.tcl` 能從兩片讀回 `PPS_CR`、`PPS_ESCR`、`SPLL_CSR`、`SPLL_ECCR`、`SPLL_OCCR`、`SYSC_RSTR`、`SYSC_GPSR` 與 CPU debug 狀態。

## pain terminal log

建置與燒錄的完整輸出保存於 pain 的：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-JTAG-RUNTIME-20260816/
```

實驗完成後，將在此段貼上最小必要輸出，保留完整 log 在上述目錄。

## 怎麼看待這個結果

如果 mailbox 能成功讀回 WRPC 暫存器，下一步才可以合理判斷問題是在 firmware/PTP/SoftPLL，而不是繼續盲目修改 QSFP lane、polarity 或 pre-emphasis。

如果 mailbox 版仍只有 `0x82CF` 且 `time_valid=0`、`pps_valid=0`，代表 PHY/link 已成立但同步尚未完成；這時要依暫存器與 PTP/SoftPLL 狀態決定下一個單一變因。

如果診斷版讓 link 從 `0x82CF` 退化，必須立即恢復正式基準 SOF，並把問題視為診斷介面整合錯誤，而不是拿診斷結果修改光路。

## 成功判定限制

即使 `time_valid=1`、`pps_valid=1`，也只能先宣稱 WRPC 內部同步狀態有效。若要宣稱實體次奈秒同步，仍要依官方校正流程量測兩端 1-PPS（每秒脈衝）上升緣差，並保存校正資料與量測證據。
