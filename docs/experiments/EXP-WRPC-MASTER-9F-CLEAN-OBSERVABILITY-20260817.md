# EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817

## 實驗資訊

- Experiment ID：`EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817`
- 日期：2026-08-17
- 實驗名稱：乾淨 9f848ec Master role 加入唯讀 clock/reset observability
- Git branch：`exp/master-9f-observability`
- Git commit：`302ffc1`
- Master role 基底：`9f848ec84b73328daca63b64d2725817e8802e60`
- 唯讀 observability：`a7f28ec`、`5bddeda` 的 cherry-pick commits `584827c`、`302ffc1`
- Quartus：Quartus Prime 17.0 Build 595 (04/25/2017 SJ Standard Edition)

## 為了驗證什麼

前一個把後續多個 firmware/role 實驗疊在一起的版本，雖然 `status=0xEF` 且 link 已建立，卻沒有重現歷史 Master `WDIAGS_MODE=2、WDIAGS_PTP=6`。本實驗將變因縮小為：

1. 使用歷史 `9f848ec` 的 Master startup command：`vlan off;ptp stop;mode master;ptp start`。
2. 只加入已驗證且唯讀的 clock/reset probe：Slave `a7f28ec`、Master `5bddeda`。
3. 不帶入後續 `CONFIG_FORCE_MASTER_AFTER_INIT`、直接/延後 role API、shell marker、SI5340 runtime 或其他 role 實驗。

成功判準先限定為 Master diagnostic baseline：`marker=B004、WDIAGS_MODE=2、WDIAGS_PTP=6、status=0xFF、PTP RX/TX 持續增加`。這仍不等於兩端 WR 時間同步成功。

## 編譯與來源完整性

- Master firmware build：成功
- Slave firmware build：成功
- Master Quartus full compilation：`Full Compilation was successful`
- Slave Quartus full compilation：`Full Compilation was successful`
- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Slave MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- Master SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`
- Slave SOF SHA-256：`6a4357519c2c7996d28bbc2ade098ba8ab58b1f336c48953737932cf168bb225`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Master/Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master timing summary：setup `-0.206 ns`、hold `-3.504 ns`、timing closed `NO`
- Slave timing summary：setup `-0.401 ns`、hold `-3.548 ns`、timing closed `NO`
- 原始 compile artifacts：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/`

## 燒錄結果

### Master：`DE5 [1-11.1]`

- 燒錄時間：2026-08-17 16:38:36 至 16:38:54（Asia/Taipei）
- SOF checksum：`0x30A46449`
- JTAG ID：`0x02E660DD`
- configuration 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：Quartus Prime 17.0，`0 errors, 0 warnings`
- 原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/program_master.log`

### Slave：`DE5 [1-11.2]`

- 燒錄時間：2026-08-17 16:39:27 至 16:39:46（Asia/Taipei）
- SOF checksum：`0x30A3C175`
- JTAG ID：`0x02E660DD`
- configuration 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：Quartus Prime 17.0，`0 errors, 0 warnings`
- 原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/program_slave.log`

## JTAG/runtime 原始結果

待燒錄後以同一個 `quartus_stp` read-only session 取樣。原始輸出保存於 pain：

`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/runtime_readings.log`

需至少記錄：status、clock/reset probe、CPU marker/fault、WDIAGS_MODE/PTP、PTP RX/TX、Slave parent、SSTAT/PSTAT、UCNT、PPS、`time_valid/pps_valid`。

### 2026-08-17 clean-9f 60 秒結果

- `quartus_stp` return code：`0`
- 原始結果：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/runtime_readings.log`
- 同一個 JTAG session 對每張板取 60 列；完整 mailbox 讀取使單列時間大於 1 秒，以下用 session 的 sample 001、010、060 作代表。

#### Master：`DE5 [1-11.1]`

| 代表時間 | marker/fault | status | WDIAGS_MODE | WDIAGS_PTP | PTP RX/TX | 判讀 |
|---|---|---|---:|---:|---|---|
| sample 001 | `B004` / 0 | `0xFF` | 2 | 6 | counter 持續增加 | Master baseline 通過 |
| sample 010 | `B004` / 0 | `0xFF` | 2 | 6 | counter 持續增加 | 與 sample 001 一致 |
| sample 060 | `B004` / 0 | `0xFF` | 2 | 6 | RX=`0x143`、TX=`0x2CF` | 與 sample 001 一致 |

Master status 低 8 位的 `0xFF` 表示 `link_up=1、link_ok=1、time_valid=1、pps_valid=1`。`WDIAGS_PTP_META` 在 session 尾端為 `0x02020406`，其中 mode=2、PTP=6。

#### Slave：`DE5 [1-11.2]`

| 代表時間 | status | WDIAGS_MODE/PTP | parent/foreign | SoftPLL/servo | 判讀 |
|---|---|---|---|---|---|
| sample 001 | `0xCF` | 3 / 9 | `foreign=1、best=0、is_wr=1、calibrated=1` | `PSTAT.locked=0`、`UCNT` 有活動 | 已看到 Master，但未 lock |
| sample 010 | `0xCF` | 3 / 9 | parent flags 持續有效 | `spll_locked=0` | 未完成 time-valid |
| sample 060 | `0xCF` | 3 / 9 | `FOREIGN_META=0x03000001`、`PARSE_META=0x05019B50` | `UCNT=0x4A`、`WR_LOCK result=1` 但 `spll_locked=0` | servo 有活動但仍未 lock |

Slave 的低 8 位為 `0xCF`（其中少數取樣短暫為 `0xEF`），代表 link/PHY 正常，但 `time_valid` 沒有穩定成立；完整原始欄位顯示 `SSTAT=1、PSTAT=1、WDIAGS_PTP=9、WR_LOCK seq_state=4、spll_locked=0`。

## Observation

1. clean-9f 分支成功重現歷史 Master diagnostic baseline：`B004`、`status=0xFF`、`WDIAGS_MODE=2`、`WDIAGS_PTP=6`，且 PTP RX/TX counter 持續增加。
2. 這項結果證明先前 c4 版本的 `MODE=3/PTP=4` 是後續 firmware/role 實驗疊加造成的差異；不是 QSFP link 本身無法建立。
3. Slave 能收到 Master 的 WR/parent signaling：`foreign_count=1、foreign_best=0、parent is WR=1、parent calibrated=1`，且 `UCNT`、Raw SoftPLL tag/source counters 有活動。
4. Slave 仍沒有 `spll_locked=1`、穩定 `time_valid=1` 或 `pps_valid=1`；`WR_LOCK` 顯示 `result=1、seq_state=4、polls=883697、unlocked=883697`，支持「Slave servo/SoftPLL 尚未 lock」但不能單獨確定根因。

## Conclusion

本實驗部分成功：clean `9f848ec` Master role 與 link/runtime baseline 已被實際重現並保存；但兩端 White Rabbit 時間同步尚未完成。證據支持目前的主要阻塞點已從 Master role/PHY link 收斂到 Slave parent/servo/SoftPLL-to-time-valid 路徑，尚不能宣稱根因是某一個 register、校正值或 SI5340 動作。

## Next Step

固定 clean-9f Master SOF/MIF，不再修改 Master role。下一個實驗只改 Slave，先做唯讀寄存器與 clock/reset/SoftPLL activity 的基準觀察；若確定 Slave 已進入 `TRACK_PHASE` 但 lock 仍為 0，再隔離 calibration/SI5340 或 parent handshake 的單一變因。
