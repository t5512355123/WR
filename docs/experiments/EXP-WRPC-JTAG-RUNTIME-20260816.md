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

## 實驗：EXP-WRPC-CPU-STORE-COUNT-20260816

### 實驗名稱

CPU 內部資料寫入累計計數觀測。

### 這次要驗證什麼

前一輪只保存「最後一次 CPU 內部寫入」，無法分辨 CPU 是只寫過一次後停止，還是一直有寫入但最後一筆剛好落在其他位址。本實驗加入累計計數器，並在兩秒間隔後再次讀取，確認 CPU 是否持續執行資料寫入活動。

### 修改內容

- 在 `wrc_urv_wrapper.vhd` 新增 32-bit `cpu_internal_store_count_o`，每次觀察到 CPU internal store 就累加。
- 在 `wr_core.vhd` 與 `xwr_core.vhd` 將該計數器訊號向上傳遞。
- Master／Slave 的 JTAG diagnostic top 各新增第 5 個 SLD probe，讓 JTAG 可以讀回計數值。
- `read_wb_runtime.tcl` 新增 `cpu_internal_store_count` 顯示；其他 WR timing、QSFP lane、pre-emphasis 與 firmware 內容沒有改動。
- Git commit：`64d4739 增加 CPU 內部寫入計數觀測`。

### Compile 證據

兩片都使用 pain 上的 Quartus Prime 17.0 Build 595 編譯，且為完整編譯成功：

| 項目 | Master | Slave |
|---|---|---|
| Compile 結果 | `Full Compilation was successful`，0 errors | `Full Compilation was successful`，0 errors |
| SOF SHA-256 | `5e3f5958e7af37dcf1592c9b64a2679ff5275b45d3f50a9c22f301834e8a1051` | `8a3454f9317e3a7a6fdd3b99e4642ccf7a497f0382e3964e370b205c88fa24d1` |
| Timing | 未關閉；最差 setup slack `-2.902 ns` | 未關閉；最差 setup slack `-2.873 ns` |

編譯 metadata 保留在 pain：

```text
/home/b10504072/04_WR/build/build_info_jtag_master.txt
/home/b10504072/04_WR/build/build_info_jtag_slave.txt
```

### 燒錄證據

兩片皆由各自 JTAG cable 燒錄成功：

```text
Master cable: DE5 [1-11.1]
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings

Slave cable: DE5 [1-11.2]
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

完整終端機輸出保留在：

```text
/home/b10504072/04_WR/build/program_store_count_master.log
/home/b10504072/04_WR/build/program_store_count_slave.log
/home/b10504072/04_WR/build/runtime_store_count.log
/home/b10504072/04_WR/build/runtime_store_count_repeat.log
```

### pain terminal log 結果顯示什麼

燒錄後第一次讀取：

```text
DE5 [1-11.1] status_probe: 000102C1275082CF
DE5 [1-11.1] cpu_internal_store_count: 33466578 (0x01FEA8D2)

DE5 [1-11.2] status_probe: 0001026131BC82CF
DE5 [1-11.2] cpu_internal_store_count: 8138969 (0x007C30D9)
```

約三秒後再次讀取：

```text
DE5 [1-11.1] cpu_internal_store_count: 47845853 -> 50794168
DE5 [1-11.2] cpu_internal_store_count: 22515792 -> 25468453
```

兩片在所有讀取中都保持低 16-bit status `0x82CF`，其 bit mapping 表示 `phy_ready=1`、`tm_link_up=1`、`link_ok=1`、`rx_ready=1`、`tx_ready=1`，且沒有看到 RX/TX encoding error。CPU probe 也保持 `reset=0`、`fault=0`、`im_valid=1`。

同一批讀取仍看到：

```text
cpu_marker: 0x00000000 seen=0
PPS_CR: 00000000
WDIAGS_VER: 00000000
WDIAGS_PTP: 00000000
WDIAGS_RX: 00000000
WDIAGS_TX: 00000000
```

### 結果與判讀

- 兩片 store counter 在短時間內都明顯增加，證明 CPU 內部資料寫入活動持續發生，不是「CPU 完全停止」或「只執行一次 store」的情況。
- `cpu_marker` 仍沒有觀察到預期的啟動 marker，最後一次 store 仍是 `addr=0x000002E8 data=0x00000000`。因此目前更像是觀測到的 store 位址分類、CPU 啟動流程或中斷／例外活動與 marker 假設不一致，而不是單純沒有寫入。
- `WDIAGS_*` 仍全部為 0，代表目前不能用這組診斷暫存器證明 WRPC 已經正常進入 PTP、SoftPLL 或 clock actuator 的工作狀態。
- 兩端 `time_valid` 與 `pps_valid` 仍沒有變成 1 的證據，因此本實驗不能宣稱 White Rabbit 時間同步成功；目前只確認 PHY/link 與 CPU 活動仍在。
- 下一個最小變因應該是加入 CPU `mepc`（Machine Exception Program Counter，機器例外程式計數器）與 `mcause`（Machine Cause，機器例外原因）觀測，並檢查 internal store 的位址／字組位址定義。暫時不更換光纖、不切換 QSFP port，也不再盲目調高 TX pre-emphasis。

## 實驗：EXP-WRPC-RV32IM-20260816

### 實驗名稱

修正 WRPC firmware 與 uRV CPU 指令集不一致，並重新驗證兩片 DE5a 的 WR runtime。

### 這次要驗證什麼

前一輪的例外 probe 在兩片都固定讀到 `mepc=0x00000474`、`mcause=0x00000006`。uRV 原始碼將 cause 6 定義為 `CAUSE_UNALIGNED_STORE`（未對齊的 store／AMO 存取），而當時 firmware 的設定是 `CONFIG_RISCV_COMP_INSTR=y`，編譯結果為 `rv32imc`。檢查 uRV fetch/decode 原始碼後，確認這份 uRV 實作沒有完整的壓縮指令取指流程；因此本實驗把 firmware 改成 uRV 實際使用的 `rv32im` 指令集，驗證例外是否消失、WRPC 是否能進入 PTP 工作狀態。

### 修改內容

- `firmware/configs/de5a_master_defconfig`：取消 `CONFIG_RISCV_COMP_INSTR`。
- `firmware/configs/de5a_slave_defconfig`：取消 `CONFIG_RISCV_COMP_INSTR`。
- 重新建立 Master／Slave 的 `wrc.elf`、`wrc.bin` 與 `wrc.mif`。
- 保留前一輪的唯讀 `mepc/mcause` JTAG probe、CPU store counter 與 runtime mailbox。
- Git commit：`b9fa1dc 修正 WRPC 與 uRV 指令集不一致`。

### Compile 證據

兩份 firmware 都確認 `# CONFIG_RISCV_COMP_INSTR is not set`，並成功產生新的 MIF：

```text
Master wrc.mif SHA-256:
5fc963872ffa351ff3ea1b881e903eed2df67dde18e70958ce13f0f7b41c31ae

Slave wrc.mif SHA-256:
cc047c9b789cd5f787f7f253520f0da5af23a82824d42038b8cca2631d274840
```

Quartus Prime 17.0 完整編譯結果：

| 項目 | Master | Slave |
|---|---|---|
| Compile 結果 | `Full Compilation was successful`，0 errors | `Full Compilation was successful`，0 errors |
| SOF SHA-256 | `420ee7122ea72f57aecc058af0afd0b78a911420187743abffa03184edc93be9` | `6bf747aa44d65af6dc1b593d10633b7ed1d6eb03a225c4d4d5c50907a9339390` |
| Timing | 未關閉；最差 setup slack `-3.024 ns` | 未關閉；最差 setup slack `-3.002 ns` |

### 燒錄證據

```text
Master cable: DE5 [1-11.1]
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings

Slave cable: DE5 [1-11.2]
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

本輪 pain 輸出保留在：

```text
/home/b10504072/04_WR/build/firmware/master/build_hashes.sha256
/home/b10504072/04_WR/build/firmware/slave/build_hashes.sha256
/home/b10504072/04_WR/build/build_info_jtag_master.txt
/home/b10504072/04_WR/build/build_info_jtag_slave.txt
/home/b10504072/04_WR/build/program_rv32im_master.log
/home/b10504072/04_WR/build/program_rv32im_slave.log
/home/b10504072/04_WR/build/runtime_rv32im.log
/home/b10504072/04_WR/build/runtime_rv32im_repeat.log
```

### pain terminal log 結果顯示什麼

燒錄後第一次 runtime 讀取：

```text
Master status_probe: 101ED0C1275082FF
Master cpu_exception: mepc=0x00000000 mcause=0x00000000
Master WDIAGS_VER: 00000002
Master WDIAGS_PTP: 00000006
Master WDIAGS_TX: 00000021
Master WDIAGS_RX: 00000003
Master WDIAGS_TEMP: 0000B004

Slave status_probe: 001E766335BC82EF
Slave cpu_exception: mepc=0x00000000 mcause=0x00000000
Slave WDIAGS_VER: 00000002
Slave WDIAGS_PTP: 00000004
Slave WDIAGS_TX: 00000013
Slave WDIAGS_RX: 00000010
Slave WDIAGS_TEMP: 0000B004
```

約五秒後再次讀取：

```text
Master status_probe: 101E886137BC82FF
Master cpu_exception: mepc=0x00000000 mcause=0x00000000
Master WDIAGS_PTP: 00000006
Master WDIAGS_TX: 00000083
Master WDIAGS_RX: 00000014

Slave status_probe: 001E8A6135BC82EF
Slave cpu_exception: mepc=0x00000000 mcause=0x00000000
Slave WDIAGS_PTP: 00000004
Slave WDIAGS_TX: 00000044
Slave WDIAGS_RX: 00000054
```

依 status probe 的 bit mapping：

- Master 低 byte `0xFF`：`tm_link_up=1`、`link_ok=1`、`time_valid=1`、`pps_valid=1`。
- Slave 低 byte `0xEF`：`tm_link_up=1`、`link_ok=1`、`time_valid=0`、`pps_valid=1`。
- 兩片 CPU 都是 `reset=0`、`fault=0`、`im_valid=1`，且例外狀態清為 0。
- `WDIAGS_PTP=6` 對應 Master 狀態；`WDIAGS_PTP=4` 對應 `PPS_LISTENING`，表示 Slave 仍在等待有效的 PTP／WR 上游狀態。
- 兩端 `WDIAGS_PSTAT=1` 表示 link 已起來，但目前診斷版本顯示的 SoftPLL locked bit 尚未成為 1。

### 結果與判讀

- **已確認的根因：** 原本的 CPU 例外主要來自 firmware 使用 `rv32imc`，而目前採用的 uRV core 不具備相符的 compressed instruction 取指支援；改為 `rv32im` 後，兩片的 `mepc/mcause` 都回到 0，CPU 可以持續執行，WRPC marker／WDIAGS 也開始正常更新。
- **已確認的改善：** Master 已進入 `PPS_MASTER`，並同時出現 `time_valid=1`、`pps_valid=1`；這是第一次取得 WR timecode 有效的實機證據。
- **尚未完成的部分：** Slave 仍是 `PPS_LISTENING`，雖然 `pps_valid=1`、link_ok=1，`time_valid` 仍為 0。因此現在還不能宣稱兩片已完成 WR 時間同步。
- **下一個驗證方向：** 保留目前 `rv32im` firmware，不再修改 CPU；針對 Slave 的 PTP 接收路徑檢查 announce／sync 是否真的被 PPSI 接受，以及 QSFP lane0 的 WR Ethernet 設定、封包過濾與接收錯誤計數。若需要重編譯，仍維持一次只改一個變因。

## 實驗：EXP-WRPC-PPSI-COUNTERS-20260816

### 實驗名稱

加入 PPSI（PTP Protocol State Machine，精確時間協定狀態機）封包收發計數與父時鐘診斷。

### 這次要驗證什麼

本實驗要區分「PHY/link 已連線」與「WRPC（White Rabbit Protocol Core，White Rabbit 協定核心）真的有收到並處理 PTP 封包」。如果兩片板都能看到 Sync、Announce、Follow-up 訊息計數增加，代表 QSFP 光路與 PTP 封包接收路徑至少有資料流動；接著再觀察 Slave 是否建立 foreign master（候選上游時鐘）以及是否進入同步狀態。

### 修改內容

- 在 `wdiags` 的診斷暫存器中加入 PPSI RX/TX 計數。
- 加入 PTP 狀態與父時鐘相關 metadata（中繼資料）讀回。
- 更新 `scripts/jtag/read_wb_runtime.tcl`，讀取 `WDIAGS_PTP_RX`、`WDIAGS_PTP_TX` 與 `WDIAGS_PTP_META`。
- 只增加診斷讀值，不改變 WRPC 的同步決策流程。
- Git commit：`3bfa39d 新增 PPSI 訊息類型與父時鐘診斷`。

### Compile 與燒錄證據

Master 與 Slave 都使用 Quartus Prime 17.0 Build 595 完整編譯成功，0 errors、267 warnings；兩端的 timing 尚未關閉，最差 setup slack 分別為 `-3.024 ns` 與 `-3.002 ns`。編譯前先將可工作的前一版本產物保存至：

```text
/home/b10504072/04_WR/build/artifacts/ptp_total_diag_028c8a1/
```

本實驗產物的 MIF SHA-256：

```text
Master: 5919576947bae5cf29eb98781171c4fed6879eab0037d19f2f9acb37688e0c31
Slave : 9400e5df385d905d8c9cca2451c38727515002a1bf2a83f39ee88d9b8
```

SOF SHA-256：

```text
Master: aad08d9f70dafb290604bd3188d928fc3a50b4ed704312dd9f26d538f41e6b00
Slave : db1aba16d2ffc243e150e5db74b7c11ac953bcefd8fa3fc622ec930e42834d00
```

兩端分別使用 `DE5 [1-11.1]` 與 `DE5 [1-11.2]` 燒錄，均顯示 `Configuration succeeded`，且 Quartus Programmer 回報 0 errors、0 warnings。

### pain terminal log 結果顯示什麼

燒錄約 8 秒後的主要讀值如下：

```text
Master WDIAGS_PTP:00000006
Master WDIAGS_PTP_RX:00000013
Master WDIAGS_PTP_TX:00000035
Master WDIAGS_PTP_META:01010106
Master WDIAGS_RXERR:00000022

Slave WDIAGS_PTP:00000004
Slave WDIAGS_PTP_RX:00000037
Slave WDIAGS_PTP_TX:00000013
Slave WDIAGS_PTP_META:01010104
Slave WDIAGS_RXERR:0000001B
```

約 20 秒後，兩端的 PPSI RX/TX 計數仍持續增加；Master 仍為 `WDIAGS_PTP=6`，Slave 仍為 `WDIAGS_PTP=4`。

### 結果與判讀

- 兩端都確實有 PTP 封包收發，因為 PPSI RX/TX 計數會增加。
- Slave 沒有從 `PPS_LISTENING` 進入可用的同步狀態，表示「有收到封包」不等於「已選出可接受的父時鐘」。
- 這排除了「QSFP 完全沒有資料」這個最簡單的解釋，但還不能定位是封包過濾、Announce 資料、時鐘身份，或其他 PPSI 條件未滿足。
- 因此本實驗的結論是：**光路與 PTP 資料流存在，但兩片尚未完成 WR 時間同步。**

## 實驗：EXP-WRPC-PREFILTER-20260816

### 實驗名稱

加入 PTP 封包類型、Announce 處理與 prefilter（前置封包過濾）原因診斷。

### 這次要驗證什麼

上一個實驗確認兩端會交換 PTP 封包，但 Slave 仍停在 `PPS_LISTENING`。本實驗進一步確認：

1. 收到的封包是否包含 Sync、Announce、Follow-up。
2. Announce 是否進入 PPSI 狀態機。
3. 封包是否因 domain、alternate master、same port 或 same clock 等條件被丟棄。
4. 是否真的建立 foreign master 記錄。

### 修改內容

- 在 `wrc_ptp_ppsi.c` 增加 PTP message type 計數。
- 在 `fsm.c` 增加 parse error 與 prefilter 原因計數。
- 在 `wrc_ptp_ppsi.c` 記錄 Announce processed、Announce added 與 Announce length。
- 在 `wdiags` 暫存器增加 `WDIAGS_PTP_TYPES`、`WDIAGS_FOREIGN_META`、`WDIAGS_FILTER_META` 與 `WDIAGS_PARSE_META`。
- 更新 JTAG runtime 讀取腳本。
- 第一次編譯因 `task-diags.c` 的括號錯誤失敗，隨後以 `af9162b 修正封包診斷編譯錯誤` 修正；修正後 Quartus 編譯成功。

### Compile 與燒錄證據

修正後的 Master 與 Slave 都以 Quartus Prime 17.0 Build 595 完整編譯成功，0 errors、267 warnings：

```text
Master GIT_COMMIT   : af9162bd2ce785caa954cc1738240110c8ce4292
Master MIF SHA-256  : f57d7fb44d2a7b091a934f1e713452fb6136fba2c6aab2d699a78dd0cff0ba28
Master SOF SHA-256  : fdeaf2b36e85f24d544ae2b1fa2d9d03cdc7e668f2fcf26a32f04db0ca727698
Master timing       : 未關閉，最差 setup slack -3.024 ns

Slave MIF SHA-256   : 689f2679cb3bffa13ce085480dbd239c54f409077c2db64aac32946f06f0f781
Slave SOF SHA-256   : bde6aefdae1c65a957d40e2d9c00f46fcf390f5f05a44175037dcb628af88fa2
Slave timing        : 未關閉，最差 setup slack -3.002 ns
```

兩端燒錄均顯示 `Configuration succeeded -- 1 device(s) configured`。

### pain terminal log 結果顯示什麼

這一版燒錄後，兩端都在 WRPC 啟動早期陷入 CPU fault handler，主要輸出如下：

```text
Master status_probe: 000102C1275082CF
Master cpu_probe: PC around 0x00015CF0..0x00015CFC
Master cpu_exception: mepc=0x0000006F mcause=0x00000000
Master WDIAGS_VER: 00000000
Master WDIAGS_PTP: 00000000
Master PPS_CR: 00000000
Master PPS_ESCR: 00000000

Slave status_probe: 000102C123D082CF
Slave cpu_probe: PC around 0x00015CF0..0x00015CFC
Slave cpu_exception: mepc=0x0000006F mcause=0x00000000
Slave WDIAGS_VER: 00000000
Slave WDIAGS_PTP: 00000000
Slave PPS_CR: 00000000
Slave PPS_ESCR: 00000000
```

約 20 秒後讀取結果沒有改善，診斷暫存器仍為 0。

### 結果與判讀

- 本版本的 Quartus 編譯與 FPGA 燒錄都成功，但 **firmware runtime 沒有成功啟動到 WRPC 診斷階段**。
- 因為 CPU 已進入 fault handler，所以 `WDIAGS_PTP_TYPES=0`、`WDIAGS_FILTER_META=0` 與 `WDIAGS_PARSE_META=0` 不能解讀成「沒有收到 PTP 封包」；它們只是表示診斷程式還沒跑到會更新這些暫存器的位置。
- 這次實驗因此是「編譯成功、runtime 失敗」，不是封包過濾結論。
- 目前最可靠的回復基準是前一個可正常執行的 `3bfa39d` 產物，已保存在：

```text
/home/b10504072/04_WR/build/artifacts/ptp_types_diag_3bfa39d/
```

- 下一步應先重新燒錄該基準版本，確認 `WDIAGS_VER=2`、PPSI RX/TX 計數持續增加且 `mepc/mcause` 回到 0，再以更小變因重新加入封包過濾診斷。未完成這個回復前，不應宣稱 Slave 的封包過濾原因已被量出來。

### 目前階段性總結

截至本紀錄：

- Master 已有 `link_ok=1`、`time_valid=1`、`pps_valid=1` 的實機證據。
- Slave 已有 `link_ok=1`、`pps_valid=1`，但 `time_valid=0`，仍未完成 WR 時間同步。
- `3bfa39d` 能正常執行並證明兩端交換 PTP 封包。
- `af9162b` 雖然編譯與燒錄成功，但造成 CPU runtime trap，因此必須先回到 `3bfa39d` 基準再繼續診斷。
- 尚未取得兩片 DE5a 外部 PPS 端點的示波器量測，因此不能宣稱已達到 White Rabbit 的實體次奈秒同步精度。

---

## 實驗：EXP-WRPC-ROLE-DIAG-20260816

### 實驗名稱

加入 Master/Slave 角色與 PTP 執行狀態的 JTAG 唯讀診斷。

### 這次要驗證什麼

確認兩片 DE5a 是否以正確角色啟動，以及 Slave 是否真的收到 PTP 封包並進入父時鐘選擇流程。這個實驗不修改 QSFP 光路、lane、極性或 pre-emphasis。

### 修改內容

- 在 firmware 診斷暫存器加入角色模式、PTP 狀態、PTP RX/TX 計數與 foreign master metadata。
- 更新 `scripts/jtag/read_wb_runtime.tcl`，以兩條獨立 JTAG 連續讀取 Master 與 Slave。
- 使用 commit `798dd99 加入角色模式的 JTAG 診斷` 建立並燒錄 Master/Slave SOF。

### 結果

- Quartus 17.0 Build 595 編譯成功，兩片皆成功燒錄。
- Master：mode=2、`WDIAGS_PTP=6`（PPS master）、PTP_RX=`0x30`、PTP_TX=`0x9D`、`PPS_ESCR=0x01312D0C`。
- Slave：mode=3、`WDIAGS_PTP=4`（PPS listening）、PTP_RX=`0x9F`、PTP_TX=`0x30`、`PPS_ESCR=0`。
- 兩端 CPU 都是 `fault=0`，`cpu_marker=0xB004`，PC 與 instruction-memory valid 正常。
- 兩端 `FOREIGN_META=0x0000FF00`，表示當時尚未建立可用的 foreign master 記錄或 parent。

### pain terminal log 結果顯示什麼

完整紀錄保存在：

```text
/home/b10504072/04_WR/build/artifacts/role_diag_798dd99/runtime_after_program_8s.log
```

### 怎麼看待這個結果

CPU、角色設定與雙向 PTP 封包流已經成立；但 Slave 仍停在 `PPS_LISTENING`，所以不能把「有 PTP RX/TX」解讀成「已完成 White Rabbit 同步」。下一個重點是讀出 parent identity、Announce 接受狀態與 delay exchange，不是先修改 PHY。

---

## 實驗：EXP-WRPC-ENDPOINT-MAC-20260816

### 實驗名稱

讀取兩片 DE5a 的 Endpoint MAC，確認 PTP clock identity 是否意外相同。

### 這次要驗證什麼

確認 Master 與 Slave 是否因使用完全相同的 fallback MAC，導致 BMC（Best Master Clock，最佳主時鐘選擇）拒絕對方的 Announce，進而使 Slave 無法選出 parent。

### 修改內容

- 只在 JTAG 唯讀腳本加入 endpoint MAC register 讀取，不修改硬體資料路徑。
- 讀取 endpoint MAC high/low register 與 endpoint status。
- 使用 commit `c9874c2 加入 Endpoint MAC 的 JTAG 診斷` 重新編譯、燒錄並讀取。

### 結果

兩片讀到相同的 endpoint MAC register 組合：

```text
EP_MAC_H: 02002233
EP_MAC_L: 44556677
```

依 `ep_set_mac_addr()` 的 register byte packing，實際 fallback MAC 的有效低位元組為 `22:33:44:55:66:77`，兩片沒有不同的節點身份。這是重要的軟體身份問題候選，但尚未證明它是唯一根因。

### pain terminal log 結果顯示什麼

完整紀錄保存在：

```text
/home/b10504072/04_WR/build/artifacts/role_diag_798dd99/runtime_mac_read_c9874c2.log
```

### 怎麼看待這個結果

兩片 DE5a 使用同一個 clock identity 會讓 BMC 的 parent selection 非常可疑；因此下一個合理變因是只修正節點身份。然而，這個變更必須先用最小 A/B 證明不會破壞原本可運作的 CPU runtime。

---

## 實驗：EXP-WRPC-UNIQUE-MAC-20260816

### 實驗名稱

為 Master/Slave 建立不同的角色專用 fallback MAC。

### 這次要驗證什麼

驗證兩片使用不同 PTP clock identity 後，是否能讓 Slave 建立 foreign master 並進入同步流程；同時確認這個修正不會破壞 uRV firmware 的啟動。

### 修改內容

- 在 `vendor/wrpc-sw/Kconfig` 新增 `DE5A_NODE_ID`。
- Master defconfig 設為 node id 1，Slave defconfig 設為 node id 2。
- generic board fallback MAC 改為角色專用的 locally administered MAC：
  - Master：`02:00:22:33:44:01`
  - Slave：`02:00:22:33:44:02`
- 使用 commit `c206628 保留 DE5a 角色身份設定` 重新產生兩份 MIF、重新編譯兩份 Quartus SOF，再分別燒錄。

### 結果

- firmware build 成功；Master MIF SHA-256：
  `e56ee9f1b4d4c96f6b869ec3dcd770c8facfddc29584e67f99929a026e6a4a1a`
- Slave MIF SHA-256：
  `0343988a27e43c2da3485896d2395b6fcc1e6d788505c2b582aad1995a66e36`
- Master/Slave Quartus build 都成功。
- Master SOF SHA-256：`e64bf6ef6993a706a68680d48abdf9533acbc9db62a6d2be01e8ffe788c33808`
- Slave SOF SHA-256：`a1bb6d2cb68b3185e1e61c2ed0d7bd87802a057938aad52ba3fe816f3cfec8b0`
- 兩片燒錄都顯示 configuration succeeded。
- 但是兩片 runtime 都在啟動早期進入 `fault_handler`，PC 約在 `0x15CEC`；`cpu_marker=0`、`WDIAGS_*` 全為 0、endpoint MAC 讀值為 0。

### pain terminal log 結果顯示什麼

完整紀錄保存在：

```text
/home/b10504072/04_WR/build/artifacts/unique_mac_c206628/runtime_after_program_8s.log
/home/b10504072/04_WR/build/artifacts/unique_mac_c206628/program_master.log
/home/b10504072/04_WR/build/artifacts/unique_mac_c206628/program_slave.log
```

關鍵輸出：

```text
cpu_debug: PC 約在 0x00015CEC，fault=0 的 probe 仍停在 fault handler 鄰近位置
cpu_marker: 0x00000000 seen=0
WDIAGS_PTP: 00000000
EP_MAC_H: 02000000
EP_MAC_L: 00000000
```

### 怎麼看待這個結果

這次不能拿來判斷 MAC 是否成功解決 BMC，因為 firmware 根本還沒執行到 MAC 初始化與 PTP 診斷。兩片同時在相同 fault address 失敗，較像 Kconfig、firmware layout 或新 MAC runtime code 引起的回歸，而不是 QSFP 電氣問題。這個版本先保留在 artifact 目錄，不作為目前執行基準。

---

## 實驗：EXP-WRPC-RESTORE-BASELINE-20260816

### 實驗名稱

恢復已知可運作的 `e302c4d` bitstream，確認新版本失敗不是板卡永久狀態損壞。

### 這次要驗證什麼

確認相同兩片 DE5a、相同兩條 JTAG 與相同 QSFP 連線，在恢復 baseline 後 CPU、PTP 封包流與 JTAG 診斷能否回復。這是對 `c206628` 的安全回復與控制組實驗。

### 修改內容

- 沒有修改 source code。
- 使用保存的 `fixed_marker_2e000_e302c4d` Master/Slave SOF。
- 以 Quartus 17.0 programmer 分別燒錄 `DE5 [1-11.1]` 與 `DE5 [1-11.2]`。
- 燒錄後等待 8 秒，執行同一份 `read_wb_runtime.tcl`。

### 結果

兩片都顯示：

```text
Configuration succeeded
0 errors, 0 warnings
```

8 秒後兩端都回到正常 runtime：

- Master：`fault=0`、`cpu_marker=0xB004 seen=1`、`WDIAGS_VER=2`、`WDIAGS_PTP=6`、PTP_RX=`0x0F`、PTP_TX=`0x21`。
- Slave：`fault=0`、`cpu_marker=0xB004 seen=1`、`WDIAGS_VER=2`、`WDIAGS_PTP=0x13`、PTP_RX=`0x12`、PTP_TX=`0x08`。
- 兩端 CPU internal store count 持續增加，`cpu_exception` 的 `mepc=0`、`mcause=0`。
- 兩端仍讀到相同 fallback MAC `22:33:44:55:66:77`，因此身份問題尚未解決，但 baseline runtime 已恢復。

### pain terminal log 結果顯示什麼

完整紀錄保存在：

```text
/home/b10504072/04_WR/build/artifacts/unique_mac_c206628/control_restore_e302c4d_8s.log
```

### 怎麼看待這個結果

恢復 baseline 後兩片 CPU 與 PTP 活動都正常，表示目前沒有必要先做實體斷電，也不支持把 `c206628` 的 fault 歸因於 QSFP 或板卡永久故障。下一個實驗應採用另一種不改 Kconfig/layout 的最小身份注入方式，並保留 baseline SOF 作為對照；只有在新版 runtime 正常後，才可繼續驗證 parent selection 與 `time_valid/pps_valid`。

### 本階段結論

目前已取得的可靠證據是：

```text
PHY/PCS：有穩定雙向 PTP 封包活動
CPU runtime：e302c4d baseline 正常
角色：Master/Slave 設定正確
節點身份：兩片仍使用相同 fallback MAC
唯一 MAC 修正：尚未成功，因 firmware 先 fault
White Rabbit 完整同步：尚未完成，不能宣稱 time_valid=1、pps_valid=1

---

## 實驗：EXP-WRPC-CONTROL-NO-MAC-20260816

### 實驗名稱

`ffb7350 建立唯一身份問題的控制組`：移除 `DE5A_NODE_ID` 與角色專用 MAC，保留其餘診斷程式。

### 這次要驗證什麼

確認 `c206628` 的 early fault 是否只由角色專用 MAC 或 Kconfig node-ID 造成。控制組恢復原始 `22:33:44:55:66:77` fallback MAC，且不再有 node-ID 設定。

### 修改內容

- `vendor/wrpc-sw/boards/generic/board.c` 恢復原始 fallback MAC。
- 移除 `vendor/wrpc-sw/Kconfig` 的 `DE5A_NODE_ID` 設定。
- 移除 Master/Slave defconfig 的 node-ID 行。
- 其餘角色診斷、PTP 診斷與 linker marker 保持不變。
- pain pull `ffb7350` 後重新產生兩份 MIF，再以 Quartus 17 完整編譯兩份 SOF。

### 結果

- Master 與 Slave firmware build 成功。
- Master 與 Slave Quartus build 成功，均為 `timing_closed=NO`。
- 兩片燒錄都顯示 `Configuration succeeded`、0 errors、0 warnings。
- Master 8 秒後正常：`fault=0`、`marker=0xB004 seen=1`、`WDIAGS_VER=2`。
- Slave 8 秒後仍停在 `PC=0x15CEC` fault handler：`marker seen=0`、`WDIAGS_* = 0`、endpoint MAC 尚未初始化。

### pain terminal log 結果顯示什麼

```text
/home/b10504072/04_WR/build/artifacts/control_no_mac_ffb7350/hashes.sha256
/home/b10504072/04_WR/build/artifacts/control_no_mac_ffb7350/runtime_after_program_8s.log
```

關鍵輸出：

```text
Master cpu_debug: fault=0
Master cpu_marker: 0x0000B004 seen=1
Slave  cpu_debug: PC=0x00015CEC fault=0 im_valid=1
Slave  cpu_marker: 0x00000000 seen=0
Slave  WDIAGS_VER: 00000000
```

### 怎麼看待這個結果

單純移除角色 MAC 與 node-ID，仍不能保證 runtime 正常；但這個結果受到「每次重建的 MIF 可能包含不同 SDBFS 內嵌資料」影響，不能直接把 fault 歸因到某一段 C 程式。下一步必須先驗證同一 commit 的 firmware 是否可重現。

---

## 實驗：EXP-WRPC-CLEAN-REBUILD-798-20260816

### 實驗名稱

`798dd99 加入角色模式的 JTAG 診斷`：乾淨 worktree 重建與實機驗證。

### 這次要驗證什麼

確認先前保存的 `role_diag_798dd99` 正常結果能否由同一 Git commit、同一 pain 建置流程重新產生；同時比較它與 `ffb7350` 控制組的 MIF。

### 修改內容

- 沒有修改 source code。
- 在 pain 建立乾淨 worktree `/tmp/wr_role_diag_798`，固定 checkout `798dd99`。
- 使用同一套 firmware 與 Quartus 17 build scripts 產生兩份 MIF/SOF。
- 將產物保存到新的 artifact 目錄，未覆蓋任何舊檔。

### 結果

- Master/Slave firmware 與 Quartus 17 build 都成功。
- MIF SHA-256：Master `2edf4da24e3a535569cefa14f89e8e3a7681da0ce76282977fe299eda640871c`；Slave `ce1409c4207ba609985686514a5799ea7841dddc741ee00ebc185b3ce19b264d`。
- 兩片 SOF 都成功燒錄。
- 8 秒後兩片 CPU 都正常：`fault=0`、`marker=0xB004 seen=1`。
- Master `WDIAGS_PTP=6`、mode=2；Slave `WDIAGS_PTP=6`、mode=3；兩端 PTP RX/TX 計數都有增加。

### pain terminal log 結果顯示什麼

```text
/home/b10504072/04_WR/build/artifacts/rebuild_798_clean/hashes.sha256
/home/b10504072/04_WR/build/artifacts/rebuild_798_clean/runtime_after_program_8s.log
```

### 怎麼看待這個結果

`798dd99` 乾淨重建可正常執行，說明 CPU fault 不是這個診斷功能必然造成，也不是板卡永久故障。它與 `ffb7350` 的差異需要以 firmware 產物與 SDBFS 內嵌影像追查；目前仍不能宣稱 WR 已完成時間同步，因為 `FOREIGN_META=0x0000FF00` 且 Slave 尚未有有效 parent 證據。

---

## 實驗：EXP-WRPC-REBUILD-REPRODUCIBILITY-20260816

### 實驗名稱

`ffb7350 建立唯一身份問題的控制組`：同一 commit 的第二次乾淨 firmware rebuild。

### 這次要驗證什麼

確認 `ffb7350` 的 MIF/ELF 是否可重現，避免把不可重現的 firmware 產物誤判為硬體或 PTP 問題。

### 修改內容

- 沒有修改 source code。
- 在 pain 建立第二個乾淨 worktree `/tmp/wr_control_ffb2`，固定 checkout `ffb7350`。
- 只重新執行 Master/Slave firmware build，沒有覆蓋正在板上運作的 baseline。

### 結果

同一 commit 的兩次 firmware 產物 hash 不同：

```text
第一次 Master MIF: 40aa683ef4bb3319265cb34063da21af56735e08c564f2eec93fe0eb15f3c4be
第二次 Master MIF: 6cff5faedd04fb3559cf977e7a3b680bbf749fb857b84b5ba6c8855cd00d3df4
第一次 Slave  MIF: f770a7057d0b1054da1e718dab2c5cb470d82963785e74fd652d2f4d478e7872
第二次 Slave  MIF: d2516c15c464f154b72fea064faf89571d589742ade56aa68a1621daa40a2667
```

Map 的主要 code section 位址仍相同，但 `wrc.bram`/`wrc.mif` 在 SDBFS 影像區的檔案排列與 build-time 字串不同，例如 `sfp-` 與 `wr-init` 的資料位置互換。這表示目前建置流程不是位元級可重現。

### pain terminal log 結果顯示什麼

第二次建置的 worktree 與產物位於：

```text
/tmp/wr_control_ffb2/build/firmware/work/master/
/tmp/wr_control_ffb2/build/firmware/work/slave/
```

主要比對證據是 `diff -u wrc.mif` 顯示 SDBFS 區域差異，而 `.text/.rodata/.data/.bss/.debug_boot` 位址與大小一致。

### 怎麼看待這個結果

目前最值得優先修正的是 firmware/SDBFS 的可重現性。即使程式碼與 linker map 看起來相同，內嵌 SDBFS 的排列或生成順序變動，也可能改變啟動時讀到的資料。下一輪先固定 SDBFS 生成輸入的排序與 build metadata，再重新編譯同一 commit 兩次，直到 MIF hash 一致，才繼續 MAC identity 與 parent selection 實驗。

---

## 實驗：EXP-WRPC-RESTORE-AFTER-CONTROL-20260816

### 實驗名稱

A 組測試後恢復 `e302c4d` baseline。

### 這次要驗證什麼

確認 A 組 fault 不會永久破壞 DE5a，並把實驗平台留在已知可執行狀態。

### 修改內容

- 沒有修改 source code。
- 重新燒錄保存的 `/home/b10504072/04_WR/build/artifacts/fixed_marker_2e000_e302c4d/` 兩份 SOF。
- 等待 8 秒後以相同 JTAG 腳本讀取。

### 結果

- Master/Slave 都恢復 `fault=0`、`marker=0xB004 seen=1`、`mepc=0`、`mcause=0`。
- PTP RX/TX 計數持續增加。
- 兩端仍使用相同 fallback MAC，身份問題仍未處理。

### pain terminal log 結果顯示什麼

```text
/home/b10504072/04_WR/build/artifacts/control_no_mac_ffb7350/runtime_restore_e302c4d_after_A_8s.log
```

### 怎麼看待這個結果

baseline 回復成功，表示不需要實體斷電，也不支持把 fault 歸因於 QSFP 光路永久故障。後續實驗會先修正可重現建置，再以相同 baseline 逐項加入唯一身份設定。
```

---

## 實驗：EXP-WRPC-DETERMINISTIC-BUILD-20260816

### 實驗名稱

`4acdeb6`、`569c9f3`、`a0a1973`：固定韌體產物的可重現建置流程。

### 這次要驗證什麼

驗證同一份 Master/Slave 原始碼，在相同建置流程執行兩次時，產生的韌體 MIF（Memory Initialization File，記憶體初始化檔）是否完全一致。這一步是為了避免把每次建置產物的差異誤判成 FPGA、PHY 或 White Rabbit（WR）執行期故障。

### 修改內容

- `4acdeb6 固定 SDBFS 生成順序`：在 `gensdbfs.c` 對嵌入檔案名稱排序，避免 `readdir()` 回傳順序改變 SDBFS（Software Database File System，軟體資料庫檔案系統）內容排列。
- `569c9f3 啟用可重現韌體建置`：在 Master/Slave defconfig 啟用 `CONFIG_DETERMINISTIC_BINARY=y`。
- `a0a1973 移除韌體中的建置時間差異`：將 PPSi 與 SNMP 中的 `__DATE__`、`__TIME__` 改為 deterministic 分支，避免建置日期與時間寫入韌體。
- 使用 pain 上的 Quartus 17 / WR 韌體建置流程；本階段只驗證韌體產物，尚未以這一輪產物燒錄 FPGA。

### 結果

- Master/Slave firmware build 均成功。
- 同一份 commit 的兩次獨立建置，MIF hash 完全相同：

```text
Master MIF: 7bb9a242b81683d71e208539fd2ecd5b7f9a0c691a555ecc3ffe1e1ed7250b04
Slave  MIF: c5ab914a69bd7ec6a1336e4afc9f6ef63fe0f8491ae23bbd94ef3988f8e81697
diff count: 0 / 0
```

### pain terminal log 結果顯示什麼

```text
/home/b10504072/04_WR/build/artifacts/deterministic_a0a1973/hashes.sha256
/home/b10504072/04_WR/build/artifacts/deterministic_a0a1973/master_build.log
/home/b10504072/04_WR/build/artifacts/deterministic_a0a1973/slave_build.log
```

`hashes.sha256` 記錄兩次建置的 Master/Slave MIF hash 與逐位元比對結果；結果為 `diff count: 0 / 0`。

### 怎麼看待這個結果

這次已證明韌體從 source 到 MIF 的建置流程具備位元級可重現性，後續可以把 Quartus compile、燒錄與 JTAG runtime 讀值歸因到明確的 Git commit 與 MIF。這個結果本身不代表 WR 已完成時間同步；它只排除了「韌體建置產物每次不同」這個干擾因素。下一步可在不改 source 的前提下，以 `a0a1973` 產出的 MIF 做 Quartus 17 compile、燒錄，再記錄兩片 DE5a 的 runtime、PTP、parent 與 servo 證據。

---

## 實驗：EXP-WRPC-DETERMINISTIC-SOF-RUNTIME-20260816

### 實驗名稱

`56848ac 補充可重現韌體建置實驗紀錄`：使用 `a0a1973` 固定產物進行 Quartus 17 compile、燒錄與 JTAG runtime 讀值。

### 這次要驗證什麼

確認已經位元級固定的 Master/Slave MIF，可以在 Quartus 17 重新編譯成可燒錄 SOF，並確認燒錄後兩片 DE5a 的 CPU、PTP 封包活動與目前 WR link 狀態。這次不修改 PHY、QSFP 接線、Pre-Emphasis 或 SFP database。

### 修改內容

- source code 沒有新增功能變更；使用 `56848ac` 所包含的 `a0a1973` deterministic firmware。
- pain 重新執行 `build_master_firmware.sh`、`build_slave_firmware.sh`。
- pain 使用 Quartus 17 重新編譯 `DE5a_wr_master_jtag` 與 `DE5a_wr_slave_jtag`。
- 產生的 SOF 另存於 `/home/b10504072/04_WR/build/artifacts/deterministic_a0a1973/quartus_sof/`。
- 透過兩條獨立 JTAG 分別燒錄 Master `DE5 [1-11.1]` 與 Slave `DE5 [1-11.2]`，8 秒後執行相同的 `read_wb_runtime.tcl`。

### 結果

- Master/Slave Quartus 17 compile 均成功，但兩份報告均為 `timing_closed=NO`。
- 燒錄均成功：

```text
Master checksum: 0x30A0A429
Slave  checksum: 0x30A5A091
Configuration succeeded -- 1 device(s) configured
```

- 8 秒後兩片 CPU 都正常：

```text
Master: fault=0, marker=0x0000B004, seen=1
Slave : fault=0, marker=0x0000B004, seen=1
```

- Master runtime：`WDIAGS_MODE=2`、`WDIAGS_PTP=00000006`，PTP RX/TX 為 `0x0D / 0x38`。
- Slave runtime：`WDIAGS_MODE=3`、`WDIAGS_PTP=00000004`，PTP RX/TX 為 `0x20 / 0x29`。
- 目前兩端仍讀到相同 endpoint MAC：`EP_MAC_H=02002233`、`EP_MAC_L=44556677`。
- 兩端 `WDIAGS_FOREIGN_META=0000FF00`，表示目前沒有選出有效的 foreign master；`time_valid` 尚未形成可宣稱的穩定成功證據。

### pain terminal log 結果顯示什麼

```text
/home/b10504072/04_WR/build/artifacts/deterministic_a0a1973/quartus_master_compile.log
/home/b10504072/04_WR/build/artifacts/deterministic_a0a1973/quartus_slave_compile.log
/home/b10504072/04_WR/build/artifacts/deterministic_a0a1973/program_a0a1973.log
/home/b10504072/04_WR/build/artifacts/deterministic_a0a1973/runtime_after_program_8s.log
/home/b10504072/04_WR/build/artifacts/deterministic_a0a1973/quartus_artifact_hashes.sha256
```

### 怎麼看待這個結果

這次證明 `56848ac` 的 firmware 可重現產物可以通過 Quartus 17 compile 並成功燒錄，且沒有重現先前的 CPU early fault；因此目前平台仍可繼續做 runtime 實驗，不需要實體斷電。另一方面，這次沒有證明 White Rabbit 已完成同步：兩端仍使用相同 fallback MAC，且 foreign master 尚未被選出。下一個實驗必須只改「節點唯一身份」這一個變因，並沿用本次 deterministic build、相同 JTAG 讀值與相同 artifact 保存規則。

---

## 實驗：EXP-WRPC-UNIQUE-IDENTITY-CACHE-20260816

### 實驗名稱

`ed21eaa 加入兩片 DE5a 唯一節點身份` 與 `c88cc05 修正 Quartus 建置前清理快取`：排除相同 PTP clock identity，並確認新 MIF 確實進入 SOF。

### 這次要驗證什麼

確認兩片 DE5a 不再使用相同 fallback MAC，讓 White Rabbit 的 BMC（Best Master Clock，最佳主時鐘選擇）可以辨識不同節點並建立 foreign-master/parent 關係；同時確認 Quartus incremental cache 不會讓新 MIF 被舊 SOF 蓋過。

### 修改內容

- `ed21eaa`：不新增 Kconfig、不修改 linker、PHY 或 PTP 參數。
- Master/Slave build script 各自注入 identity header：
  - Master：`02:00:22:33:44:01`
  - Slave：`02:00:22:33:44:02`
- `c88cc05`：在 Master/Slave Quartus 17 build script 於 compile 前執行 `quartus_sh --clean <project.qpf>`，清除 database/incremental cache。
- 保留 stale-SOF 版本與 log，不覆蓋：
  `/home/b10504072/04_WR/build/artifacts/unique_mac_ed21eaa/`
- 修正後的 clean 版本保存於：
  `/home/b10504072/04_WR/build/artifacts/unique_mac_clean_c88cc05/`

### 結果

#### A 組：stale-SOF 失效判定

- `ed21eaa` 的 Master/Slave MIF hash 已改變，但未清 Quartus cache 時，SOF hash 與前一版相同。
- 因此 A 組只證明「firmware build 產生了新 MIF」，不能證明新 MIF 已進入 FPGA；這次燒錄結果不採用為唯一身份實驗證據。

#### B 組：clean Quartus 有效版本

- `c88cc05` clean compile 後，SOF hash 改變：

```text
Master SOF SHA256: f565c0a209cf1567f048df25b0f3312e9db4bf45a3fc46914a87efefbf2b1abf
Slave  SOF SHA256: 926d4a57f50dce0e39e437af7eba164a8ca1ec327c989b59d5f6480a038eb2cb
```

- Master/Slave Quartus 17 compile 均成功，兩份均為 `timing_closed=NO`。
- 兩片 JTAG 燒錄均 `Configuration succeeded`，SOF programmer checksum 分別為 `0x30A0A429` 與 `0x30A5A091`。此 checksum 不是本次唯一判斷依據，因為 JTAG runtime 已提供更直接的 MAC/parent 證據。
- 8 秒後兩片 CPU 都正常：`fault=0`、`marker=0xB004 seen=1`。
- Master JTAG 讀到 `EP_MAC_H=02000200`、`EP_MAC_L=22334401`，對應 `02:00:22:33:44:01`。
- Slave 已不再是舊的相同 fallback identity；`WDIAGS_FOREIGN_META` 由 `0000FF00` 變成 `03000001`，`WDIAGS_PTP` 由 4 前進到 8，表示已開始建立 foreign-master/parent 狀態。

### pain terminal log 結果顯示什麼

```text
/home/b10504072/04_WR/build/artifacts/unique_mac_ed21eaa/master_firmware_build.log
/home/b10504072/04_WR/build/artifacts/unique_mac_ed21eaa/slave_firmware_build.log
/home/b10504072/04_WR/build/artifacts/unique_mac_ed21eaa/program_ed21eaa.log
/home/b10504072/04_WR/build/artifacts/unique_mac_clean_c88cc05/master_firmware_build.log
/home/b10504072/04_WR/build/artifacts/unique_mac_clean_c88cc05/slave_firmware_build.log
/home/b10504072/04_WR/build/artifacts/unique_mac_clean_c88cc05/quartus_clean_master.log
/home/b10504072/04_WR/build/artifacts/unique_mac_clean_c88cc05/quartus_master_compile.log
/home/b10504072/04_WR/build/artifacts/unique_mac_clean_c88cc05/quartus_slave_compile.log
/home/b10504072/04_WR/build/artifacts/unique_mac_clean_c88cc05/program_clean_c88cc05.log
/home/b10504072/04_WR/build/artifacts/unique_mac_clean_c88cc05/runtime_after_program_8s.log
/home/b10504072/04_WR/build/artifacts/unique_mac_clean_c88cc05/quartus_artifact_hashes.sha256
```

### 怎麼看待這個結果

這是目前第一個證據顯示「唯一節點身份」變因已真正進入 FPGA，並讓 Slave 的 foreign/parent metadata 開始變化；先前 `c206628` 的 CPU fault 沒有重現。可是 `time_valid=1`、Slave 的完整 parent identity、Delay exchange 與 SoftPLL/DCO lock 尚未完成，因此不能宣稱 WR 時間同步成功。60 秒 runtime snapshot 完成後，會在本節追加結果；在此之前不會進行下一個 source 變因。
