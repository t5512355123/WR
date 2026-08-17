# 實驗紀錄：恢復 Master DCO controller 原始 handshake

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-MASTER-DCO-HANDSHAKE-RESTORE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- Git branch：`exp/master-9f-observability`
- Source/build commit：`a334630f6b041fb076c0495b5c308dbcc199d9de`

## 實驗名稱

`保留最新唯讀 DCO observability，只恢復成功 baseline 的 runtime handshake`

## 這次想驗證什麼

歷史 SOF A/B 顯示：同一個 Master MIF 與同一個 Master top-level，在舊 DCO controller 下可達到 `MODE=2、status=0xFF`；目前 DCO handshake 修改版則讀到 `MODE=3、status=0xEF`。本次只恢復 DCO controller 的三個 runtime state transition 條件，確認 Master role 是否恢復。

成功判準：

- `marker=B004`
- `WDIAGS_MODE=2`
- `WDIAGS_PTP=6`
- `status=0xFF`
- `time_valid=1、pps_valid=1`
- PTP RX/TX counter 有活動

這些條件通過仍只代表 Master diagnostic baseline 恢復，不代表兩台 DE5a 已完成同步。

## 相較 baseline 唯一修改

只修改 `quartus/jtag_runtime_diag/si5340a_controller_dco.v`：

- state `3'd1` 從等待 `bus_state` 改回等待 `runtime_start`。
- state `3'd3` 從等待 `bus_state` 改回等待 `runtime_start`。
- state `3'd5` 從等待 `bus_state` 改回等待 `runtime_start`。

保留 `oDCO_DEBUG`、`i2c_state` 與其他唯讀觀測，不修改 Master firmware、startup command、PHY、clock wiring、SoftPLL 演算法或 Slave top-level。

## Build provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Project/top-level：`DE5a_wr_master_jtag`
- QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Master SOF SHA-256：`1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db`
- Fitter：`Successful`
- Compile：`Full Compilation was successful`
- Timing closed：`NO`
- Worst setup/hold slack：`-0.206 ns / -3.504 ns`
- Unconstrained clocks/inputs/outputs：`3 / 402 / 84`
- Compile log：`/home/b10504072/04_WR/build/quartus_jtag_master_compile.log`
- Compile log SHA-256：`8abf28d33ed60bc512647dca38d79e949e85c06e9ea7131775ea98c657de9b08`

## 燒錄結果

Master 使用 cable `DE5 [1-11.1]`，時間 18:16:09--18:16:28：

```text
Using programming cable "DE5 [1-11.1]"
Using programming file .../DE5a_wr_master_jtag.sof with checksum 0x30A46449
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Successfully performed operation(s)
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- Programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-DCO-HANDSHAKE-RESTORE-20260817/program_master.log`
- Programmer log SHA-256：`9d4ef6fd4e0962db89b4a81d250c10747ebfb6e3f236925f2aa09c453084ae69`

## JTAG/runtime 原始結果

原始 logs：

- `/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-DCO-HANDSHAKE-RESTORE-20260817/clock_activity.log`
- `/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-DCO-HANDSHAKE-RESTORE-20260817/runtime_probe.log`
- `/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-DCO-HANDSHAKE-RESTORE-20260817/runtime_5s.log`

Master clock activity：

```text
CLOCK_ACTIVITY label=BEGIN raw=FEFF734769BF6C3F REF=27711 DMTD=27071 RX=29511 TOGGLE=1/1/1 PHY_READY=1 RX_LOCK_REF=1 RX_LOCK_DATA=1 SYS625_LOCKED=1 CORE_RESET_N=1 PHY_RST=0 SI_DONE=1 PPS_VALID=1 TIME_VALID=1 RX_READY=1 TX_READY=1 LINK_UP=1 LINK_OK=1
CLOCK_ACTIVITY label=END   raw=FEEDEC85E2DEE57D REF=58749 DMTD=58078 RX=60549 TOGGLE=1/0/1 PHY_READY=1 RX_LOCK_DATA=1 SYS625_LOCKED=1 CORE_RESET_N=1 PHY_RST=0 SI_DONE=1 PPS_VALID=1 TIME_VALID=1 RX_READY=1 TX_READY=1 LINK_UP=1 LINK_OK=1
```

單次 runtime probe：

```text
status_probe: 71100CC1295082FF
cpu_debug: PC=0x0000CF78 reset=0 fault=0 im_valid=1
cpu_marker: 0x0000B004 seen=1
WDIAGS_PTP:   00000004
WDIAGS_PTP_META:02010204
WDIAGS_MODE:   2
```

5 秒 session 的 Master 有效 frame 持續顯示：

```text
DECODE: status_low=FF time_valid=1 pps_valid=1 wr_mode=2 link_up=1
WDIAGS_PTP_RX:00000003 -> 00000006 -> 00000009
WDIAGS_PTP_TX:00000000 -> 00000005 -> 0000000F
WDIAGS_PTP_META:02010204 -> 02010206
SESSION_SAMPLE_RESULT board=DE5 [1-11.1] sample=005 accepted=1 retries=0
```

同一 session 的 Slave 仍為 `MODE=3、time_valid=0`；本次不是兩端同步實驗。

- Clock activity log SHA-256：`320c7c02a643c8181d9c8625965270838ac557712a2de04c08077b314d877fcd`
- Runtime probe log SHA-256：`e67a99d04f87a9fccd7db9ec3a21b3160bb6edca115cb7cff1949aa26bcba5f8`
- Runtime 5s log SHA-256：`111ae5da6928dc18af500c9a1707be2f49614f8a7d67ffaa5573079976377a6a`

## Observation

1. Quartus 17 compile 與 programmer 成功。
2. 只恢復 `si5340a_controller_dco.v` 的三個 state transition 條件後，Master 再次達到 `marker=B004、MODE=2、status=0xFF、time_valid=1、pps_valid=1`。
3. PTP RX/TX 在 5 秒 session 中持續增加；clock/reset/PHY/link probe 也維持有效。
4. Master MIF hash 沒變，Master startup command 沒變，Master top-level observability 仍保留；因此相較前一個失敗 image，最直接的 source-level 變因就是 DCO handshake 條件。
5. Slave 沒有在本次實驗重新燒錄，仍未同步；不能把 Master baseline 恢復誤寫成兩板同步成功。

## Conclusion

本實驗成功恢復 Master diagnostic baseline。結合前一個失敗 image 與歷史 SOF A/B，證據強烈支持：把 runtime DCO request state `1/3/5` 改成等待 `bus_state` 的 handshake 修改，會讓 Master role/runtime regression；恢復原本等待 `runtime_start` 後，Master 回到 `MODE=2/status=FF`。這是目前可由 A/B 支持的結論；尚不能單獨宣稱 Slave servo 根因已解決。

## Next Step

固定 Master source/image：`a334630` DCO controller、Master MIF `b85fc3...`、Master SOF `1a3362...`。下一個只燒錄目前相同 source 的 Slave image，讀取 `DCO_STATE`、SoftPLL helper/lock、parent 與 `time_valid/pps_valid`；不再修改 Master role。
