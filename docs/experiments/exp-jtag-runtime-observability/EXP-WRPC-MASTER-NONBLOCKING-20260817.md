# EXP-WRPC-MASTER-NONBLOCKING-20260817

## 實驗基本資料

- 實驗日期：2026-08-17
- 實驗名稱：Master 非阻塞角色啟動驗證
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`488a860`（讓Master角色非阻塞啟動）
- 目的：確認 Master 角色先套用、且不等待 SoftPLL lock，是否能讓 Master 進入 WR master runtime。

## 相較於 baseline 的唯一修改

- Master `wrc_initialize()` 在原本的 Slave 初始化位置改為套用 `WRC_MODE_MASTER`。
- Master `wrc_ptp_set_mode()` 在 `CONFIG_FORCE_MASTER_AFTER_INIT` 下略過 `wrpc_spll_check_lock_with_timeout()`，讓 role commit 不被 PLL lock wait 阻塞。
- Master 仍略過持久化 Flash init script。
- Slave、PHY、QSFP lane、DMTD、PTP state machine 與 JTAG observability 未修改。

## 編譯與映像 provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA-256：`20fef98041eacfa9b026d046102fac5c0bab838d908a5dfbfca0e03f5d25ea06`
- Master SOF SHA-256：`da759756243322a16eb784bf93e6665787841a67dfc32d28ba072d018272d968`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Firmware `.config`：`CONFIG_FORCE_MASTER_AFTER_INIT=y`、`CONFIG_INIT_COMMAND="vlan off;ptp stop;mode master;ptp start"`、`CONFIG_HAS_FLASH_INIT=1`。
- Quartus 結果：Fitter successful，Full Compilation successful，0 errors / 272 warnings；`timing_closed=NO`，最差 setup slack `-0.184 ns`、hold slack `-3.475 ns`。

## 燒錄結果

- 目標：`DE5 [1-11.1]`（Master）
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A31DBA`
- 結果：Configuration succeeded；Quartus Programmer 報告 0 errors / 0 warnings。
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-NONBLOCKING-20260817/program_master.log`
- 燒錄後執行一次 `sudo reboot`，等待主機恢復後重新讀取。

## JTAG/runtime 原始結果

### 燒錄後立即讀取（2026-08-17 12:40）

Master：

- `cpu_marker=B00B`、`WDIAGS_TEMP=B002`、`reset=0`、`fault=0`。
- `WDIAGS_MODE=0`、`WDIAGS_PTP_RX=0`、`WDIAGS_PTP_TX=0`。
- `WDIAGS_SSTAT=0`、`WDIAGS_PSTAT=0`。

Slave：

- `cpu_marker=B004`、`WDIAGS_MODE=3`。
- `WDIAGS_PTP_RX=0x1C50`、`WDIAGS_PTP_TX=0x1AF6`。

### 重開機後讀取（2026-08-17 12:43）

Master：

- 仍為 `cpu_marker=B00B`、`WDIAGS_TEMP=B002`。
- 仍為 `WDIAGS_MODE=0`、`WDIAGS_PTP_RX=0`、`WDIAGS_PTP_TX=0`。

Slave：

- `cpu_marker=B004`、`WDIAGS_MODE=3`。
- `WDIAGS_PTP_RX=0x1C50`、`WDIAGS_PTP_TX=0x1AF6`。

原始紀錄：

- `artifacts/EXP-WRPC-MASTER-NONBLOCKING-20260817/runtime_after_program.log`
- `artifacts/EXP-WRPC-MASTER-NONBLOCKING-20260817/runtime_after_reboot.log`

## Observation

1. Quartus 編譯與 SOF 燒錄成功，但 Master 沒有到達 `B004` 主迴圈 marker，而是停在 `B002`；`PC=0x000053A4` 對應 `timer_delay`。
2. Master 角色設定呼叫尚未執行到，因此本實驗無法驗證非阻塞 role commit 是否有效。
3. Slave 仍可執行並持續產生 PTP RX/TX，顯示本次主要失敗點在 Master 的更早期初始化路徑。
4. 重開機後 Master 仍停在 B002，不能把它解釋成一次性的暫態。

## Conclusion

本實驗只支持以下結論：

> 直接在 `wrc_initialize()` 套用 Master role 會使 Master image 在早期初始化階段停在 B002，尚未進入 role 設定或 runtime loop；因此這個修正不可用，也沒有產生 WR synchronization 成功證據。

## Next Step

撤回 `wrc_initialize()` 的直接 Master 呼叫，保留非阻塞 `wrc_ptp_set_mode()`，改由主迴圈啟動後的一次性 task 套用 Master role。這樣可保留原本能到達 B004 的初始化順序，再檢查 Master `WDIAGS_MODE=2` 與 PTP counters。
