# EXP-WRPC-MASTER-FLASH-SKIP-20260817

## 實驗基本資料

- 實驗日期：2026-08-17
- 實驗名稱：Master 映像略過持久化 Flash init script 的角色驗證
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`17ac382`（修正Master啟動腳本條件編譯）
- 目的：確認只略過 Master 的持久化 Flash init script，是否能讓內建 `mode master` 成為最後角色設定。

## 相較於 baseline 的唯一修改

Master firmware 新增 `CONFIG_FORCE_MASTER_AFTER_INIT=y` 行為：

- `shell_boot_script()` 仍執行內建 `CONFIG_INIT_COMMAND`。
- Master image 不執行持久化 Flash init script。
- 移除先前會讓 boot 卡在初始化階段的額外 post-init 強制呼叫。
- Slave image、PHY、QSFP lane、PTP 演算法、servo 與 JTAG observability 未修改。

## 編譯與映像 provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA-256：`be99f76886ad899b6efded328b0161d8c146b50cfe3bece36c2d84468102caf2`
- Master SOF SHA-256：`a3a9922a6584c24e37ef4bc8f217d78a2fd6793c8c844f60cad82a6c13636f77`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Firmware `.config`：`CONFIG_FORCE_MASTER_AFTER_INIT=y`、`CONFIG_INIT_COMMAND="vlan off;ptp stop;mode master;ptp start"`、`CONFIG_HAS_FLASH_INIT=1`。
- Quartus 結果：Fitter successful，Full Compilation successful，0 errors / 272 warnings；`timing_closed=NO`，最差 setup slack `-0.184 ns`、hold slack `-3.475 ns`，另有 4 個 unconstrained clocks。

## 燒錄結果

- 目標：`DE5 [1-11.1]`（Master）
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A31DBA`
- 結果：Configuration succeeded；Quartus Programmer 報告 0 errors / 0 warnings。
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-FLASH-SKIP-20260817/program_master.log`
- 另一次未成功的 shell invocation 只因分號未加引號，沒有改變 FPGA；該說明保存在同一 artifact 目錄。

## JTAG/runtime 原始結果

燒錄後立即於 2026-08-17 12:28:00 使用唯讀腳本
`scripts/jtag/read_wb_runtime.tcl` 讀取兩片板。

### Master（DE5 [1-11.1]）

- `cpu_marker=0x0000B004`、`reset=0`、`fault=0`：CPU/runtime 已執行到主迴圈。
- `WDIAGS_MODE=3`：仍是 Slave，不是預期的 Master `2`。
- `WDIAGS_PTP_RX=0`、`WDIAGS_PTP_TX=3`。
- `WDIAGS_SSTAT=0`、`WDIAGS_UCNT=0`。
- `WDIAGS_RXERR=1`：本次也觀察到接收錯誤計數。

### Slave（DE5 [1-11.2]）

- `cpu_marker=0x0000B004`、`reset=0`、`fault=0`。
- `WDIAGS_MODE=3`。
- `WDIAGS_PTP_RX=0x1AF4`、`WDIAGS_PTP_TX=0x18D7`。
- `WDIAGS_SSTAT=1`、`WDIAGS_CKO=0x12DE71C1`。

原始 runtime 紀錄：`artifacts/EXP-WRPC-MASTER-FLASH-SKIP-20260817/runtime_after_program.log`。

## Observation

1. 新 SOF 已確實燒錄，Master CPU 也正常離開 reset，不能把失敗歸因於 SOF 未載入或 CPU 未啟動。
2. 略過持久化 Flash init script 仍沒有讓 Master 留在 Master；`WDIAGS_MODE` 仍為 `3`。
3. Master 的 PTP RX 仍為 0，Slave 的 PTP RX/TX 仍在活動；本次沒有得到兩端同步成功的證據。
4. Quartus timing 尚未 closed，這是需要另外處理的風險，但本次最直接的角色失敗已在 runtime mode register 被觀察到。

## Conclusion

本實驗只支持以下結論：

> 略過持久化 Flash init script 仍不足以把 Master 角色建立起來。CPU/runtime 活著，但 Master 仍回報 Slave；因此目前不能宣稱 WR link 或時間同步成功，也不能把根因確定為單一 PHY 問題。

## Next Step

維持 PHY/PTP/servo 不變，直接檢查並修正 Master firmware 的角色設定呼叫路徑：讓 Master image 在 `wrc_initialize()`/task initialization 的最後明確套用 Master mode，並避免 `wrpc_spll_check_lock_with_timeout()` 阻塞 boot。新實驗必須先 compile，再燒錄，燒錄後立即記錄 `WDIAGS_MODE`，只有讀到 Master `2` 才進入後續 60 秒 servo/time-valid 觀測。
