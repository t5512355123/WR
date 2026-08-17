# EXP-WRPC-MASTER-FLASH-GUARD-20260817

## 實驗資訊

- 日期：2026-08-17
- 實驗名稱：避免 Master 初始化後被 Flash 腳本覆寫
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`811d01c8d9743a847ab434ff3054ecdcb60612b7`
- 基準版本：`48ce16f`；本次唯一功能變更為讓 Master 組態跳過持久化 Flash init script，避免它把已設定的 Master 角色改回 Slave。另有一個僅為 `-Werror` 修正的條件編譯宣告調整。
- Quartus：Quartus Prime 17.0 Build 595 (04/25/2017 SJ Standard Edition)

## 想驗證什麼

確認 `CONFIG_INIT_COMMAND="vlan off;ptp stop;ptp master;ptp start"` 設定出的 Master 角色，在 `shell_boot_script()` 執行期間不會再被 Flash init script 覆寫；同時確認 Slave 維持 Slave 角色，且兩邊 firmware runtime 與 PTP 封包路徑仍能運作。

## 相較基準唯一修改

在 `vendor/wrpc-sw/shell/shell.c` 將 Flash init script 的讀取迴圈放在 `#ifndef CONFIG_FORCE_MASTER_AFTER_INIT` 內。Master 組態因此只執行內建初始化命令，不讀取可能含有 `mode slave` 的持久化腳本。這不是 PHY、PTP filter、servo 或 SI5340 參數修改。

## 編譯與來源完整性

### Firmware

- Master MIF：`build/firmware/master/wrc.mif`
  - SHA-256：`251d183793ebed34c7bd2448c32ccfed3ee24d43d7567d8461244666219c97f7`
- Slave MIF：`build/firmware/slave/wrc.mif`
  - SHA-256：`e3e8c421e1ebcae881c1e27bdfe71261bd9e8e66937c8574e7e9d7962a96c65d`
- Master firmware build：成功
- Slave firmware build：成功

### Quartus

- Master compilation：`0 errors, 272 warnings`
- Slave compilation：`0 errors, 274 warnings`
- Master SOF SHA-256：`b018c21a76849d2a7adf955eeeb8acbef92a05a6b14d790ddec5d9eb1bc8ba7c`
- Slave SOF SHA-256：`d153b51ecf7de857f9a3e28fbceb08d94ee5e6020e54f7a78bc7617ff0ae10e1`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- 共用 SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`

## 燒錄結果

- Slave cable：`DE5 [1-11.2]`
  - Programmer：Quartus 17.0 Build 595
  - Device：`10AX115N2F45@1`
  - JTAG ID：`0x02E660DD`
  - SOF checksum：`0x30A152A4`
  - 結果：`Configuration succeeded -- 1 device(s) configured`
  - Programmer 結果：`0 errors, 0 warnings`
- Master cable：`DE5 [1-11.1]`
  - Programmer：Quartus 17.0 Build 595
  - Device：`10AX115N2F45@1`
  - JTAG ID：`0x02E660DD`
  - SOF checksum：`0x30A31DBA`
  - 結果：`Configuration succeeded -- 1 device(s) configured`
  - Programmer 結果：`0 errors, 0 warnings`

## 原始證據位置

所有原始輸出保存在 pain：

`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-FLASH-GUARD-20260817/`

- `provenance.txt`
- `build_master_firmware.log`
- `build_slave_firmware.log`
- `quartus_master_compile.log`
- `quartus_slave_compile.log`
- `program_master.log`
- `program_slave.log`
- `runtime_readings.log`

## Runtime 原始結果摘要

觀測方式：不寫入目標 Wishbone 暫存器；每個時間點重新建立 JTAG SignalTap session，讀取兩條 cable 上的 runtime mailbox 與 status probe。時間點為燒錄後約 0、10、25、60 秒。

### Master：`DE5 [1-11.1]`

| 時間 | marker / fault | `WDIAGS_MODE` | `SSTAT` | `PSTAT` | PTP RX/TX | `UCNT` | `CKO` |
|---:|---|---:|---:|---:|---|---:|---|
| 0 s | `B004` / `0` | `3` | `1` | `1` | `0x27 / 0x22` | `0` | `0` |
| 10 s | `B004` / `0` | `3` | `1` | `1` | `0x34 / 0x28` | `0` | `0` |
| 25 s | `B004` / `0` | `3` | `1` | `1` | `0x4D / 0x30` | `0` | `0` |
| 60 s | `B004` / `0` | `3` | `1` | `1` | `0x7A / 0x4E` | `0` | `0` |

### Slave：`DE5 [1-11.2]`

| 時間 | marker / fault | `WDIAGS_MODE` | `SSTAT` | `PSTAT` | PTP RX/TX | `UCNT` | `CKO` |
|---:|---|---:|---:|---:|---|---:|---|
| 0 s | `B004` / `0` | `3` | `1` | `1` | `0x27 / 0x24` | `2` | `0x005B9D21` |
| 10 s | `B004` / `0` | `3` | `1` | `1` | `0x2D / 0x33` | `0` | `0x005B9D21` |
| 25 s | `B004` / `0` | `3` | `1` | `1` | `0x35 / 0x4A` | `0` | `0` |
| 60 s | `B004` / `0` | `3` | `1` | `1` | `0x53 / 0x74` | `1` | `0x06361681` |

其他關鍵值：Master `PPS_ESCR=0x00000000`、Slave `PPS_ESCR=0x00000000`；兩邊 CPU fault 都是 0，`B004` marker 穩定，PTP RX/TX 都有增加。Master 的 `FOREIGN_META` 沒有選到 foreign master；Slave 的 `FOREIGN_META` 為 `0x00000001`，表示看見一筆 foreign record，但這不能取代 Master/Slave role 與 time-valid 證據。

## Observation

1. 本次 Flash init guard 沒有使 Master 進入 `WDIAGS_MODE=2`；0、10、25、60 秒均為 `WDIAGS_MODE=3`。
2. 兩片 CPU 都持續執行，marker=`B004`、fault=`0`，因此這次沒有看到 CPU boot crash。
3. PTP RX/TX counter 持續增加，表示封包活動仍存在；但 Master/Slave 兩端都呈現 mode 3，不能把封包活動解讀成已完成 WR 同步。
4. Slave 的 `SSTAT=1`、`PSTAT=1` 且 `UCNT`/`CKO` 有非零或變化，只能支持 servo 有活動，不能證明 SoftPLL locked 或 `time_valid=1`。

## Conclusion

本次實驗失敗於「尚未證明 Master 角色切換成功」，不是 FPGA configuration 失敗，也不是 CPU 已崩潰。現有證據不支持宣稱兩台 DE5a 已同步；Flash init script 覆寫雖然仍是合理疑點，但單獨加 guard 未解決 Master mode=3，根因尚未確定。

## 下一步

先檢查 Master 的 `CONFIG_INIT_COMMAND` 是否真的被編入本次 Master MIF，以及 `shell_boot_script()` 執行後 `ptp master` 的回傳值與目前 `wrc_ptp_set_mode()` 初始化流程；下一輪只增加可讀的 boot-stage/command-result observability，不改 PHY、PTP filter、servo 或 SI5340。確認 Master 先能得到 `WDIAGS_MODE=2` 後，才繼續追 Slave 的 `SSTAT`、`PSTAT.locked`、parent flags、`time_valid` 與 `pps_valid`。
