# EXP-WRPC-MASTER-TASK-20260817

## 實驗基本資料

- 實驗日期：2026-08-17
- 實驗名稱：主迴圈後一次性 Master task 驗證
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`2ecf3c4`（讓Master在主迴圈後套用角色）
- 目的：避免在 `wrc_initialize()` 早期呼叫 Master role，改在主迴圈啟動後由一次性 task 以非阻塞方式套用。

## 相較於 baseline 的唯一修改

- 恢復 `wrc_initialize()` 原本的 `WRC_MODE_SLAVE` 初始化順序。
- 新增 `force-master` task，在主迴圈後只執行一次 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 與 `wrc_ptp_start()`。
- Master role 設定仍略過 SoftPLL blocking wait。
- Slave、PHY、QSFP lane、DMTD、PTP state machine 與 JTAG observability 未修改。

## 編譯與映像 provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA-256：`a64869c2945c8dd5c16908553e74104f19faee96b8894973082b5c2043314cfa`
- Master SOF SHA-256：`5aee2b53ddb52d9c5ed437d016ff4d69f953b783f7b693b2603f1d6b3507fed5`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Quartus 結果：Fitter successful，Full Compilation successful，0 errors / 272 warnings；`timing_closed=NO`，最差 setup slack `-0.184 ns`、hold slack `-3.475 ns`。

## 燒錄結果

- 目標：`DE5 [1-11.1]`（Master）
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A31DBA`
- 結果：Configuration succeeded；Quartus Programmer 報告 0 errors / 0 warnings。
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-TASK-20260817/program_master.log`

## JTAG/runtime 原始結果

燒錄後立即於 2026-08-17 12:52:09 使用
`scripts/jtag/read_wb_runtime.tcl`。

### Master（DE5 [1-11.1]）

- `cpu_marker=B00B`、`WDIAGS_TEMP=B002`、`reset=0`、`fault=0`。
- `PC=0x000053A4`，對應 `timer_delay`。
- `WDIAGS_MODE=0`、`WDIAGS_PTP_RX=0`、`WDIAGS_PTP_TX=0`。

### Slave（DE5 [1-11.2]）

- `cpu_marker=B004`、`WDIAGS_MODE=3`。
- `WDIAGS_PTP_RX=0x1C50`、`WDIAGS_PTP_TX=0x1AF6`。

原始紀錄：`artifacts/EXP-WRPC-MASTER-TASK-20260817/runtime_after_program.log`。

## Observation

1. 這次新增的 `force-master` task 沒有被執行到，因為 Master 在進入主迴圈前已停在 B002。
2. Slave 仍可到達 B004 並持續有 PTP RX/TX，失敗集中在 Master early initialization。
3. 因此本次不能判斷 task 方式能否把 Master mode 設為 `2`。

## Conclusion

本實驗只支持以下結論：

> `2ecf3c4` 雖然成功編譯與燒錄，但 Master 在 B002 停止，沒有同步成功證據；新增 task 的版本不可直接作為下一個同步 baseline。

## Next Step

先以 `17ac382` 的已知可到達 B004 的 Master 映像做 A/B burn，確認 B002 是否由本次新增的 firmware code/task 觸發。確認後再用不增加 task table 項目的方式，於既有 `check-link` job 中加入一次性 Master role activation。
