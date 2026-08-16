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

本實驗已在 pain 完成 Quartus 17 編譯、雙板燒錄與 JTAG 讀取。結果如下：

1. Master/Slave 都完成 Quartus 17 編譯。因為本工程的時序約束仍有未收斂項目，工具報告 `timing_closed=NO`；這是目前的時序狀態，不能把它誤寫成 timing clean。
2. 兩片診斷版都 `Configuration succeeded`。Master checksum 為 `0x3098FB5E`，Slave checksum 為 `0x30962662`。
3. JTAG instance 同時列出 instance 0 與 instance 1，證明 Wishbone mailbox 已存在。
4. `read_wb_runtime.tcl` 能從兩片讀回 PPS、SoftPLL、系統、CPU 與 WRPC 內建 `wdiags` 欄位。

實際 JTAG 結果：

```text
Master status_probe: 0001026135BC82CF
Master PPS_CR:       00000000
Master PPS_ESCR:     00000000
Master SPLL_CSR:     01010000
Master SPLL_ECCR:    00000000
Master SPLL_OCCR:    00000000
Master SYSC_RSTR:    0105300F
Master SYSC_GPSR:    0100000F
Master CPU_DBGSTAT:  00000000
Master CPU_DBGREADY: 00000000
Master CPU_MBX:      00000000

Slave status_probe: 000102E134BC82CF
Slave PPS_CR:       00000000
Slave PPS_ESCR:     00000000
Slave SPLL_CSR:     01010000
Slave SPLL_ECCR:    00000000
Slave SPLL_OCCR:    00000000
Slave SYSC_RSTR:    0105300F
Slave SYSC_GPSR:    0100000F
Slave CPU_DBGSTAT:  00000000
Slave CPU_DBGREADY: 00000000
Slave CPU_MBX:      00000000
```

狀態 probe 的低 16-bit 仍然是兩端 `0x82CF`，表示這次診斷介面沒有破壞既有 QSFP-A lane 0 的 PHY/link 基準。兩端仍是 `time_valid=0`、`pps_valid=0`，所以同步尚未完成。

另外，腳本已加入 WRPC 既有 `wdiags` 區的唯讀讀取，下一次在兩板上重跑並比較間隔一秒以上的結果，才能判斷韌體是否有週期更新 PTP、伺服器與封包計數。這些欄位若完全維持零或版本不正確，優先懷疑 WRPC 韌體沒有正常執行或診斷區未接到預期位址；若欄位會更新但 lock 仍為零，才進一步集中到 PTP/SoftPLL/時鐘參考問題。

## pain terminal log

建置與燒錄的完整輸出保存於 pain 的：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-JTAG-RUNTIME-20260816/
```

上面的輸出是目前已取得的最小必要結果；完整 Quartus、燒錄與 JTAG log 保留在上述目錄。下一輪 `wdiags` 讀值會另外附加在此實驗文件的後續紀錄中。

## 怎麼看待這個結果

如果 mailbox 能成功讀回 WRPC 暫存器，下一步才可以合理判斷問題是在 firmware/PTP/SoftPLL，而不是繼續盲目修改 QSFP lane、polarity 或 pre-emphasis。

如果 mailbox 版仍只有 `0x82CF` 且 `time_valid=0`、`pps_valid=0`，代表 PHY/link 已成立但同步尚未完成；這時要依暫存器與 PTP/SoftPLL 狀態決定下一個單一變因。

如果診斷版讓 link 從 `0x82CF` 退化，必須立即恢復正式基準 SOF，並把問題視為診斷介面整合錯誤，而不是拿診斷結果修改光路。

## 成功判定限制

即使 `time_valid=1`、`pps_valid=1`，也只能先宣稱 WRPC 內部同步狀態有效。若要宣稱實體次奈秒同步，仍要依官方校正流程量測兩端 1-PPS（每秒脈衝）上升緣差，並保存校正資料與量測證據。
