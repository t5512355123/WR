# EXP-WRPC-MASTER-DIRECT-ROLE-20260817

## 實驗基本資料

- Experiment ID：`EXP-WRPC-MASTER-DIRECT-ROLE-20260817`
- 實驗日期：2026-08-17
- 實驗名稱：將 `wrc_initialize()` 預設角色直接替換為 Master
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`4c82ca8fa1e696fa403942501b88ed8c92b8c2e9`（將Master預設角色直接設為Master）
- 目的：排除 shell init command/parser 與持久化 init script 影響，確認在 `wrc_initialize()` 直接呼叫 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 是否能讓 Master 成為 Master。

## 相較於 baseline 的唯一修改

在共用的 `vendor/wrpc-sw/wrc_main.c` 將：

```c
wrc_ptp_set_mode(WRC_MODE_SLAVE);
```

替換為：

```c
wrc_ptp_set_mode(WRC_MODE_MASTER);
```

原本的 `wrc_ptp_start()`、主迴圈、PHY、QSFP lane、PTP 演算法與 servo 均未改動。

重要限制：`wrc_main.c` 同時供 Master 與 Slave firmware 使用，因此這個 source-level 修改實際上同時改變了兩份 MIF；這是本次結果的重要解讀條件。

## 編譯與映像 provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`
- Master MIF SHA-256：`b4ed176b9545646d7323ce1905dfc5de4983ee7c64588bcf8eebf91f51e3eae9`
- Master SOF SHA-256：`b8de8cb4a8423ad17953148f492408ef65482a37e720eecfa8170222405a5a03`
- Slave MIF SHA-256：`3ac62089becaab1ac6e8237e1cc390840ea641c09c401080c4ffdbf3ab747c61`
- Slave SOF SHA-256：`24e719d30e8e41b142d843d0623f408df5a6a4e9f5711030ac428af3d6df4afd`
- Master/Slave QSF、SDC：與前一個 JTAG diagnostic project 相同，hash 收錄於本次 pain artifact 的 `project_hashes.sha256`。
- Master/Slave compile：兩者均 `Full Compilation was successful`，0 errors；Master 272 warnings、Slave 274 warnings。
- Timing：未宣稱 timing closure；沿用此 diagnostic project 的 timing report，需以 artifact 中的完整 STA 報告為準。

## 燒錄結果

### Slave

- 目標：`DE5 [1-11.2]`
- SOF checksum：`0x30A152A4`
- JTAG ID：`0x02E660DD`
- 結果：Configuration succeeded，0 errors / 0 warnings。
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-DIRECT-ROLE-20260817/program_slave.log`

### Master

- 目標：`DE5 [1-11.1]`
- SOF checksum：`0x30A31DBA`
- JTAG ID：`0x02E660DD`
- 第一次嘗試：JTAG cable 暫時未偵測，沒有配置結果。
- 重新列出 cable 後的重試：Configuration succeeded，0 errors / 0 warnings。
- 最終 immediate sample 前再次以同一 SOF 成功配置。
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-DIRECT-ROLE-20260817/program_master_final.log`

## JTAG/runtime 原始結果

使用 `scripts/jtag/read_wb_runtime.tcl`，於最後一次 Master 成功燒錄後讀取：

| 時間點 | 板卡 | CPU marker / fault | `WDIAGS_MODE` | `SSTAT` | `PSTAT` | PTP RX | PTP TX | `TEMP` | 判定 |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| immediate | Master | `B00B / 0` | 0 | 0 | 0 | 0 | 0 | `B002` | 卡在初始化 |
| immediate | Slave | `B00B / 0` | 0 | 0 | 0 | 0 | 0 | `B002` | 共用 source 也被改成 Master |
| 10 s | Master | `B00B / 0` | 0 | 0 | 0 | 0 | 0 | `B002` | 未離開初始化 |
| 10 s | Slave | `B00B / 0` | 0 | 0 | 0 | 0 | 0 | `B002` | 未離開初始化 |
| 25 s | Master | `B00B / 0` | 0 | 0 | 0 | 0 | 0 | `B002` | 未離開初始化 |
| 25 s | Slave | `B00B / 0` | 0 | 0 | 0 | 0 | 0 | `B002` | 未離開初始化 |

原始紀錄：

- `artifacts/EXP-WRPC-MASTER-DIRECT-ROLE-20260817/runtime_immediate.log`
- `artifacts/EXP-WRPC-MASTER-DIRECT-ROLE-20260817/runtime_10s.log`
- `artifacts/EXP-WRPC-MASTER-DIRECT-ROLE-20260817/runtime_25s.log`

## Observation

1. 兩份 SOF 都成功編譯、燒錄，且 JTAG 可讀到 CPU marker；因此不是 Quartus 配置失敗。
2. 兩片都停在 `B00B/B002`，沒有到達 `B004`，也沒有產生 PTP counter；這與 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 內部等待 SoftPLL lock 的行為一致。
3. 這次修改不是只影響 Master，因為 Master/Slave 共用 `wrc_main.c`；Slave 也被編譯成相同的 Master 初始化路徑。
4. 結果不足以判斷光纖、PHY、PTP packet path 或 Slave servo 的功能，因為兩片都尚未正常進入 runtime diagnostics。

## Conclusion

本實驗只支持以下結論：

> 直接把共用 `wrc_initialize()` 的角色設定改為 `WRC_MODE_MASTER` 會讓兩份 firmware 都進入會等待 SoftPLL lock 的初始化路徑，至少在 25 秒觀測內兩片都停在 `B002`。這不是可接受的 Master-only 修法，也沒有任何 WR synchronization 成功證據。

## Next Step

1. 先恢復共用 source 的 `WRC_MODE_SLAVE`，避免 Slave 再被誤編成 Master。
2. 利用 Master/Slave 各自的 Kconfig/defconfig 宏做條件化，且 Master 角色設定必須是 non-blocking；不能再直接呼叫 blocking 的 `wrc_ptp_set_mode(WRC_MODE_MASTER)`。
3. 重新建置兩份 MIF，確認 Master/Slave hash 與角色設定不同後再燒錄。
4. 成功進入 `B004` 後，重新做 read-only runtime 觀測；只有在 Master `mode=2`、Slave WR handshake/SoftPLL lock、`time_valid=1`、`pps_valid=1` 長時間穩定同時成立時，才可宣稱同步成功。
