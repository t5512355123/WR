# 實驗紀錄：歷史成功 Master SOF A/B

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-MASTER-9F-HISTORICAL-SOF-AB-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗分支：`exp/master-9f-observability`
- 映像來源 commit：`302ffc1`（歷史 clean-9f Master diagnostic build）
- 本次紀錄提交不代表硬體映像來源改變；燒錄檔使用已保存 artifact。

## 實驗名稱

`歷史成功 9f848ec Master SOF 與目前 observability SOF 的不改 source A/B`

## 這次想驗證什麼

上一個實驗使用目前分支重新編譯的 Master SOF，雖然 compile/program 成功，但 runtime 讀到 `MODE=3、status=0xEF`。本次只燒錄歷史上實際達到 `marker=B004、MODE=2、PTP=6、status=0xFF` 的保存 SOF，驗證問題是否由最新 Master top-level observability 編譯映像造成。

## 相較 baseline 唯一修改

只替換 FPGA 燒錄檔；不修改 source、firmware、startup command、Slave、PHY、clock、JTAG script 或 role API。

## Build / image provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- 歷史 build artifact：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/master.sof`
- 歷史 source/build commit：`302ffc1`
- Master startup command：`vlan off;ptp stop;mode master;ptp start`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Master SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`

## 燒錄結果

Master 使用 cable `DE5 [1-11.1]`，時間 18:08:17--18:08:36：

```text
Using programming cable "DE5 [1-11.1]"
Using programming file .../EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/master.sof with checksum 0x30A46449
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Successfully performed operation(s)
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- Programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-HISTORICAL-SOF-AB-20260817/program_master.log`
- Programmer log SHA-256：`f7e5a15ea3af748ab20c7779e6af251546a27c99ad7000f0719d76625f35df56`

## JTAG/runtime 原始結果

待燒錄後使用既有 read-only `read_wb_runtime.tcl`、`read_clock_activity.tcl` 與 `read_wb_timeseries_session.tcl`，不寫入 WR 設定。

原始 logs：

- `/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-HISTORICAL-SOF-AB-20260817/clock_activity.log`
- `/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-HISTORICAL-SOF-AB-20260817/runtime_probe.log`
- `/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-HISTORICAL-SOF-AB-20260817/runtime_5s.log`

Master `DE5 [1-11.1]` 的 clock activity：

```text
CLOCK_ACTIVITY label=BEGIN raw=FEEDDCBBD6AED923 REF=55587 DMTD=54958 RX=56507 TOGGLE=1/0/1 PHY_READY=1 RX_LOCK_DATA=1 SYS625_LOCKED=1 CORE_RESET_N=1 SI_DONE=1 PPS_VALID=1 TIME_VALID=1 RX_READY=1 TX_READY=1 LINK_UP=1 LINK_OK=1
CLOCK_ACTIVITY label=END raw=FEFF55F74FCB525F REF=21087 DMTD=20427 RX=22007 TOGGLE=1/1/1 PHY_READY=1 RX_LOCK_DATA=1 SYS625_LOCKED=1 CORE_RESET_N=1 SI_DONE=1 PPS_VALID=1 TIME_VALID=1 RX_READY=1 TX_READY=1 LINK_UP=1 LINK_OK=1
```

單次 runtime probe：

```text
status_probe: 80100CC3205082FF
cpu_marker: 0x0000B004 seen=1
WDIAGS_PTP:   00000004
WDIAGS_PTP_META:02010204
WDIAGS_MODE:   2
```

5 秒 session 中 Master 有效 frame 連續顯示：

```text
DECODE: status_low=FF time_valid=1 pps_valid=1 wr_mode=2 link_up=1
WDIAGS_PTP_RX:00000006 -> 00000009 -> 0000000B
WDIAGS_PTP_TX:00000000 -> 00000005 -> 0000000A
WDIAGS_PTP_META:02010204 -> 02010206
SESSION_SAMPLE_RESULT board=DE5 [1-11.1] sample=005 accepted=1 retries=1
```

同一 session 的 Slave `DE5 [1-11.2]` 仍為 `MODE=3、time_valid=0`；本次只是在做 Master A/B，沒有宣稱 Slave 已同步。

- Clock activity log SHA-256：`5acb9287911cf1f2b98b0c409f61e071bb5e862e56c7d4814a1122b2dee3ce10`
- Runtime probe log SHA-256：`8775ae86207e95cdc7535f9ff93447205ec13bfc93859ccc0c232870c388fb07`
- Runtime 5s log SHA-256：`27a3f05a0c7e17b56cb027a4fab8813e1d301a90db39ca1dc6eaa5ea008d392b`

## Observation

1. 歷史成功 SOF 在同一台 pain、同一個 cable、同一套 read-only JTAG script 下恢復 Master 判準：`marker=B004、MODE=2、status=0xFF、time_valid=1、pps_valid=1`。
2. Master PTP RX/TX counter 在 5 秒 session 中增加，支持 PTP runtime 有活動。
3. 目前新版 observability SOF 與歷史 SOF 的唯一預定 source 差異，是 Master `clock_activity_probe[54:63]` 從常數 0 改成直接觀測 clock/reset/link signals；A/B 結果顯示這個新版 image 沒有保留 Master role 行為。
4. 這仍不能單獨證明「某一條 probe wire 就是根因」；也可能是新增多 clock-domain probe 造成的 timing/實作差異。兩個 SOF 的功能差異需要再做單一變因重編譯確認。
5. Slave 在本次 A/B 中沒有重新燒錄，仍是 `MODE=3、time_valid=0`；因此本次只證明 Master baseline 可用，不代表兩台同步完成。

## Conclusion

本次 A/B 成功重現歷史 Master baseline。證據支持：startup command/MIF 本身不是唯一問題，因為同一 MIF hash 的歷史 SOF 可正常進入 `MODE=2`；而目前新版 Master observability SOF 確實未能重現。最保守的結論是：新增的 Master 高位 clock/reset/link observability 與功能行為之間存在可觀測的 image-level regression，優先懷疑其跨 clock-domain 直連或 timing/fit 影響，但尚未把根因縮到單一訊號。

## Next Step

保持 `9f848ec` Master role 與 startup command 不變，只撤回 Master `clock_activity_probe[54:63]` 的新增直接訊號，保留原有低位 activity probe；重新用 Quartus 17 compile，再以新 SOF 做單一變因 A/B。若恢復 `MODE=2/status=FF`，就固定這個 Master image，不再為了 observability 破壞功能，後續回到 Slave。
