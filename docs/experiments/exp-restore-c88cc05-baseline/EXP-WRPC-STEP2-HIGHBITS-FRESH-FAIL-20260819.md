# EXP-WRPC-STEP2-HIGHBITS-FRESH-FAIL-20260819

## 實驗識別

- 實驗名稱：`Step 2 fresh HEAD 高位 clock activity probe 恢復測試（失敗）`
- 日期：2026-08-19
- Branch：`exp/restore-c88cc05-baseline`
- Git commit：`bf71b9ed87163690a53ce76d7e48868103457c3c`
- 變因：將 Master/Slave `clock_activity_probe[63:54]` 恢復為 historical `9f848ec` 的固定 0；保留 625 MHz WR system clock、reset release、`g_softpll_reverse_dmtds => true`、JTAG/CPU/PTP observability 以及既有 startup command。
- 目的：驗證高位 clock activity probe 是否為 Master role regression 的必要原因。

## Build provenance

- clean worktree：`/home/b10504072/04_WR_step2_head`
- Git HEAD：`bf71b9ed87163690a53ce76d7e48868103457c3c`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`a098f6d4f3c6deadf80196d752d8db5eebf6830c45f435808c32f019c9a5bdbc`
- Slave MIF SHA256：`7fc8fe9080b12d03449d6077011171b7613a509c1b5c52c156be5e8ba5124acc`
- Master SOF SHA256：`04d58f25fedaeca3ec7551a1797c8c6e3d2942ee1f9a56a195c176a06fa7d339`
- Slave SOF SHA256：`09843d51eb578b2931827e26f0471673461571ae37bb8cc5125f9de9db8fec7f`
- Compile：Master/Slave 均 `Full Compilation was successful`
- Timing：Master/Slave 均 `TIMING_CLOSED=NO`
- Compile logs：`/home/b10504072/04_WR_step2_head/build/quartus_jtag_master_compile.log`、`/home/b10504072/04_WR_step2_head/build/quartus_jtag_slave_compile.log`

## 燒錄 provenance

- Master cable：`DE5 [1-11.1]`
- Master programmer checksum：`0x309F7BEE`
- Master：`Configuration succeeded`，0 errors，0 warnings
- Slave cable：`DE5 [1-11.2]`
- Slave programmer checksum：`0x30A4AAA4`
- Slave：`Configuration succeeded`，0 errors，0 warnings
- Programmer logs：
  - `/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-MILESTONE-20260819-BF71B9E/program_master.log`
  - `/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-MILESTONE-20260819-BF71B9E/program_slave.log`

## Runtime raw evidence

- Snapshot：`/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-MILESTONE-20260819-BF71B9E/runtime_snapshot.log`
- Script：`scripts/jtag/read_wb_runtime.tcl`
- JTAG script result：successful，0 errors，0 warnings。

### Master（DE5 [1-11.1]）

- MAC：`02:00:22:33:44:01`
- CPU：reset=0、fault=0、im_valid=1、marker=`B004` 且 seen=1
- Endpoint/link：link_up=1、link_ok=1、PHY/RX/TX ready 正常
- MiniNIC：`WDIAGS_TX=0x7B`、`WDIAGS_RX=0x79`
- PTP counter：`WDIAGS_PTP_RX=0x3C`、`WDIAGS_PTP_TX=0x20`
- **Role fail：`WDIAGS_MODE=3`、`WDIAGS_PTP=4`（LISTENING）**
- Foreign：`WDIAGS_FOREIGN_META=0x0000FF00`

### Slave（DE5 [1-11.2]）

- MAC：`02:00:22:33:44:02`
- CPU：reset=0、fault=0、im_valid=1、marker=`B004` 且 seen=1
- Endpoint/link：link_up=1、link_ok=1、PHY/RX/TX ready 正常
- MiniNIC：`WDIAGS_TX=0x83`、`WDIAGS_RX=0x5B`
- PTP counter：`WDIAGS_PTP_RX=0x20`、`WDIAGS_PTP_TX=0x3C`
- **Role fail：`WDIAGS_MODE=3`、`WDIAGS_PTP=4`（LISTENING）**
- Foreign：`WDIAGS_FOREIGN_META=0x0000FF01`，未形成穩定的 `0x03000001`。

## 結果與判定

| 驗證項目 | 結果 |
|---|---|
| Exact HEAD fresh firmware/build | PASS |
| Exact HEAD fresh clean Quartus SOF | PASS |
| 雙板 programming | PASS |
| CPU/PHY/Endpoint/MiniNIC/PTP counter activity | PASS |
| Master=`MODE=2`、`PPS_MASTER=6` | FAIL |
| Slave=`MODE=3`、`PPS_SLAVE=9` | FAIL，本次為 PTP=4 |
| Slave stable foreign master | FAIL |
| Step 2 overall | **FAIL** |

## Conclusion

將 clock activity probe 高位恢復為固定 0，仍不能讓最新 HEAD 在 fresh SOF 上進入 Master role。因此「高位 clock activity probe 直接接線」不是目前唯一或充分的根因。證據仍支持問題位於 startup role 設定尚未完成，或 Master `wrc_ptp_set_mode(WRC_MODE_MASTER)` 在 SoftPLL lock check 前後被阻塞；目前不能直接指向某個單一功能模組。

## Next Step

先檢查 `CONFIG_HAS_FLASH_INIT` 的持久化 user init script 是否覆寫 built-in startup command，以及 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 的 lock-wait 路徑；不改 Master role 設計、不改 Step 3/4 演算法，下一輪仍只做一個可追溯的變因。
