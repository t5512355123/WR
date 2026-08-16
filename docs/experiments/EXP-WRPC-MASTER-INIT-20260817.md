# EXP-WRPC-MASTER-INIT-20260817：修正 Master 啟動流程並觀測雙板 runtime

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-MASTER-INIT-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗分支：`exp/jtag-runtime-observability`
- Git commit：`9f848ec84b73328daca63b64d2725817e8802e60`
- 前一個已燒錄 baseline：`cee98e3`（反向 DDMTD 實驗紀錄）

## 這次想驗證什麼

前一輪 runtime 讀值顯示 Master 與 Slave 都是 `WDIAGS_MODE=3`，Master 停在 `PPS_LISTENING`，沒有進入 Master/PPS Master 角色。這次只驗證 Master 的啟動命令是否因為等待 `sfp match` 而沒有執行後續的 `mode master`。

判定重點：

- Master 是否進入 `WDIAGS_MODE=2`。
- Master 是否進入 `WDIAGS_PTP=6`（PPS Master）。
- Slave 是否看到較完整的 parent/servo 活動。
- 不把 Master 角色正確化誤認為兩端 White Rabbit 時間同步完成。

## 相較 baseline 唯一修改

只修改 `firmware/configs/de5a_master_defconfig` 的初始化命令，移除 `sfp match`：

```text
原本：vlan off;ptp stop;sfp match;mode master;ptp start
本次：vlan off;ptp stop;mode master;ptp start
```

本次沒有修改：

- QSFP-A lane 0、lane mapping、polarity、pre-emphasis 或 PHY line rate。
- DDMTD reverse 設定、DMTD/reference clock、SI5340、PTP filter、servo 或 SoftPLL 演算法。
- Slave firmware 或 Slave SOF。
- JTAG read-only 觀測工具。

## Build 證據

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Git commit：`9f848ec84b73328daca63b64d2725817e8802e60`
- Master：`Full Compilation was successful`、Fitter successful、`0 errors`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`9829fb3e346d16a25865698a033eb883a54c1e7e52c00238165dac680f62b6ff`
- Master SOF SHA-256：`c548bab576a61e3102391464e8790aa5dd71ead869cc85199005f5ac2bd7af0d`
- Master SOF checksum：`0x30A3010A`
- Fitter timing：`TIMING_CLOSED=NO`；worst setup slack `-0.177 ns`；worst hold slack `-3.493 ns`
- Slave：未重新 compile、未重新燒錄；沿用前一輪已燒錄的 Slave image。
- Slave 參考 image：MIF SHA-256 `2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0`；SOF SHA-256 `e020cb02a21693a656d4c3d93ce7a1e2d8b1593adca4b079474f4ff4d09ade99`。

## 燒錄結果

只燒錄 Master cable `DE5 [1-11.1]`：

```text
Info (213011): Using programming file .../DE5a_wr_master_jtag.sof with checksum 0x30A3010A
Info (209007): Configuration succeeded -- 1 device(s) configured
Info (209011): Successfully performed operation(s)
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

燒錄時間：`2026-08-17 04:24:21` 至 `04:24:40`（pain terminal）。

## JTAG/runtime 原始結果

使用既有 `read_wb_runtime.tcl` 唯讀讀取；沒有寫入 `WDIAGS_CTRL.DATA_SNAPSHOT`，也沒有修改 PHY、PTP、servo 或 SoftPLL 設定。每次讀取均為 `WDIAGS_CTRL=00000001`，表示 frame data valid。

### Snapshot A

```text
Master status_probe: 61100E61365C82FF
Master cpu_marker: 0x0000B004 seen=1
Master cpu_debug: PC=0x0000B0F0 reset=0 fault=0 im_valid=1
Master WDIAGS_SSTAT: 00000000
Master WDIAGS_PSTAT: 00000001
Master WDIAGS_PTP:   00000006
Master WDIAGS_MODE:  2
Master WDIAGS_PTP_RX:000000BE
Master WDIAGS_PTP_TX:000001A9
Master WDIAGS_FOREIGN_META:00000001

Slave status_probe: 8572FAE133BC82CF
Slave cpu_marker: 0x0000B004 seen=1
Slave cpu_debug: PC=0x00017078 reset=0 fault=0 im_valid=1
Slave WDIAGS_SSTAT: 00000001
Slave WDIAGS_PSTAT: 00000001
Slave WDIAGS_PTP:   00000009
Slave WDIAGS_MODE:  3
Slave WDIAGS_PTP_RX:000005BC
Slave WDIAGS_PTP_TX:000006C5
Slave WDIAGS_FOREIGN_META:03000001
Slave WDIAGS_CKO:   0210A021
Slave WDIAGS_UCNT:  0000000A
```

### Snapshot B（約 10 秒後）

```text
Master status_probe: 91100E43265082FF
Master cpu_marker: 0x0000B004 seen=1
Master cpu_debug: PC=0x00016FF8 reset=0 fault=0 im_valid=1
Master WDIAGS_SSTAT: 00000000
Master WDIAGS_PSTAT: 00000001
Master WDIAGS_PTP:   00000006
Master WDIAGS_MODE:  2
Master WDIAGS_PTP_RX:000000D7
Master WDIAGS_PTP_TX:000001E4
Master WDIAGS_FOREIGN_META:00000001

Slave status_probe: E572FAE333BC82EF
Slave cpu_marker: 0x0000B004 seen=1
Slave cpu_debug: PC=0x0000EFD8 reset=0 fault=0 im_valid=1
Slave WDIAGS_SSTAT: 00000001
Slave WDIAGS_PSTAT: 00000001
Slave WDIAGS_PTP:   00000009
Slave WDIAGS_MODE:  3
Slave WDIAGS_PTP_RX:000005F4
Slave WDIAGS_PTP_TX:000006CB
Slave WDIAGS_FOREIGN_META:03000001
Slave WDIAGS_CKO:   02743C21
Slave WDIAGS_UCNT:  0000000D
```

完整的兩次 pain terminal runtime 輸出保存於：

```text
build/artifacts/EXP-WRPC-MASTER-INIT-20260817/runtime_after_program.log
```

檔案 SHA-256：`9C2C2E43796F04CCD6D03158976556D2435EA69C0B8F6975339345F17951D3FA`

## Observation

1. Master 連續兩次都是 `WDIAGS_MODE=2`、`WDIAGS_PTP=6`，而且 status low byte 為 `0xFF`。依目前 mapping，Master 的 link、PHY、PPS 與 time-valid bits 都已為 1。
2. 因此移除 Master boot command 的 `sfp match` 後，Master 確實不再停在原先的 `mode=3/PPS_LISTENING`；本次局部假設獲得支持。
3. Slave 仍是 `WDIAGS_MODE=3`、`WDIAGS_PTP=9`，status low byte 由 `0xCF` 變為 `0xEF`，表示 pps-valid bit 出現，但 time-valid bit 仍為 0。
4. Slave PTP RX/TX counter 持續增加，`FOREIGN_META=03000001`，且 `CKO` 與 `UCNT` 在兩次讀值間變化，支持 parent/servo 路徑有活動。
5. Slave `WDIAGS_PSTAT=1`，目前沒有可宣稱的 SoftPLL locked 證據；`time_valid=0` 也表示雙板同步尚未完成。
6. 兩片 CPU 都 `reset=0`、`fault=0`、`im_valid=1`，marker 都為 `0xB004`，所以本次不是 CPU 未啟動的證據。

## Conclusion

本實驗的證據支持：

> 移除 Master 啟動命令中的 `sfp match`，成功讓 Master 進入 `WDIAGS_MODE=2/PPS_MASTER`；之前的 Master 角色啟動問題已被局部修正。

本實驗的證據不支持：

> 兩片 DE5a 已完成 White Rabbit 時間同步。

因為 Slave 仍沒有 `time_valid=1`，`PSTAT` 也沒有顯示 SoftPLL lock。問題目前仍優先落在 Slave parent/servo/SoftPLL 到 `time_valid` 的路徑，尚不能把根因定義成單一 gating、calibration 或 DMTD wiring 問題。

## Next Step

下一輪仍只做唯讀 observability，不先改 PHY 或 servo：

1. 以同一 JTAG session 觀測 Slave 的 `SSTAT` state field、`PSTAT.locked`、`UCNT`、`CKO/SETP`、`FOREIGN_META`、`PARSE_META`、`PPS_ESCR` 與 status bits 的轉換。
2. 若 Slave 的 `UCNT` 持續增加但 `PSTAT.locked` 長時間維持 0，再檢查 SoftPLL sequence/lock feedback；若 locked=1 但 time-valid 仍 0，才把 validity gating 列為主要假設。
3. Master 本次設定先保留，不再把 `sfp match` 加回去；下一個可燒錄變因必須另立 commit 與實驗紀錄。

