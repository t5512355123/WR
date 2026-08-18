# EXP-WRPC-MASTER-PTP-MASTER-CMD-20260817

## 實驗基本資料

- Experiment ID：`EXP-WRPC-MASTER-PTP-MASTER-CMD-20260817`
- 實驗日期：2026-08-17
- 實驗名稱：只以內建 `ptp master` 指令設定 Master 角色
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`dad9f8709625b3dacc5f8f1b90969cef19eb34ab`（只用內建指令設定Master角色）
- 目的：確認把 Master 的內建初始化命令由 `mode master` 改為 `ptp master`，是否能讓 Master 在啟動後保持 Master 角色。

## 相較於 baseline 的唯一修改

Master firmware 的 `CONFIG_INIT_COMMAND` 由：

```text
vlan off;ptp stop;mode master;ptp start
```

改為：

```text
vlan off;ptp stop;ptp master;ptp start
```

其餘 `wrc_main.c`、PHY、QSFP lane、PTP 演算法、servo、Slave image 與 JTAG observability 均未修改。

## 編譯與映像 provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`
- Master MIF SHA-256：`40b3a42ffc49a27a6ccd493ae3fd5c9ad40080b8b8042a1e47a6353508354c5b`
- Master SOF SHA-256：`45c18bb42238ba0a072988e4882058c557da448bff42f591580d10ad2666cebc`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`578d526306bf28721412d2a7a51f928a169bc1561e20a404de726d51df669ecb`
- Slave SOF SHA-256：`f45a648f0e380a5ed0238f2d1030ebea9943cba93066c1f5cbc7247d40aa4a67`
- Fitter：Successful
- Full Compilation：successful
- Timing：`TIMING_CLOSED=NO`；worst setup slack `-0.184 ns`、worst hold slack `-3.475 ns`
- 未約束時脈：4；未約束 input paths：411；未約束 output paths：90

## 燒錄結果

- 燒錄目標：`DE5 [1-11.1]`（Master）
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A31DBA`
- 結果：Configuration succeeded；Quartus Programmer 為 0 errors / 0 warnings。
- 燒錄時間：2026-08-17 13:13:20 至 13:13:39（Asia/Taipei）
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-PTP-MASTER-CMD-20260817/program_master.log`

## JTAG/runtime 原始結果

使用唯讀腳本 `scripts/jtag/read_wb_runtime.tcl`，於 2026-08-17 13:13:50 讀取同一 JTAG session 的兩片板。

### Master（DE5 [1-11.1]）

- `cpu_marker=0x0000B004`、`reset=0`、`fault=0`、`im_valid=1`：CPU/runtime 已執行。
- `WDIAGS_MODE=3`：仍是 Slave，不是預期的 Master `2`。
- `WDIAGS_PTP_RX=0x00000000`、`WDIAGS_PTP_TX=0x00000003`。
- `WDIAGS_SSTAT=0x00000000`、`WDIAGS_PSTAT=0x00000001`、`WDIAGS_UCNT=0`。
- `WDIAGS_PARSE_META=0x0000000C`、`WDIAGS_RXERR=0`。

### Slave（DE5 [1-11.2]）

- `cpu_marker=0x0000B004`、`reset=0`、`fault=0`、`im_valid=1`：CPU/runtime 已執行。
- `WDIAGS_MODE=3`。
- `WDIAGS_PTP_RX=0x00001D01`、`WDIAGS_PTP_TX=0x00001C04`。
- `WDIAGS_SSTAT=0x00000001`、`WDIAGS_PSTAT=0x00000001`、`WDIAGS_UCNT=0`。
- `WDIAGS_FOREIGN_META=0x0000FF01`、`WDIAGS_PARSE_META=0x0001010B`、`WDIAGS_RXERR=0`。

原始 runtime 紀錄：`artifacts/EXP-WRPC-MASTER-PTP-MASTER-CMD-20260817/runtime_after_program.log`。

## Observation

1. Master SOF 確實成功燒錄，且 Master/Slave 的 CPU 都離開 reset；因此本次不是「燒錄失敗」或「CPU 沒有啟動」。
2. Master 已到達 `B004`，但 `WDIAGS_MODE` 仍為 `3`，所以把命令名稱由 `mode master` 改為 `ptp master` 沒有讓角色切換成 Master。
3. Slave 仍有持續增加的 PTP RX/TX counter，表示目前仍有 PTP 封包路徑活動；本實驗沒有證據支持 PHY 已失效。
4. 目前尚不能由這次結果判定是命令沒有執行、命令執行後又被覆寫，或模式設定在既有啟動流程中被阻擋；需要下一個更小的 firmware 變因。

## Conclusion

本實驗只支持以下結論：

> 內建 `ptp master` 命令沒有使 Master 映像在 runtime 讀到 `WDIAGS_MODE=2`。因此目前尚未證明 Master/Slave 已完成 WR 時間同步，也不能把問題直接歸因於光纖、PHY 或 Slave SoftPLL。

## Next Step

回到 `wrc_initialize()` 的既有角色設定位置，只把原本已存在的：

```c
wrc_ptp_set_mode(WRC_MODE_SLAVE);
```

替換成：

```c
wrc_ptp_set_mode(WRC_MODE_MASTER);
```

不新增函式呼叫、不改主迴圈、不改 PHY/PTP/servo。完成 compile 後重新燒錄並立即記錄 `WDIAGS_MODE`、`PSTAT`、`SSTAT`、`PTP_RX/TX` 與 CPU marker；若成功得到 `mode=2`，再進行同一 JTAG session 的唯讀 60 秒 time-series。
