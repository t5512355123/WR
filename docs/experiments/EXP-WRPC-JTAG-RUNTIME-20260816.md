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
- 新增 `scripts/jtag/read_wb_runtime.tcl`，只讀取 PPS、SoftPLL、系統與 CPU debug 狀態。
- `scripts/jtag/read_wb.tcl` 是另一支記憶體診斷工具；它會短暫寫入 CPU reset 與 UADDR，讀取 instruction RAM 後一定釋放 CPU，不能把它和唯讀 runtime snapshot 混用。

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
Master CPU_RESET:    00000000
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
Slave CPU_RESET:    00000000
Slave CPU_DBGSTAT:  00000000
Slave CPU_DBGREADY: 00000000
Slave CPU_MBX:      00000000
```

狀態 probe 的低 16-bit 仍然是兩端 `0x82CF`，表示這次診斷介面沒有破壞既有 QSFP-A lane 0 的 PHY/link 基準。兩端仍是 `time_valid=0`、`pps_valid=0`，所以同步尚未完成。

另外，腳本已加入 WRPC 既有 `wdiags` 區的唯讀讀取。實際讀取時兩片的 `WDIAGS_VER`、`WDIAGS_CTRL`、PTP 計數、伺服器狀態、`WDIAGS_UCNT` 與 SoftPLL 診斷欄位都維持零；這仍不能單獨證明 CPU 沒有執行，因為還需要直接觀測 CPU 的取指位址與 firmware marker。

`CPU_RESET=00000000` 表示 uRV CPU 沒有被 CPU CSR（Control and Status Register，控制與狀態暫存器）的 reset bit 保持住；但這還不足以證明 CPU 已執行到 `main()`。因此下一個診斷版本會在 WRPC 初始化早期，把 `WDIAGS_TEMP` 暫時當作 boot stage：

| 值 | 代表階段 |
|---:|---|
| `0xB001` | 進入 `wrc_initialize()` |
| `0xB002` | 完成 `wrc_board_early_init()` |
| `0xB003` | 完成 `wrc_board_init()` |
| `0xB004` | 完成所有任務的初始化 |

這些值只用於診斷版，因為目前設定沒有啟用板上溫度感測器；正式版本若啟用溫度感測器，該欄位恢復原本的溫度用途。

## 後續實驗：CPU 執行與啟動標記觀測

### 實驗名稱

`EXP-WRPC-CPU-OBSERVABILITY-20260816`：增加 CPU instruction address 與 firmware boot marker 的只讀觀測。

### 為了驗證什麼

本實驗要回答：CPU 是完全停在 reset、遇到 fault，還是其實正在執行 WRPC，只是先前的 JTAG RAM 讀值路徑沒有讀到 marker。

### 改了什麼

- 在 `wrc_urv_wrapper`、`wr_core`、`xwr_core` 逐層導出 CPU 的 PC、CPU reset、fault 與 instruction-valid。
- 增加 JTAG instance 2：`[31:0]` 是 CPU PC，bit 32 是 CPU reset，bit 33 是 fault，bit 34 是 instruction-valid。
- `read_wb_runtime.tcl` 對 instance 2 連續取樣，間隔 50 ms。
- 目前工作中的下一版再增加 JTAG instance 3：只記住 CPU 對 `0x00016530` 這個 `debug_boot_stage` 位址發出的第一次 store，避免只依賴停止 CPU 後的 RAM 讀回。
- 以上都是診斷觀測，不改 QSFP-A lane 0、PHY、PCS、SI5340、125 MHz 參考時鐘或 WR protocol。

### 已完成的結果

CPU probe 版本以 commit `4a1ec34` 編譯並燒錄；讀值工具修正與連續取樣分別是 `0f2e1bc`、`1fd0831`。pain 上執行 `quartus_stp -t scripts/jtag/read_wb_runtime.tcl` 的重要輸出如下：

```text
=== DE5 [1-11.1] ===
status_probe: 000102E1363C82CF
cpu_probe_1:    0000000400001E1A
cpu_debug: PC=0x00001E1A reset=0 fault=0 im_valid=1
cpu_probe_2:    000000040000EFE6
cpu_debug: PC=0x0000EFE6 reset=0 fault=0 im_valid=1

=== DE5 [1-11.2] ===
status_probe: 000102C1205082CF
cpu_probe_1:    0000000400002962
cpu_debug: PC=0x00002962 reset=0 fault=0 im_valid=1
cpu_probe_2:    0000000400000474
cpu_debug: PC=0x00000474 reset=0 fault=0 im_valid=1
```

### pain terminal log 結果顯示什麼

- `status_probe` 兩片低 16-bit 都仍是 `0x82CF`，所以 CPU probe 沒有破壞原本的 PHY/link 基準。
- `reset=0` 表示 CPU 沒有被 reset bit 持續壓住。
- `fault=0` 表示這次取樣沒有看到 ECC fault。
- `im_valid=1` 且兩次 PC 不同，表示 CPU 有在取指；Master 的 `0x0000EFE6` 落在 `trap_entry`，Slave 的樣本也會落在初始化或中斷處理函式。
- 兩片 `time_valid` 與 `pps_valid` 仍為 0，因此這不是時間同步成功證據。

### 怎麼看待這個結果

目前最合理的結論是：問題已從「CPU 完全沒有執行」縮小到「WRPC 啟動流程、interrupt/SoftPLL 互動、CPU data-store，或 JTAG RAM 讀回其中一段仍有問題」。不能再把 `WDIAGS` 全零直接解讀成 CPU 死掉。

下一個 marker latch 編譯完成後：

- `seen=1` 且 marker 是 `0xB000`、`0xB00A` 或 `0xB00B`：CPU 已執行到對應啟動階段，先檢查 JTAG RAM 讀回時序。
- `seen=0`：CPU 沒有對 marker 位址發出 store，需繼續檢查 CPU data memory write/exception 路徑。

在拿到 marker 之前，不修改 pre-emphasis、lane polarity 或 QSFP port；這些是另一條實驗線，必須維持單一變因。

## pain terminal log

建置與燒錄的完整輸出保存於 pain 的：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-JTAG-RUNTIME-20260816/
```

上面的輸出是目前已取得的最小必要結果；完整 Quartus、燒錄與 JTAG log 保留在上述目錄。後續每一版都會在此實驗文件追加實驗名稱、目的、修改、pain log、結果與判讀，不用只看最後一行結論。

## 怎麼看待這個結果

如果 mailbox 能成功讀回 WRPC 暫存器，下一步才可以合理判斷問題是在 firmware/PTP/SoftPLL，而不是繼續盲目修改 QSFP lane、polarity 或 pre-emphasis。

如果 mailbox 版仍只有 `0x82CF` 且 `time_valid=0`、`pps_valid=0`，代表 PHY/link 已成立但同步尚未完成；這時要依暫存器與 PTP/SoftPLL 狀態決定下一個單一變因。

如果診斷版讓 link 從 `0x82CF` 退化，必須立即恢復正式基準 SOF，並把問題視為診斷介面整合錯誤，而不是拿診斷結果修改光路。

## 成功判定限制

即使 `time_valid=1`、`pps_valid=1`，也只能先宣稱 WRPC 內部同步狀態有效。若要宣稱實體次奈秒同步，仍要依官方校正流程量測兩端 1-PPS（每秒脈衝）上升緣差，並保存校正資料與量測證據。

## 後續實驗：CPU 內部資料寫入觀測

### 實驗名稱

`EXP-WRPC-CPU-DATA-STORE-20260816`：增加 CPU 內部資料寫入位址與資料的持續觀測。

### 為了驗證什麼

本實驗要區分兩種可能：

1. CPU 確實在執行，但 firmware marker 寫入沒有被既有 JTAG 讀回路徑看到。
2. CPU 的資料記憶體寫入介面本身沒有正常完成，導致啟動標記沒有寫入。

### 改了什麼

- 在 `wrc_urv_wrapper` 增加最後一次 CPU 內部資料寫入位址與資料的 latch。
- 將觀測值透過 `wr_core`、`xwr_core` 傳到頂層。
- 增加 JTAG instance 4：低 32-bit 為最後一次內部 store 位址，高 32-bit 為對應資料。
- 保留 JTAG instance 3 的 `debug_boot_stage` marker 觀測。
- 沒有修改 QSFP-A lane 0、PHY、PCS、SI5340、WR 參考時鐘或正式 WR protocol。

### 編譯與燒錄證據

本版本使用 Git commit `727d08f` 編譯：

| 項目 | Master | Slave |
|---|---|---|
| Quartus 結果 | Full Compilation was successful | Full Compilation was successful |
| SOF SHA-256 | `41a7840a149f9856c81ec5fccf5ab7cfb2ea0479035b258da430e0ae38f97233` | `9116daffcacf2793e6e62a54d441a12ca43965b0bda2a05b82a1110beda840ef` |
| Timing | 未關閉；最差 setup slack `-2.828 ns` | 未關閉；最差 setup slack `-3.517 ns` |
| Programmer | `Configuration succeeded` | `Configuration succeeded` |

燒錄與編譯詳細檔案保留在 pain：

```text
/home/b10504072/04_WR/build/build_info_jtag_master.txt
/home/b10504072/04_WR/build/build_info_jtag_slave.txt
/home/b10504072/04_WR/build/program_store_master.log
/home/b10504072/04_WR/build/program_store_slave.log
```

### pain terminal log 結果顯示什麼

診斷腳本在兩片板讀到：

```text
Master status_probe: 000203C1213C82CF
Master cpu_probe_1: 000000040000296E
Master cpu_debug: PC=0x0000296E reset=0 fault=0 im_valid=1
Master cpu_probe_2: 0000000400000478
Master cpu_debug: PC=0x00000478 reset=0 fault=0 im_valid=1
Master cpu_marker: 0x00000000 seen=0
Master cpu_last_internal_store: addr=0x000002E8 data=0x00000000

Slave status_probe: 000102C3383C82CF
Slave cpu_probe_1: 000000040000EFB6
Slave cpu_debug: PC=0x0000EFB6 reset=0 fault=0 im_valid=1
Slave cpu_probe_2: 0000000400002966
Slave cpu_debug: PC=0x00002966 reset=0 fault=0 im_valid=1
Slave cpu_marker: 0x00000000 seen=0
Slave cpu_last_internal_store: addr=0x000002E8 data=0x00000000
```

兩端的 `CPU_RESET=00000000`，而且取樣到的 `reset=0`、`fault=0`、`im_valid=1`；這表示 CPU 仍在取指執行，沒有看到被 reset 或 fault 卡住。兩端低 16-bit 仍是 `0x82CF`，所以這次增加觀測邏輯沒有破壞原本的 PHY/link 基準。

### 結果與判讀

- `cpu_marker seen=0`：目前沒有觀察到對 `0x00016530` 的啟動 marker 寫入。
- `cpu_last_internal_store` 讀到位址 `0x000002E8`、資料 `0x00000000`：確實捕捉到至少一筆 CPU 內部資料寫入，但這一筆資料尚不足以證明 marker 寫入路徑正常或異常。
- 目前不能把結果解讀成「CPU 資料寫入完全失效」，因為 latch 保存的是最後一次觀察到的 store，而且 `0x2E8` 可能是初始化或其他內部資料位置。
- 目前也不能宣稱 WR 時間同步成功；兩端 `time_valid` 與 `pps_valid` 仍未成為 1 的證據。

下一個診斷會加入內部 store 累計次數，並檢查 CPU store 位址的位元組／字組位址定義；必要時再讀取 CPU exception 的 `mepc`（Machine Exception Program Counter，機器例外程式計數器）與 `mcause`（Machine Cause，機器例外原因），以判斷是否反覆進入中斷或例外處理。這些仍維持「診斷版單一變因」，不先修改光纖、lane polarity 或 pre-emphasis。
