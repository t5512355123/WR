# EXP-WRPC-MASTER-NONBLOCKING-INIT-20260817

## 實驗基本資料

- Experiment ID：`EXP-WRPC-MASTER-NONBLOCKING-INIT-20260817`
- 實驗日期：2026-08-17
- 實驗名稱：Master 專用 non-blocking PLL 初始化與既有 `mode master` 啟動腳本
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`b4c93bf1bc4d6059dee775ce4daadfd721cb07da`（讓Master初始化不等待PLL鎖定）
- 目的：確認只在 Master 專用設定下略過 `wrc_ptp_set_mode(MASTER)` 的 20 秒 PLL wait，是否能讓既有 built-in `mode master` 命令切換 Master 角色，同時保持 Slave 的原始初始化流程。

## 相較於 baseline 的唯一修改

1. 恢復共用 `wrc_main.c` 的原始：

   ```c
   wrc_ptp_set_mode(WRC_MODE_SLAVE);
   ```

2. Master defconfig 保留 `CONFIG_FORCE_MASTER_AFTER_INIT=y`，並使用已知 parser 支援的：

   ```text
   vlan off;ptp stop;mode master;ptp start
   ```

3. 在 `wrc_ptp_set_mode()` 的 Master case 中，只有 `CONFIG_FORCE_MASTER_AFTER_INIT` 時略過 `wrpc_spll_check_lock_with_timeout(LOCK_TIMEOUT_FM)`；Slave 沒有該設定，仍使用原始流程。

沒有修改 PHY、QSFP lane、DMTD、PTP packet filter、servo、Slave defconfig 或主迴圈。

## 編譯與映像 provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`
- Master MIF SHA-256：`f14318d5d6756fb63298053098ffd6d72c4431927a70db42a621170e270832fc`
- Master SOF SHA-256：`b29d4db5be2dcb9f0f73ca81aa4726750e9be1cd80ef10655792b23fd203ad01`
- Slave MIF SHA-256：`89e85883654e5a5c71c6ba63131fee93f4e54488ebc1b972d1d6ade766c32171`
- Slave SOF SHA-256：`ca076b465232cc64532356aeae5a89cd1ba8b5f2856f7c3420fec75c8f0b67d5`
- Master/Slave Full Compilation：均成功，0 errors；Master 272 warnings、Slave 274 warnings。
- QSF、SDC hash 與完整 build log：保存在 pain 的 `artifacts/EXP-WRPC-MASTER-NONBLOCKING-INIT-20260817/`。

## 燒錄結果

### Slave（`DE5 [1-11.2]`）

- SOF checksum：`0x30A152A4`
- JTAG ID：`0x02E660DD`
- 結果：Configuration succeeded，0 errors / 0 warnings。
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-NONBLOCKING-INIT-20260817/program_slave.log`

### Master（`DE5 [1-11.1]`）

- SOF checksum：`0x30A31DBA`
- JTAG ID：`0x02E660DD`
- 結果：Configuration succeeded，0 errors / 0 warnings。
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-NONBLOCKING-INIT-20260817/program_master.log`

## JTAG/runtime 原始結果

使用 `scripts/jtag/read_wb_runtime.tcl`，Master/Slave 燒錄後取樣於 immediate、10 秒、25 秒。

| 時間點 | 板卡 | CPU marker | fault | `WDIAGS_MODE` | `SSTAT` | `PSTAT` | PTP RX | PTP TX | `UCNT` | `TEMP` |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| immediate | Master | `B004` | 0 | 3 | 0 | 1 | 3 | `0x03010204` | 0 | `A0000044` |
| immediate | Slave | `B004` | 0 | 3 | 0 | 1 | 3 | 5 | 0 | `A0000044` |
| 10 s | Master | `B004` | 0 | 3 | 0 | 1 | 9 | 9 | 0 | `A0000044` |
| 10 s | Slave | `B004` | 0 | 3 | 0 | 1 | 9 | `0x0B` | 0 | `A0000044` |
| 25 s | Master | `B004` | 0 | 3 | 0 | 1 | `0x0F` | `0x0F` | 0 | `A0000044` |
| 25 s | Slave | `B004` | 0 | 3 | 0 | 1 | `0x12` | `0x11` | 0 | `A0000044` |

原始紀錄：

- `artifacts/EXP-WRPC-MASTER-NONBLOCKING-INIT-20260817/runtime_immediate.log`
- `artifacts/EXP-WRPC-MASTER-NONBLOCKING-INIT-20260817/runtime_10s.log`
- `artifacts/EXP-WRPC-MASTER-NONBLOCKING-INIT-20260817/runtime_25s.log`

## Observation

1. 兩片 CPU 都成功離開 reset 並達到 `B004`，因此本次 non-blocking PLL 修改沒有造成前一實驗的 `B002` 問題。
2. Master 的 `WDIAGS_MODE` 在 25 秒內都為 `3`，沒有變成預期的 `2`；Master/Slave 的 PTP counter 都有活動，但兩片仍以 Slave mode 觀察到。
3. `SSTAT=0`、`UCNT=0`，尚未看到 Slave WR servo/SoftPLL 已鎖定的證據；更不能宣稱 `time_valid=1` 或 `pps_valid=1`。
4. 因為 CPU/runtime 正常但 built-in `mode master` 沒有改變 mode，下一步應避免再猜 parser 行為，直接在 Master-only 的 shell init callback 呼叫既有 `wrc_ptp_set_mode(WRC_MODE_MASTER)`，並保留同一個 non-blocking PLL 條件。

## Conclusion

本實驗只支持以下結論：

> Master-only non-blocking PLL 條件讓兩片都能正常完成 boot，但現有 built-in `mode master` 啟動命令沒有讓 Master 進入 `WDIAGS_MODE=2`。目前仍沒有 WR time synchronization 成功證據；問題已從 CPU boot/blocking 收斂到角色切換呼叫是否真正被套用。

## Next Step

只修改 `shell_boot_script()`：在 `CONFIG_FORCE_MASTER_AFTER_INIT` 下直接呼叫 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 與 `wrc_ptp_start()`，不修改 `wrc_main.c`、PHY、PTP/servo 或 Slave image。燒錄後重新取 immediate/10 秒/25 秒 runtime，成功判據先是 Master `mode=2` 且 PTP TX 持續增加；之後才進行 Slave WR state、SoftPLL lock、`time_valid`/`pps_valid` 的 60 秒唯讀觀測。
