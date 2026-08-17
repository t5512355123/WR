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

Master 使用 cable `DE5 [1-11.1]`，時間 18:00:53--18:01:12：

```text
Using programming cable "DE5 [1-11.1]"
Using programming file .../DE5a_wr_master_jtag.sof with checksum 0x30A21D29
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Successfully performed operation(s)
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- Programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-OBS-REBASE-20260817/program_master.log`
- Programmer log SHA-256：`246789cda1ae416979738445d44ddefa1646bfd259ad50c3602b0d7aed304577`

## JTAG/runtime 原始結果

### Clock activity probe

原始輸出：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-OBS-REBASE-20260817/clock_activity.log`

Master `DE5 [1-11.1]`：

```text
CLOCK_ACTIVITY label=BEGIN raw=F6E9D0BE7D6C829F REF=33439 DMTD=32108 RX=53438 TOGGLE=1/0/0 PHY_READY=1 RX_LOCK_REF=0 RX_LOCK_DATA=1 SYS625_LOCKED=1 CORE_RESET_N=1 PHY_RST=0 SI_DONE=1 PPS_VALID=1 TIME_VALID=0 RX_READY=1 TX_READY=1 LINK_UP=1 LINK_OK=1
CLOCK_ACTIVITY label=END   raw=F6EA49E2F671FBC4 REF=64452 DMTD=63089 RX=18914 TOGGLE=0/1/0 PHY_READY=1 RX_LOCK_REF=0 RX_LOCK_DATA=1 SYS625_LOCKED=1 CORE_RESET_N=1 PHY_RST=0 SI_DONE=1 PPS_VALID=1 TIME_VALID=0 RX_READY=1 TX_READY=1 LINK_UP=1 LINK_OK=1
```

這證明燒錄後 clock、PHY、reset、link 與 PPS activity 都存在，但 `TIME_VALID` 當下為 0。

### 10 秒 read-only runtime session

原始輸出：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-OBS-REBASE-20260817/runtime_10s.log`

在 `DE5 [1-11.1]` 的有效 frame 中，代表性結果為：

```text
WDIAGS_PTP_RX:0000002D WDIAGS_PTP_TX:00000021 WDIAGS_PTP_META:03010204
DECODE: status_low=EF time_valid=0 pps_valid=1 wr_mode=3 link_up=1 spll_locked=0
WR_LOCK: result=0 spll_locked=0 polls=0 unlocked=0 calibration_fail=0 enable=0
```

後續有效 frame 的 `WDIAGS_PTP_RX/TX` 有增加，`WDIAGS_PTP_META` 也曾出現 `03020404` 與 `03020406`，但 `wr_mode` 仍解碼為 3，沒有達到 Master 判準 `status=FF / MODE=2 / PTP=6`。另一 cable `DE5 [1-11.2]` 同一 session 也讀到 `status=EF、wr_mode=3`，符合目前 Slave 未同步的狀態。

這次 session 的部分 frame 為 `FRAME_VALID=0`，只把 `accepted=1` 的 frame 用於判讀；JTAG mailbox 取樣不完整的列不作為結論。

- Clock activity log SHA-256：`11f88852f14d9860ff0e559f6171559945ac664c8d706b26ff73c904aaf2eec3`
- Runtime log SHA-256：`d8041e4c944ff92bc89d793c07f299d306cb440f5fb4794c7035c460573a2969`

## Observation

1. Quartus compile 與 programmer 都成功，但這次燒錄後 Master 判準沒有通過：`status=0xEF、MODE=3、PTP=4/6、time_valid=0`，不是預期的 `0xFF/2/6`。
2. Master 的 clock activity 顯示 `PHY_READY=1、RX_LOCK_DATA=1、SYS625_LOCKED=1、CORE_RESET_N=1、SI_DONE=1、RX_READY=1、TX_READY=1、LINK_UP=1、LINK_OK=1`；因此目前證據支持 clock/PHY/link 已活著，但不支持 WR Master role 已正確生效。
3. build tree 的 `auto.conf`、`autoconf.h` 與 source config 都仍是 `vlan off;ptp stop;mode master;ptp start`，MIF hash 也與歷史 9f baseline 相同；因此不能直接把問題寫成「source startup command 被改掉」。
4. 目前仍未排除：歷史 SOF 與最新 observability SOF 的 A/B 差異、實際 MIF 嵌入/燒入內容、runtime 啟動後 role 被其他流程覆寫，以及 JTAG/board mapping 或 mailbox decode 問題。

## Conclusion

本次實驗的 compile/program 部分成功，但 Master diagnostic baseline 失敗；不能宣稱 `9f848ec` Master role 已在這個最新 observability SOF 上重現，也不能據此宣稱兩台 DE5a 已同步。現有證據只支持「硬體 link/clock activity 正常，而 runtime role/status 不符合判準」，根因尚未確定。

## Next Step

先不修改任何 Master role 或 firmware。使用歷史上已實際成功的 Master SOF `383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93` 做不改 source 的 A/B burn；若歷史 SOF 恢復 `status=FF、MODE=2、PTP=6`，再把差異收斂到最新 top-level observability/編譯映像；若歷史 SOF 也讀到 `MODE=3`，則優先查 runtime/board/JTAG mapping，而不是再改 role。
