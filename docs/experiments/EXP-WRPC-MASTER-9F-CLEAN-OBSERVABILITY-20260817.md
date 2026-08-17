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

- SOF checksum：待燒錄後填入
- JTAG ID：待燒錄後填入
- configuration 結果：待燒錄後填入

### Slave：`DE5 [1-11.2]`

- SOF checksum：待補
- JTAG ID：待補
- configuration 結果：待補

## JTAG/runtime 原始結果

待燒錄後以同一個 `quartus_stp` read-only session 取樣。原始輸出保存於 pain：

`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/runtime_readings.log`

需至少記錄：status、clock/reset probe、CPU marker/fault、WDIAGS_MODE/PTP、PTP RX/TX、Slave parent、SSTAT/PSTAT、UCNT、PPS、`time_valid/pps_valid`。

## Observation

待編譯、燒錄與唯讀 session 後填入。只把原始證據支持的內容寫入結論。

## Conclusion

在取得 clean `9f848ec` branch 的 compile、programming 與 runtime 證據前，不宣稱 Master role 或兩端同步成功。

## Next Step

若 Master 五項 baseline 全部成立，保存該 Master SOF/MIF 並停止修改 Master role，接著只追 Slave parent/servo/SoftPLL 到 `time_valid/pps_valid`。若仍為 mode 3，回查 exact 9f 的 flash/startup 狀態與實際 artifact，不再加入新的 role switching 方法。
