# EXP-WRPC-MASTER-CHECK-LINK-BLOCKING-20260817

## 實驗基本資料

- 實驗日期：2026-08-17
- 實驗名稱：既有 check-link role 呼叫與原始 blocking PLL A/B
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`73e472a`（恢復Master原始PLL啟動流程）
- 目的：只撤回 Master `wrc_ptp_set_mode()` 的 non-blocking 分支，確認 B002 是否由該分支造成。

## 相較於 baseline 的唯一修改

- 保留既有 `wrc_check_link()` 的一次性 Master role 呼叫。
- 恢復 `wrc_ptp_set_mode(MASTER)` 原本的 `wrpc_spll_check_lock_with_timeout(20s)`。
- 其他 firmware、Slave、PHY、QSFP lane、DMTD、PTP state machine 與 JTAG observability 未修改。

## 編譯與映像 provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA-256：`5b3fc20c5df52879a6f873f6731b6bb01504e8ef5c910ff892d30ea9eef92235`
- Master SOF SHA-256：`33d588e50446b198e18d2878745306a31eacf8d5500e340d634c967884c31c24`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Quartus 結果：Fitter successful，Full Compilation successful，0 errors / 272 warnings；`timing_closed=NO`。

## 燒錄結果

- 目標：`DE5 [1-11.1]`（Master）
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A31DBA`
- 結果：Configuration succeeded；Quartus Programmer 報告 0 errors / 0 warnings。
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-CHECK-LINK-BLOCKING-20260817/program_master.log`

## JTAG/runtime 原始結果

燒錄後立即於 2026-08-17 13:07:02 讀取。

### Master（DE5 [1-11.1]）

- `cpu_marker=B00B`、`WDIAGS_TEMP=B002`、`reset=0`、`fault=0`。
- `WDIAGS_MODE=0`、`WDIAGS_PTP_RX=0`、`WDIAGS_PTP_TX=0`。
- `PC=0x000053A4`，對應 `timer_delay`。

### Slave（DE5 [1-11.2]）

- `cpu_marker=B004`、`WDIAGS_MODE=3`。
- `WDIAGS_PTP_RX=0x1CFE`、`WDIAGS_PTP_TX=0x1C01`。

原始紀錄：`artifacts/EXP-WRPC-MASTER-CHECK-LINK-BLOCKING-20260817/runtime_after_program.log`。

## Observation

1. 恢復 blocking PLL call 後，Master 仍停在 B002；check-link role 呼叫同樣沒有執行機會。
2. 與 17ac382 的 B004 A/B 比較，新增 `wrc_main.c` role code 是目前最可疑的影響來源，但不能只靠這次實驗單獨證明編譯器 layout 是唯一根因。
3. Slave 仍能執行並有 PTP counters，沒有兩端 WR synchronization 證據。

## Conclusion

本實驗只支持以下結論：

> 73e472a 編譯與燒錄成功，但 Master 仍停在 B002；把 blocking/non-blocking PLL call 切換回原始版本沒有恢復啟動。因此下一步應回到 17ac382 的 source layout，避免再修改 `wrc_main.c`，只測 built-in command 的文字差異。

## Next Step

恢復 17ac382 的 `wrc_main.c` 與 `wrc_ptp_ppsi.c`，只將 Master `CONFIG_INIT_COMMAND` 改為 `vlan off;ptp stop;ptp master;ptp start`。若新映像回到 B004 且 mode=2，便可確認問題是 init command 解析/角色套用，而非 PHY 或 SoftPLL 硬體路徑。
