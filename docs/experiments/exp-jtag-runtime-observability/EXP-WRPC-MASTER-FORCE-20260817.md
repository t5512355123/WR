# EXP-WRPC-MASTER-FORCE-20260817：初始化後固定 Master 角色

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-MASTER-FORCE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 目的：驗證 Master firmware 在所有啟動腳本執行後重新套用 `WRC_MODE_MASTER`，能否避免板上舊角色設定覆寫 Master。

## Git 來源

- Branch：`exp/jtag-runtime-observability`
- Commit：`a93423a493d95f20292b2eecb2e595293c8045eb`
- 本次唯一功能變更：新增 `CONFIG_FORCE_MASTER_AFTER_INIT=y`；在 `wrc_tasks_run_inits()` 後呼叫 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 與 `wrc_ptp_start()`，並在 Master built-in init script 中加入 `init erase`。
- 未修改 PHY、PCS/lane、DMTD、servo 演算法、SI5341/SI5340 控制或 Slave image。

## Image / build provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Project：`DE5a_wr_master_jtag`
- Master MIF SHA-256：`72a8ee07f27146b9bfa35e6d903b966b7fd79d0f81654dd4a2a94c15dbe21ed9`
- Master SOF SHA-256：`73378bf954176a8495f53e45b3e58f91b0a97a8d5c5057fd04b99579543562e0`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave image reused：SOF SHA-256 `f45a648f0e380a5ed0238f2d1030ebea9943cba93066c1f5cbc7247d40aa4a67`；MIF SHA-256 `578d526306bf28721412d2a7a51f928a169bc1561e20a404de726d51df669ecb`
- Quartus compile：`Full Compilation was successful`，0 errors；`TIMING_CLOSED=NO`。

## 燒錄結果

- Programmer cable：`DE5 [1-11.1]`
- Device JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A31DBA`
- 結果：Quartus Programmer 回報 `Configuration succeeded`、0 errors、0 warnings。
- 原始紀錄：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-FORCE-20260817/program_master.log`

## JTAG / runtime 原始結果

### 燒錄後約 15 秒

Master：

```text
cpu_marker: 0x0000B00B seen=1
WDIAGS_CTRL: 00000000
WDIAGS_TEMP: 0000B002
WDIAGS_MODE: 0
WDIAGS_PTP_RX:00000000
WDIAGS_PTP_TX:00000000
```

此時診斷 RAM 尚未有效，不能解讀為 Master/Slave 同步狀態。

### 等待約 70 秒後

Master 仍為：

```text
cpu_marker: 0x0000B00B seen=1
WDIAGS_CTRL: 00000000
WDIAGS_TEMP: 0000B002
WDIAGS_MODE: 0
WDIAGS_PTP_RX:00000000
WDIAGS_PTP_TX:00000000
```

Slave 當時仍為：

```text
WDIAGS_CTRL: 00000001
WDIAGS_SSTAT:00000001
WDIAGS_PSTAT:00000000
WDIAGS_PTP_META:03000003
WDIAGS_MODE: 3
WDIAGS_PTP_RX:00001AF1
WDIAGS_PTP_TX:000018D4
```

- 原始紀錄：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-FORCE-20260817/runtime_after_program.log`
- 原始紀錄：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-FORCE-20260817/runtime_after_timeout.log`

## Observation

1. Quartus compile 與 FPGA configuration 都成功。
2. Master CPU 停在 boot marker `B002`，沒有到達 `B004`，`WDIAGS_CTRL=0`，因此 Master runtime diagnostics 尚未有效。
3. Slave 仍是 `WDIAGS_MODE=3`，且 `WDIAGS_PSTAT` 沒有 link/lock 成功證據。
4. 這次結果不能支持「Master role 已固定」或「兩片已同步」。
5. 目前最合理的下一步是移除會在 WRPC 初始化路徑中造成阻塞的 post-task force call，改成讓 Master build 明確跳過 persistent Flash init loop，再用原本的 built-in `mode master` 驗證角色。

## Conclusion

本次只能確認：`a93423a` 的 Master SOF 可以成功燒錄，但 runtime 沒有完成正常啟動；因此本實驗失敗，沒有證明 WR link 或 time synchronization 成功，也沒有足夠證據把問題歸因於 PHY。

## Next Step

只改 firmware startup policy：保留 `cmd_init` 編譯，但在 `CONFIG_FORCE_MASTER_AFTER_INIT` 下不執行 persistent Flash init script，移除 `wrc_main.c` 的 post-task force call，重新 compile、燒錄並先確認 Master `WDIAGS_MODE=2`、`cpu_marker=B004`，再進行 60 秒雙板 read-only observation。
