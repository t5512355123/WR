# EXP-WRPC-MASTER-DIRECT-ROLE-20260817

## 實驗資訊

- Experiment ID：`EXP-WRPC-MASTER-DIRECT-ROLE-20260817`
- 日期：2026-08-17
- 實驗名稱：初始化 task 完成後直接設定 Master 角色
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`c598475c8e2f9564c1e035de1b72d32102f95ec9`
- 基準版本：`e36a8b3`（保留 shell marker，但 runtime 仍為 mode 3）
- Quartus：Quartus Prime 17.0 Build 595 (04/25/2017 SJ Standard Edition)

## 想驗證什麼

驗證 Master 在 `wrc_tasks_run_inits()` 完成後，直接呼叫 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 與 `wrc_ptp_start()` 是否能穩定進入 Master role，並觀察 Slave 是否因此開始進入 parent/servo/SoftPLL 同步流程。

## 相較 baseline 的唯一修改

只在 Master 組態的 `wrc_main.c` 中，於所有初始化 task 完成後加入：

```c
wrc_ptp_set_mode(WRC_MODE_MASTER);
wrc_ptp_start();
```

本輪沒有修改 PHY、QSFP、PTP filter、servo、SI5340、PPS、clock constraint 或 Slave firmware。

## 來源與建置證據

- Master firmware build：成功
- Master MIF SHA-256：`055c0bf960afb7662465cc11eb0c40123668d51b6f9f4adbaee7db0b38764775`
- Master Quartus full compilation：`COMPILE_RC=0`、`0 errors`、warnings 以原始 log 為準
- Master SOF SHA-256：`09da4b60708616847bfb6db2ea0ed9c9ee918e5dcdb8fb035a0d4c555ca23243`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave 維持上一輪已燒錄版本：SOF `d153b51ecf7de857f9a3e28fbceb08d94ee5e6020e54f7a78bc7617ff0ae10e1`

## 燒錄結果

- 燒錄時間：2026-08-17 15:21:52 至 15:22:11（Asia/Taipei）
- cable：`DE5 [1-11.1]`
- device：`10AX115N2F45@1`
- JTAG ID：`0x02E660DD`
- SOF checksum：`0x30A31DBA`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：`0 errors, 0 warnings`

以上燒錄結果已先於 runtime 觀察寫入本紀錄。pain 原始證據：

`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-DIRECT-ROLE-20260817/`

- `provenance.txt`
- `build_master_firmware.log`
- `master_mif.sha256`
- `quartus_master_compile.log`
- `master_sof.sha256`
- `program_master.log`

## Runtime 原始結果

同一 JTAG session 的 `t=0s`、`t=10s`、`t=60s` read-only observation 已完成；完整輸出寫入上述 artifact 目錄的 `runtime_readings.log`，整理摘要寫入 `runtime_summary.log`。

### Master：DE5 [1-11.1]

| 時間 | marker | WDIAGS_MODE | SSTAT | PSTAT | PTP RX/TX | 其他觀察 |
|---|---|---:|---:|---:|---|---|
| 0 s | `0x0000B00B` | 0 | 0 | 0 | `0x0 / 0x0` | CPU fault=0，但 runtime diagnostics 尚未初始化 |
| 10 s | `0x0000B00B` | 0 | 0 | 0 | `0x0 / 0x0` | PC 約在 `0x53A4`，internal store count 不動 |
| 60 s | `0x0000B00B` | 0 | 0 | 0 | `0x0 / 0x0` | 仍停在同一 boot stage，沒有 PTP 活動 |

### Slave：DE5 [1-11.2]

Slave 維持上一輪 bitstream，0/10/60 秒仍為 `WDIAGS_MODE=3`；`PTP_RX=0x443`、`PTP_TX=0x4F1` 沒有明顯前進，`SSTAT=1`、`PSTAT=0`、`UCNT=0`。Slave 沒有因 Master 新版 firmware 而取得同步。

## Observation

1. Master 在 60 秒內始終停留在 `B00B`，沒有到達 `B001/B004` 或 shell marker；因此本輪沒有實際執行到 `wrc_tasks_run_inits()` 後的直接 Master API 呼叫。
2. Master 的 CPU fault=0 並不表示 firmware 已正常完成 boot；boot marker 與 PTP/WDIAGS 全零顯示它卡在更早的初始化路徑。
3. Slave 仍可被讀取，但沒有取得 Master parent/servo lock 的證據；本輪沒有 `time_valid=1` 或 `pps_valid=1` 證據。

## 恢復動作

為避免將板子留在 `B00B` boot hang 狀態，runtime log 保存後，使用 Git detached worktree `e36a8b3` 重新 build/compile 已知可進入 runtime 的 Master baseline。這是恢復動作，不把它誤當成同步實驗成功。

- restore worktree commit：`e36a8b3d2986e96436e6c229834f16640bd50a29`
- restore firmware MIF SHA-256：`409ca7097696df2324a15c1cdd65e32f73766bc6c0a9f60a5b1feca5530ef4c6`
- restore Quartus compile：`COMPILE_RC=0`
- restore SOF SHA-256：`a2ff592aeb35bb78da66814c11787f9f8880f8a3b212fdf5469060259e3f974a`
- restore burn time：2026-08-17 15:29:50 至 15:30:09（Asia/Taipei）
- restore cable：`DE5 [1-11.1]`
- restore device/JTAG ID：`10AX115N2F45@1` / `0x02E660DD`
- restore SOF checksum：`0x30A31DBA`
- restore result：`Configuration succeeded -- 1 device(s) configured`
- restore Programmer：`0 errors, 0 warnings`

restore 原始證據保存在：

- `restore_build_master_firmware.log`
- `restore_master_mif.sha256`
- `restore_quartus_master_compile.log`
- `restore_master_sof.sha256`
- `restore_program_master.log`

## Conclusion

本輪失敗。直接加入 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 與 `wrc_ptp_start()` 的程式碼雖然成功編譯與 configuration，但 runtime 在到達該程式碼以前就停在 `B00B`；所以本輪不能判斷 direct API 是否能切換 Master，也不能宣稱任何 WR synchronization。這個結果支持「本次 firmware image/layout 使早期初始化卡住」的觀察，但尚未證明根因是程式碼本身、記憶體配置或其他硬體條件。

## Next Step

先確認恢復版 Master 回到正常 runtime，再保留 `e36a8b3` 作為安全 baseline。下一個功能實驗不能直接重複本輪 early-init 敏感的 direct API 變更，應先以更小的、可觀測且不改變 firmware boot layout 的方式確認 shell init task 是否真的被排程執行。
