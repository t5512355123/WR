# EXP-WRPC-STEP4-FIRMWARE-ONLY-SHELL-EXEC-DISPATCH-DIAGNOSTIC-20260826

## 實驗目的

針對前一輪 VLAN/pfilter 診斷中 Master 未出現 `VLAN_CMD_ENTER` 的結果，加入 firmware-only、read-only 的 `shell_exec()` 分派 checkpoint，確認問題是否位於命令 tokenization、命令查找、handler 呼叫或 handler 返回邊界。

本輪只新增診斷寫入，不改變 shell 命令的功能順序、命令內容、PTP/SoftPLL/FSM/PI/DCO、網路封包或 endpoint 行為。

## 診斷設計

在既有 `PTPSTAT (0x00100A10)` 的高位加入暫存診斷欄位；低 8 位仍保留 PTP state。每次 `shell_exec()` 執行時依序記錄：

1. `SHELL_EXEC_ENTER`
2. `TOKENIZE_DONE`
3. `COMMAND_NAME_PARSED`
4. `COMMAND_LOOKUP_BEGIN`
5. `COMMAND_LOOKUP_MATCH_INDEX`
6. `COMMAND_HANDLER_FOUND`
7. `BEFORE_HANDLER_CALL`
8. `AFTER_HANDLER_RETURN`

match index 使用 6 bits 保存命令表索引。讀取工具只透過 JTAG 讀取既有診斷暫存器，不對 firmware 或硬體狀態下寫入命令。

## Image、版本與燒錄

- firmware/diagnostic code commit：`838e1e4`
- Master build：成功；`timing_closed=NO`（與本實驗前的 B image 相同）
- Slave build：成功；`timing_closed=NO`（與本實驗前的 B image 相同）
- Master cable：`DE5 [1-11.1]`，program 成功，0 errors/0 warnings，checksum `0x30B1722A`
- Slave cable：`DE5 [1-11.2]`，program 成功，0 errors/0 warnings，checksum `0x30B05EEB`
- raw evidence commit：`04751d2`

## 量測方法

燒錄完成後，以 `scripts/jtag/read_shell_exec_dispatch_progress_diag.tcl 12 1000` 對兩個 cable 各讀取 12 次，取樣間隔約 1 秒。完整原始輸出保存在：

`raw/EXP-WRPC-STEP4-FIRMWARE-ONLY-SHELL-EXEC-DISPATCH-DIAG-20260826/shell_exec_dispatch_diag_final.txt`

## 結果

| Board | Samples | RAW | PTP_STATE | ENTER | TOKENIZE | NAME | LOOKUP | MATCH_VALID | MATCH_INDEX | HANDLER | BEFORE_CALL | AFTER_RETURN |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Master `DE5 [1-11.1]` | 12/12 | `0x000AFF04` | 4 | 1 | 1 | 1 | 1 | 1 | 10 | 1 | 1 | 1 |
| Slave `DE5 [1-11.2]` | 12/12 | `0x000AFF04` | 4 | 1 | 1 | 1 | 1 | 1 | 10 | 1 | 1 | 1 |

兩端 12 次取樣皆保持相同結果，沒有 checkpoint 遺失或中途退回的現象。

## match index 對應

本次使用的 `de5a_master_defconfig` 與 `de5a_slave_defconfig` 都啟用 `CONFIG_IP`、`CONFIG_VLAN`，並未啟用 `CONFIG_CMD_CONFIG`、`CONFIG_CMD_LL`、`CONFIG_CMD_NETCONSOLE`、`CONFIG_CMD_PPS`、`CONFIG_CMD_LEAPSEC`、`CONFIG_CMD_REFRESH`、`CONFIG_LATENCY_PROBE` 或 `CONFIG_FREQUENCY_MONITOR`。依 `shell_register_commands()` 的註冊順序，index 10 為 top-level `ptp` command：

`calibration(0), diag(1), gui(2), help(3), init(4), ip(5), mac(6), mode(7), pll(8), ps(9), ptp(10)`

因此目前證據與 built-in init script 的最後一個 `ptp start` 分派一致；這個診斷欄位只證明 top-level command 為 `ptp`，不保存其 arguments。

## 判定

1. Master 與 Slave 的 `shell_exec()` 都能完成 tokenization、命令名稱解析、命令查找、handler 找到、handler 呼叫與 handler 返回。
2. `shell_exec()` 的通用 dispatch path 不是目前可觀測到的阻塞點；兩端均已通過 `BEFORE_HANDLER_CALL → AFTER_HANDLER_RETURN`。
3. 本輪沒有重新保存 VLAN-specific marker，因此不能單獨證明 `vlan off` 的 handler 曾在本輪被呼叫；PTPSTAT 的 shell 診斷是「最後一次 shell_exec」狀態，後續 `ptp` 命令會覆蓋先前命令的 marker。
4. 因此 `STEP4_ALLOWED=NO` 的結論維持不變。本輪只排除 generic `shell_exec()` dispatch 的基本失敗，尚未解釋前一輪 Master 未出現 `VLAN_CMD_ENTER` 的原因。

## 下一步邊界

應將診斷粒度縮小到 `vlan` handler 本身與其第一個 endpoint/pfilter 操作，或以不增加額外 MMIO 讀取的方式保存 per-command 的 VLAN-specific checkpoint；在取得該證據前，不進行 Step 4 的功能判讀或新的時脈/SoftPLL 變更。
