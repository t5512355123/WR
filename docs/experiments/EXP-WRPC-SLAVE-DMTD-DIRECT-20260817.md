# 實驗紀錄：Slave 恢復 direct DDMTD 取樣方向

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-DMTD-DIRECT-20260817`
- 日期：2026-08-17（Asia/Taipei）
- Git branch：`exp/master-9f-observability`
- Git commit：`de7156d1dcd437a67b72b383568465525b066683`
- GitHub：`origin/exp/master-9f-observability`

## 這次想驗證什麼

在不改變已知可工作的 Master role 與 Master bitstream 的前提下，確認 Slave 的 SoftPLL helper error 飽和與未鎖定，是否來自 reverse DDMTD 取樣方向。目標是讓 Slave 從 reverse 取樣恢復為 WR core 預設的 direct 取樣方向，並重新觀察 helper lock、SoftPLL lock、`time_valid` 與 `pps_valid`。

## 相較 baseline 唯一修改

只修改 `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd` 的 Slave `xwr_core` generic：

```vhdl
g_softpll_reverse_dmtds => false
```

Master 的 source、MIF、SOF、role 設定與已燒錄映像均未修改。沒有改 WR role 切換方法、PTP、servo 演算法、SI5340 控制或 PHY lane 設定。

## 建置與識別資料

- Quartus Prime：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`0a6cc58f3a331aceab74757e321afebe63a403d04281dfbf0fe84f5742d283fa`
- Slave SOF SHA-256：`f12bc0fb001c7977c2dc251f948cc6bf60957cb2dfbf040ca1593b66230d0ebd`
- Fitter：`Successful`
- Compile：`Full Compilation was successful`
- Timing closed：`NO`
- Worst setup slack：`-0.234 ns`
- Worst hold slack：`0.037 ns`

Master 固定沿用乾淨 9f 基線：

- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Master SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`

## 燒錄結果

- 目標：Slave，cable `DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A3C0EE`
- `Configuration succeeded -- 1 device(s) configured`
- `Quartus Prime Programmer was successful. 0 errors, 0 warnings`
- 燒錄時間：2026-08-17 16:59:48 至 17:00:07

原始證據位於 pain：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DMTD-DIRECT-20260817/
```

其中包含 `program_slave.log`、`build_info_jtag_slave.txt`、`quartus_jtag_slave_compile.log`、SOF/MIF 副本與燒錄前 hash。

## JTAG/runtime 原始結果

使用同一 JTAG session 執行 10 個取樣、每次間隔約 1 秒：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wb_timeseries_session.tcl 10 1000 3
```

原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DMTD-DIRECT-20260817/runtime_10s.log
```

log SHA-256：`a9b226f758b49f37e07a4353fb0809f0220768f1e34e4e5acd79f576c839a393`

代表性的 Slave 結果：

```text
WDIAGS_SSTAT=00000001 WDIAGS_PSTAT=00000001 WDIAGS_PTP=00000009
DECODE: status_low=CF time_valid=0 pps_valid=0 wr_mode=3 link_up=1 spll_locked=0
WR_SPLL_LOCK: result=1 spll_locked=0 unlocked=953067 calibration_fail=0
             enable=4 seq_state=9 align_state=0 mode=3
WR_SPLL_ACTIVITY: REF_COUNT=00000000 TAG_COUNT=00000000
                  HELPER_ERROR=00000000 HELPER_OUTPUT=00000000
WR_SPLL_EVENTS: TAG_VALID_COUNT=00000000 TRR_WRITE_COUNT=00000000
WR_SPLL_SOURCE_RAW: TAG_SOURCE_COUNT=0BA40033/0BA40033
PARENT: is_wr=1 mode_on=0 calibrated=1 parent_calibrated=1
```

在所有有效取樣中，Slave 的 link 與 PTP/parent metadata 仍在活動，但沒有形成有效 SoftPLL tag FIFO 事件。

Master 在同一觀測窗維持 `status_low=FF`、`time_valid=1`、`pps_valid=1`、`wr_mode=2`。

預計使用同一 JTAG session 讀取：

- `status_probe`、`WDIAGS_SSTAT`、`WDIAGS_PSTAT`
- `WDIAGS_PTP`、PTP RX/TX 與 parent metadata
- `WR_SPLL_HELPER_LOCKDET`、helper error/output、tag valid/TRR write
- `time_valid`、`pps_valid` 與 `UCNT`

## Observation

1. compile 與燒錄成功，沒有 configuration error。
2. direct DDMTD 版本的 Slave `TAG_SOURCE_COUNT` 有硬體 source activity，但 `TAG_VALID_COUNT` 與 `TRR_WRITE_COUNT` 為零。
3. Slave 仍停在 `seq_state=9`（`SEQ_CLEAR_DACS`），`PSTAT` lock bit、`time_valid` 與 `pps_valid` 沒有穩定成立。
4. parent metadata 仍顯示 `is_wr=1`、`calibrated=1`，所以本次不是 PTP parent 消失。

## Conclusion

證據支持：Slave direct-DDMTD 版本已成功編譯並成功燒錄，但這個單一變因沒有使 Slave SoftPLL lock，且有效 tag 事件比 reverse 版本更差；兩台 DE5a 仍未完成時間同步。

## Next Step

恢復 Slave reverse DDMTD 版本 `true`，保留 Master 不變。後續只針對 reverse 版本的 helper error 飽和與 `SEQ_WAIT_HELPER`/`SEQ_CLEAR_DACS` 進出條件做 source audit；不要再以 direct 版本作為基線。只有在 Slave 穩定呈現 `link_ok=1`、`WDIAGS_PSTAT` lock bit=1、`time_valid=1`、`pps_valid=1`，且同一觀測窗內 parent/servo 證據一致時，才可宣稱同步完成。
