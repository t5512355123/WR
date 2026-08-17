# EXP-WRPC-MASTER-SHELL-DIAG-20260817

## 實驗資訊

- 日期：2026-08-17
- 實驗名稱：診斷 Master 內建初始化命令是否執行
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`c0a217eedb2693386991dedde2807ce7b6e3441a`
- 基準版本：`37f5609`（前一輪 Flash guard 實驗紀錄）
- 本次唯一功能變更：只在 `CONFIG_FORCE_MASTER_AFTER_INIT` 的 Master firmware 中，將每個內建 init command 的執行次數與第一個錯誤回傳值寫入既有 sticky CPU marker；不改命令內容、PHY、PTP 演算法、servo 或 SI5340。
- Quartus：Quartus Prime 17.0 Build 595 (04/25/2017 SJ Standard Edition)

## 想驗證什麼

前一輪 Master runtime 仍為 `WDIAGS_MODE=3`。本輪要區分三種可能：

1. `shell_boot_script()` 沒有執行內建命令；
2. 命令執行但 parser/API 回傳錯誤；
3. 命令成功執行，但目前 active SOF/MIF 不一致或後續流程把 mode 改回去。

## 來源與輸出 hash

- Master MIF SHA-256：`7aedf08361f74aca776338962262379446abdbea88da971bd3620404ce66eb9a`
- Master SOF SHA-256：`2882427a8affe7e58b1320125c69db857ac725f21c2e42bdb236ac7459eb8cb5`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave 使用上一輪已燒錄版本：MIF SHA-256 `e3e8c421e1ebcae881c1e27bdfe71261bd9e8e66937c8574e7e9d7962a96c65d`；SOF SHA-256 `d153b51ecf7de857f9a3e28fbceb08d94ee5e6020e54f7a78bc7617ff0ae10e1`。

## 編譯結果

- Master firmware：成功
- Master Quartus full compilation：`0 errors, 272 warnings`
- 未重新編譯 Slave，因本次變更只在 Master 組態啟用。

## 燒錄結果

- cable：`DE5 [1-11.1]`
- device：`10AX115N2F45@1`
- JTAG ID：`0x02E660DD`
- SOF checksum：`0x30A31DBA`
- Programmer：`Configuration succeeded -- 1 device(s) configured`
- Programmer 結果：`0 errors, 0 warnings`

## Marker 定義

Master 內建初始化命令每執行一次就更新既有 `cpu_marker`：

```text
0xB1<count><first_error_low16>
```

例如四個命令都執行且錯誤回傳為 0 時，預期 marker 為 `0xB1040000`；若 marker 仍是 `0xB004`，表示尚未進入 shell init command loop。此 marker 只用於本診斷實驗，不代表 WR synchronization 成功。

## 原始證據位置

pain：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SHELL-DIAG-20260817/`

- `build_master_firmware.log`
- `master_mif.sha256`
- `quartus_master_compile.log`
- `provenance.txt`
- `program_master.log`
- `runtime_readings.log`

## Runtime 原始結果摘要

燒錄後約 0、5、15、60 秒讀取兩條 JTAG cable。Master 與 Slave CPU 都是 `reset=0`、`fault=0`，但 Master `cpu_marker` 在所有時間點都為 `0x0000B004`。Master `WDIAGS_MODE` 讀值為 3、0、3、3；Slave 一直為 3。PTP counter 仍有活動，但沒有穩定的 Master mode=2 證據。

重要 raw 片段：

```text
Master t=0s:  cpu_marker=0x0000B004, WDIAGS_MODE=3, PTP_RX=0x29, PTP_TX=0x1A
Master t=5s:  cpu_marker=0x0000B004, WDIAGS_MODE=0, PTP_RX=0x37, PTP_TX=0x22
Master t=15s: cpu_marker=0x0000B004, WDIAGS_MODE=3, PTP_RX=0x45, PTP_TX=0x25
Master t=60s: cpu_marker=0x0000B004, WDIAGS_MODE=3, PTP_RX=0x85, PTP_TX=0x44
Slave  t=60s: cpu_marker=0x0000B004, WDIAGS_MODE=3, PTP_RX=0x1D9, PTP_TX=0x246
```

## Observation

本輪 marker 不能回答命令是否執行。唯讀檢查 source 後確認：`wrc_tasks_run_inits()` 執行完 `shell_boot_script()` 後，`wrc_main.c` 無條件執行 `debug_boot_stage = 0x0000B004`，因此 shell 寫入的 `0xB1xx....` 會被立刻覆蓋。這是診斷設計失效，不是可歸因於 FPGA、PHY 或 WR protocol 的新證據。

Master 在 5 秒讀到 mode 0，之後回到 mode 3；這個短暫值沒有同步意義，仍需先取得可靠的 command-stage 證據。

## Conclusion

本次實驗結果為「診斷方法不具判別力」，不是同步成功，也不是已證明命令失敗。硬體燒錄與 runtime CPU 執行仍成功，但 Master role 與 Slave synchronization 都未被證明。

## 下一步

下一輪只修改 `wrc_main.c` 的 Master 條件編譯：若 shell 診斷已寫入 `0xB1xx....` marker，就不要在 `wrc_tasks_run_inits()` 返回後覆寫成 `B004`；Slave 與所有 PTP/PHY 內容保持不變。之後重新產生新 MIF/SOF、燒錄 Master，再以 marker 判斷四個命令是否完成及是否有錯誤回傳。
