# EXP-WRPC-MASTER-SHELL-DIRECT-20260817

## 實驗基本資料

- Experiment ID：`EXP-WRPC-MASTER-SHELL-DIRECT-20260817`
- 實驗日期：2026-08-17
- 實驗名稱：在 Master-only shell init callback 直接呼叫 Master role API
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`8851b52b1b53bf13a74f05a59173e627e14ced23`（補上Master角色API宣告）
- 目的：避開沒有生效的 built-in `mode master` parser，確認在 `shell_boot_script()` 的 Master-only callback 直接呼叫 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 與 `wrc_ptp_start()` 是否能完成角色切換。

## 相較於 baseline 的唯一修改

- 在 `vendor/wrpc-sw/shell/shell.c` 加入 `#include "wrpc.h"`。
- 在 `CONFIG_FORCE_MASTER_AFTER_INIT` 分支中，直接執行：

  ```c
  wrc_ptp_set_mode(WRC_MODE_MASTER);
  wrc_ptp_start();
  ```

- 保留上一版 Master-only non-blocking PLL 條件；未修改 `wrc_main.c`、PHY、QSFP lane、Slave defconfig、PTP packet filter、servo 或主迴圈。

## 編譯與映像 provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`
- Master MIF SHA-256：`4b6726b4950180b31ea9e224243a992db42905d95acb40d50e95a896ef258067`
- Master SOF SHA-256：`797f4c0432d14f5b1db4aec446d55a561adc78e243d4ef79daf844fd78449dca`
- Slave MIF SHA-256：`25c9533545597e4744d3444ee77f92634443ae19a8e0641a6a76464265d4a595`
- Slave SOF SHA-256：`05e03007e039ba8bb1f0011c2f83c3900ddd0db3b947bfbd5288d4e3f67a64c3`
- Master/Slave Full Compilation：均成功，0 errors；Master 272 warnings、Slave 274 warnings。
- 完整 build log、MIF、SOF 與 hash：保存在 pain 的 `artifacts/EXP-WRPC-MASTER-SHELL-DIRECT-20260817/`。

## 燒錄結果

### Slave（`DE5 [1-11.2]`）

- SOF checksum：`0x30A152A4`
- JTAG ID：`0x02E660DD`
- 結果：Configuration succeeded，0 errors / 0 warnings。

### Master（`DE5 [1-11.1]`）

- SOF checksum：`0x30A31DBA`
- JTAG ID：`0x02E660DD`
- 結果：Configuration succeeded，0 errors / 0 warnings。

原始燒錄紀錄：

- `artifacts/EXP-WRPC-MASTER-SHELL-DIRECT-20260817/program_slave.log`
- `artifacts/EXP-WRPC-MASTER-SHELL-DIRECT-20260817/program_master.log`

## JTAG/runtime 原始結果

使用 `scripts/jtag/read_wb_runtime.tcl`，於燒錄後取 immediate、10 秒、25 秒樣本。

| 時間點 | 板卡 | CPU marker | fault | `WDIAGS_MODE` | `SSTAT` | `PSTAT` | PTP RX | PTP TX | `TEMP` |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| immediate | Master | `B00B` | 0 | 0 | 0 | 0 | 0 | 0 | `B002` |
| immediate | Slave | `B004` | 0 | 3 | 0 | 1 | 0 | 0 | `A0000044` |
| 10 s | Master | `B00B` | 0 | 0 | 0 | 0 | 0 | 0 | `B002` |
| 10 s | Slave | `B004` | 0 | 3 | 0 | 1 | 0 | 0 | `A0000044` |
| 25 s | Master | `B00B` | 0 | 0 | 0 | 0 | 0 | 0 | `B002` |
| 25 s | Slave | `B004` | 0 | 3 | 0 | 1 | 0 | 0 | `A0000044` |

原始 runtime 紀錄：

- `artifacts/EXP-WRPC-MASTER-SHELL-DIRECT-20260817/runtime_immediate.log`
- `artifacts/EXP-WRPC-MASTER-SHELL-DIRECT-20260817/runtime_10s.log`
- `artifacts/EXP-WRPC-MASTER-SHELL-DIRECT-20260817/runtime_25s.log`

## Observation

1. Slave 完成正常 boot，保持 `B004` 與 `WDIAGS_MODE=3`，表示 Master-only 條件沒有誤傷 Slave。
2. Master 在 direct role API 呼叫後停在 `B00B/B002`，沒有達到 `B004`；這比 built-in script 版本更早中止，表示 direct `wrc_ptp_set_mode(MASTER)` 在目前 startup 時機不是安全入口，或產生的 firmware 仍含有未預期的 blocking/狀態依賴。
3. Master 沒有任何有效 PTP counter 或 WR state，不能把本次結果解讀成 PHY/光路失效，也沒有同步成功證據。

## Conclusion

本實驗只支持以下結論：

> 即使只在 Master image 的 shell init callback 直接呼叫既有 Master API，Master 仍會停在 `B002`；Slave 則正常。角色切換不能在目前這個 shell callback 直接呼叫 `wrc_ptp_set_mode(MASTER)`，下一步必須先確認 firmware 實際是否移除了 PLL wait，以及選用 WRPC 原本的安全 state-machine 入口，而不是繼續重複燒錄相同 API 呼叫。

## Next Step

1. 暫停新的硬體燒錄，先對 `8851b52` 的 Master ELF 做唯讀反組譯/符號檢查，確認 `CONFIG_FORCE_MASTER_AFTER_INIT` 分支是否真的生效。
2. 檢查 `wrc_ptp_set_mode()` 的初始化前置條件與 WR extension state；不要再修改 PHY/PTP/servo。
3. 恢復到能正常 `B004` 的 source baseline 後，才提出下一個單一 firmware 變因；若需要重新燒錄，必須另建 Experiment ID 並立即記錄。
