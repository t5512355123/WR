# EXP-WRPC-MASTER-ROLE-20260817

## 實驗基本資料

- 實驗日期：2026-08-17
- 實驗名稱：Master 映像清除舊啟動腳本後的角色驗證
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`b6bcdbd`（清除Master舊啟動腳本固定角色）
- 目的：確認在 Master 的內建啟動指令前加入 `init erase`，是否能避免舊有 Flash init command 把 Master 改回 Slave。

## 相較於 baseline 的唯一修改

Master 的 `CONFIG_INIT_COMMAND` 由：

```text
vlan off;ptp stop;mode master;ptp start
```

改為：

```text
vlan off;ptp stop;init erase;mode master;ptp start
```

其餘 PHY、QSFP lane、PTP 演算法、servo 與 JTAG observability 均未修改。

## 編譯與映像 provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA-256：`dc40d52e9aac3623d2589119e927f8a6570a3f4852259613e6ebee835dbab8e4`
- Master SOF SHA-256：`2b8ddaa524566d6cf7739b5bd1f9e19447572dd9c147e9f1c8eea474e361a954`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- 編譯結果：Full Compilation successful；Quartus 報告 0 errors，timing closed 顯示為 NO。

## 燒錄結果

- 目標：`DE5 [1-11.1]`（Master）
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A31DBA`
- 結果：Configuration succeeded，Quartus Programmer 報告 0 errors / 0 warnings。
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-ROLE-20260817/program_master.log`

## JTAG/runtime 原始結果

讀取時間：2026-08-17 12:04:32，使用唯讀腳本
`scripts/jtag/read_wb_runtime.tcl`。

### Master（DE5 [1-11.1]）

- `cpu_marker=0x0000B004`、`reset=0`、`fault=0`：CPU/runtime 有在執行。
- `WDIAGS_MODE=3`：仍為 Slave，而不是預期的 Master `2`。
- `WDIAGS_PTP_RX=0x00000000`、`WDIAGS_PTP_TX=0x00000030`。
- `WDIAGS_SSTAT=0x00000000`、`WDIAGS_UCNT=0`。

### Slave（DE5 [1-11.2]）

- `cpu_marker=0x0000B004`、`reset=0`、`fault=0`：CPU/runtime 有在執行。
- `WDIAGS_MODE=3`。
- `WDIAGS_PTP_RX=0x00001A3D`、`WDIAGS_PTP_TX=0x0000181D`。
- `WDIAGS_SSTAT=0x00000001`、`WDIAGS_CKO=0x12DE71C1`。

原始 runtime 紀錄：`artifacts/EXP-WRPC-MASTER-ROLE-20260817/runtime_after_program.log`。

## Observation

1. 燒錄確實成功，且兩片 CPU 都已離開 reset，不能把結果解釋成 SOF 沒有載入或 CPU 沒有啟動。
2. Master 的 mode 仍然是 `3`。加入 `init erase` 沒有阻止角色最後變成 Slave。
3. Slave 的 PTP RX/TX、CKO 與狀態活動持續存在，因此 QSFP/PHY/PTP packet path 並非本次最直接的失敗點。

## Conclusion

本實驗只支持以下結論：

> `init erase` 不是有效的角色固定方法；Master 映像在啟動後仍讀到或執行了會把角色設為 Slave 的持久化流程。此時尚不能宣稱 WR 同步成功，也不能把根因擴大解釋成 PHY 或 SoftPLL 故障。

## Next Step

維持 PHY/PTP/servo 不變，只在 Master image 的 `shell_boot_script()` 略過持久化 Flash init script，保留內建 `mode master` 作為最後角色設定。完成後重新編譯、燒錄並立即以 JTAG 確認 `WDIAGS_MODE=2`，再進行唯讀 60 秒 runtime time-series。
