# 實驗紀錄：以 9f848ec 重建 Master diagnostic baseline

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-MASTER-9F-OBS-REBASE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- Git branch：`exp/master-9f-observability`
- 硬體 build source commit：`2806c4dddec11508cba787ce60f9514e730472c9`

## 實驗名稱

`9f848ec Master role + 最新唯讀 observability 重建基線`

## 這次想驗證什麼

使用歷史上曾經成功的 `9f848ec` Master firmware role，不新增任何 role 切換方法；只確認目前最新的 clock/reset/link observability 沒有破壞已知 Master 行為。成功判準為：

- `marker=B004`
- `WDIAGS_MODE=2`
- `WDIAGS_PTP=6`
- `status=0xFF`
- PTP RX/TX counter 持續增加

這些條件全部成立，只能證明 Master diagnostic baseline 恢復；不等於兩台 DE5a 已完成 White Rabbit 時間同步。

## 相較 baseline 唯一修改

相較 `9f848ec`，Master firmware startup command 不變：

```text
vlan off;ptp stop;mode master;ptp start
```

目前分支只在 Master top-level 增加 clock/reset/link 的唯讀 probe；probe 不驅動 WR timing、PHY、PTP、SoftPLL 或 SI5340。Slave 不在本次燒錄變因內。

## Build provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Project：`DE5a_wr_master_jtag`
- Top-level：`DE5a_wr_master_jtag`
- QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Master SOF SHA-256：`38c128a81fca30f5412027b424e0753adcf08d8d3c72620da9cc1b599f29fc5a`
- Fitter：`Successful`
- Compile：`Full Compilation was successful`
- Timing closed：`NO`
- Worst setup slack：`-0.435 ns`
- Worst hold slack：`-3.472 ns`
- Unconstrained clocks/inputs/outputs：`3 / 398 / 82`
- Compile log：`/home/b10504072/04_WR/build/quartus_jtag_master_compile.log`
- Compile log SHA-256：`eedb9f797607a53521da1335213ee4613624c0219df5d7fea57613b8172612cd`

## 燒錄結果

待燒錄後立即補入 programmer 原始輸出、時間、cable、JTAG ID、SOF checksum、結果與 log hash。

## JTAG/runtime 原始結果

待燒錄後以同一 read-only JTAG session 讀取 status、marker/fault、WDIAGS_MODE/PTP、PTP RX/TX 與 clock activity probe。

## Observation

待補入實測結果。

## Conclusion

待補入；只能根據實際燒錄與 JTAG 證據判斷，不能以 compile 成功代替 runtime 成功。

## Next Step

若 Master 判準全部通過，保存此 Master SOF/MIF/checksum 並固定 Master；後續只針對 Slave 做單一變因實驗。
