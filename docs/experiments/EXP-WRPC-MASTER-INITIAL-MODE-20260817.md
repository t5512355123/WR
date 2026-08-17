# EXP-WRPC-MASTER-INITIAL-MODE-20260817

## 實驗資訊

- Experiment ID：`EXP-WRPC-MASTER-INITIAL-MODE-20260817`
- 日期：2026-08-17
- 實驗名稱：在既有 PTP 初始化點設定 Master role
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`6aafa07`
- 基準版本：`e36a8b3`（可正常 boot，但 Master/Slave 都為 mode 3）
- Quartus：Quartus Prime 17.0 Build 595 (04/25/2017 SJ Standard Edition)

## 想驗證什麼

確認 Master 不依賴 shell parser 或 main 尾端新增 API，而是在 `wrc_initialize()` 已存在的 PTP mode 設定點直接使用 `WRC_MODE_MASTER`，能否讓 Master 進入 mode 2 並啟動 Slave 的 parent/servo/SoftPLL 路徑。

## 相較 baseline 的唯一修改

在 Master 組態下，將 `wrc_initialize()` 原本的：

```c
wrc_ptp_set_mode(WRC_MODE_SLAVE);
```

改為 `WRC_MODE_MASTER`；Slave 組態仍編譯原本的 `WRC_MODE_SLAVE`。同時移除上一輪 main 尾端 direct API 實驗的兩個呼叫，避免混入另一個變因。沒有修改 PHY、QSFP、PTP filter、servo、SI5340 或 timing constraints。

## 編譯與來源完整性

- Master firmware build：成功
- Master MIF SHA-256：`d73036acd5f18b99fbfa3565e40b0257f6f73add8dbc8951160c9ace7f3015e2`
- Master Quartus full compilation：`COMPILE_RC=0`
- Master SOF SHA-256：`3de365e1aebfd64ef47529753bd3ccc250172dc9316fba4895b3f8f1c6fcc8d0`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave 維持上一輪 baseline SOF：`d153b51ecf7de857f9a3e28fbceb08d94ee5e6020e54f7a78bc7617ff0ae10e1`

## 燒錄結果

- 燒錄時間：2026-08-17 15:41:59 至 15:42:18（Asia/Taipei）
- cable：`DE5 [1-11.1]`
- device：`10AX115N2F45@1`
- JTAG ID：`0x02E660DD`
- SOF checksum：`0x30A31DBA`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：`0 errors, 0 warnings`

以上燒錄結果已先寫入本紀錄。pain 原始證據：

`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-INITIAL-MODE-20260817/`

- `provenance.txt`
- `build_master_firmware.log`
- `master_mif.sha256`
- `quartus_master_compile.log`
- `master_sof.sha256`
- `program_master.log`

## Runtime 原始結果

同一 JTAG session 的 `t=0s`、`t=10s`、`t=60s` read-only observation 已完成；完整輸出寫入上述 artifact 目錄的 `runtime_readings.log`，摘要寫入 `runtime_summary.log`。

### Master：DE5 [1-11.1]

| 時間 | marker | WDIAGS_MODE | SSTAT | PSTAT | PTP RX/TX | 其他觀察 |
|---|---|---:|---:|---:|---|---|
| 0 s | `0x0000B00B` | 0 | 0 | 0 | `0x0 / 0x0` | CPU fault=0，boot 尚未完成 |
| 10 s | `0x0000B00B` | 0 | 0 | 0 | `0x0 / 0x0` | PC 約在 `0x53A4`，仍停在早期初始化 |
| 60 s | `0x0000B00B` | 0 | 0 | 0 | `0x0 / 0x0` | 沒有 PTP/WDIAGS 活動 |

### Slave：DE5 [1-11.2]

Slave 維持上一輪 baseline bitstream，0/10/60 秒為 `WDIAGS_MODE=3`、`SSTAT=1`、`PSTAT=0`、`UCNT=0`；PTP counter 有既有活動但沒有因本輪 Master 映像而完成同步。

## Observation

1. Master 在 60 秒內始終停在 `B00B`，沒有到達 `B001/B004`；因此本輪沒有正常完成 `wrc_initialize()`，也沒有進入 shell task 或 PTP runtime。
2. 相較 baseline，唯一功能變因是初始 PTP mode。證據支持 `WRC_MODE_MASTER` 在這個初始化時機造成 early-init hang，不能作為安全的 role switch 入口；尚不能只由 marker 判定卡在 `spll_init` 或其他 `wrc_ptp_set_mode` 子步驟。
3. Slave 仍未取得 Master parent/servo lock 的證據，沒有 `time_valid=1` 或 `pps_valid=1` 證據。

## Conclusion

本輪失敗。把既有初始化點的 mode 改成 Master 後，Master compile/configuration 雖成功，但 runtime 停在 `B00B`、WDIAGS 全零；因此不能宣稱 Master role 成功，更不能宣稱 WR synchronization。相較上一輪 main 尾端 direct API 的 `B00B`，本輪進一步支持「直接呼叫完整 `wrc_ptp_set_mode(MASTER)` 不是可安全插入的角色切換方式」，但仍需以更細的 register/boot marker 才能定位其內部阻塞點。

## Next Step

恢復 e36a8b3 baseline。下一輪不再呼叫完整 `wrc_ptp_set_mode(MASTER)`；先保留既有 Slave 初始化與 runtime，設計不改 boot flow 的單一觀測變因，確認 shell init task 是否執行以及 mode 是否曾短暫變成 2。任何新 role 設定都必須先通過 boot 不停在 `B00B` 的條件。

## 恢復燒錄證據

本輪 runtime log 保存後，使用 detached worktree `e36a8b3` 重建並恢復已知 baseline：

- restore worktree commit：`e36a8b3d2986e96436e6c229834f16640bd50a29`
- restore MIF SHA-256：`409ca7097696df2324a15c1cdd65e32f73766bc6c0a9f60a5b1feca5530ef4c6`
- restore Quartus compile：`COMPILE_RC=0`
- restore SOF SHA-256：`9c82b2ac6496029c7eced9d8953dacc7e9b3e42f6b7859b1e7ce9434ef3d2224`
- restore burn：2026-08-17 15:48:43 至 15:49:02（Asia/Taipei）
- restore cable/device/JTAG ID：`DE5 [1-11.1]` / `10AX115N2F45@1` / `0x02E660DD`
- restore checksum：`0x30A31DBA`
- restore result：`Configuration succeeded -- 1 device(s) configured`
- restore Programmer：`0 errors, 0 warnings`

恢復的原始 logs 與 hash 位於同一 artifact 目錄的 `restore_*` 檔案；恢復動作不代表同步成功。

### 恢復後 runtime check

2026-08-17 15:49:39 的 read-only JTAG check 顯示：

- Master：marker=`B004`、`WDIAGS_MODE=3`、`SSTAT=0`、`PSTAT=1`、PTP RX/TX=`0x11/0x0F`、CPU fault=0
- Slave：marker=`B004`、`WDIAGS_MODE=3`、`SSTAT=1`、`PSTAT=1`、PTP RX/TX=`0x5DC/0x6E4`、UCNT=0、CPU fault=0

Master 已恢復到可正常完成 boot 並有 PTP 活動的 baseline；兩端仍沒有完成同步的證據。
