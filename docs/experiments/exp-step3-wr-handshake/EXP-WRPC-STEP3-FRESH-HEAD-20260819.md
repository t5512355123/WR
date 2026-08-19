# 實驗紀錄：Step 3 fresh HEAD WR Parent／Signaling Handshake

## Experiment ID／日期

- Experiment ID：`EXP-WRPC-STEP3-FRESH-HEAD-20260819`
- 日期：2026-08-19（Asia/Taipei）
- 實驗分支：`exp/step3-wr-handshake`
- Git commit：`fb8c926cfe37b82e86300117181a6ac01e1889e2`
- 實驗目的：以目前 branch 的 fresh firmware、fresh Quartus SOF，驗證 Step 3 的 WR parent 與 signaling handshake。

## 這次想驗證什麼

在 Step 2「Endpoint／MiniNIC／PTP packet path」已成立的基礎上，驗證 Slave 是否能完成：

```text
PTP Slave（PTP=9）
  → 建立 Foreign Master
  → 傳送 SLAVE_PRESENT（0x1000）
  → 接收 Master LOCK（0x1001）
  → 進入 WRS_S_LOCK（fail_state=2）
  → 呼叫 WR locking enable
```

本輪不要求 SoftPLL lock 或 `time_valid=1`；那是後續 Step 4／Step 5 的驗收項目。

## 相較 baseline 唯一修改

本輪沒有新增功能性修改。使用 `exp/step3-wr-handshake` 的 exact HEAD 直接重新建置與燒錄，目的是排除歷史 SOF 與目前 source 不一致的可能性。

目前 HEAD 相對已知 9f baseline 的可見變更，主要是 JTAG／WDIAGS 可觀測性、build provenance 與 Step 2 啟動設定；本輪沒有改動 PHY、PTP 演算法、WR signaling acceptance、SoftPLL 演算法或 SI5340 DCO 控制。

## 建置與 provenance

- Git branch：`exp/step3-wr-handshake`
- Git HEAD：`fb8c926cfe37b82e86300117181a6ac01e1889e2`
- Quartus：`17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Clean build clone：`/home/b10504072/04_WR_step3_head`
- Artifact 目錄：`/home/b10504072/04_WR_step3_head/build/artifacts/EXP-WRPC-STEP3-HEAD-FRESH-20260819`
- Master QSF SHA-256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA-256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`5360a85577bf8235058ac6bfe63db1dd6e5c135db99637fa69e684868868eb34`
- Slave MIF SHA-256：`bc46c529d66464acbb914b4cc325ff7489037982e7b6d32d9ed02b750feef3e5`
- Master SOF SHA-256：`008bcf4cc8d7a9816421ab35222c284a9a657114ed57472ef39b1cd472955120`
- Slave SOF SHA-256：`15f2e983e86fc76900fc379ef619ea326e22b824a92d260ea40f2a9701f14248`
- Master timing：`TIMING_CLOSED=NO`，worst setup slack `-0.177 ns`
- Slave timing：`TIMING_CLOSED=NO`，worst setup slack `-0.210 ns`
- 完整 compile 結果：Master／Slave 均為 `Full Compilation was successful`，Fitter 均為 `Successful`。

## 燒錄結果

### Master

- Cable：`DE5 [1-11.1]`
- SOF checksum：`0x30A3010A`
- JTAG ID：`0x02E660DD`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：`0 errors, 0 warnings`
- 原始輸出：`build/artifacts/EXP-WRPC-STEP3-HEAD-FRESH-20260819/program_master.log`
- 原始輸出 SHA-256：`2cbfc4f9d6aa0eb061e93ffba83ff4d606142fede8c7163bfac098ca35051c62`

### Slave

- Cable：`DE5 [1-11.2]`
- SOF checksum：`0x30A3C3D7`
- JTAG ID：`0x02E660DD`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：`0 errors, 0 warnings`
- 原始輸出：`build/artifacts/EXP-WRPC-STEP3-HEAD-FRESH-20260819/program_slave.log`
- 原始輸出 SHA-256：`7931b00982199c7e0109f620d129cdc26b489dffc167f59db1d7feb619ed737b`

## JTAG／runtime 原始結果

- 短版 snapshot：`build/artifacts/EXP-WRPC-STEP3-HEAD-FRESH-20260819/runtime_snapshot.log`
- 30 秒 time-series：`build/artifacts/EXP-WRPC-STEP3-HEAD-FRESH-20260819/runtime_timeseries_30s.log`
- JTAG 腳本：`scripts/jtag/read_wb_runtime.tcl`、`scripts/jtag/read_wb_timeseries_session.tcl`
- snapshot SHA-256：`a3c1faa464bddd30622a365ef823ee9c20e7353c220869cb1f78a690995818f1`
- 30 秒 time-series SHA-256：`60c14ecd05b9874236549f323c0dc8a245bcb313ef2d1aa6b8c62c82797b2d9c`
- STP 結果：`SESSION_TIME_SERIES_DONE`，Quartus SignalTap `0 errors, 0 warnings`
- 取樣設定：30 samples、1000 ms 間隔、每個 frame 最多 3 次 retry
- Master：20/30 accepted；未接受的 sample 是 frame consistency retry，accepted samples 的 runtime 欄位一致
- Slave：30/30 accepted；retry 後所有 sample 均可取得有效 frame

## Acceptance criteria

| 項目 | 要求 | 實測 |
|---|---|---|
| Slave PTP role | `PTP=9` | PASS；30/30 accepted samples |
| Foreign Master | `FOREIGN_META=03000001`，count=1、best=0 | PASS；30/30 accepted samples |
| Slave signaling TX | `tx_msg=0x1000`（SLAVE_PRESENT） | PASS；30/30 accepted samples |
| Slave signaling RX | `rx_msg=0x1001`（LOCK） | PASS；30/30 accepted samples |
| WR state | `fail_state=2`（`WRS_S_LOCK`） | PASS；30/30 accepted samples |
| WR lock enable | `enable=4`，`polls=883836` | PASS；30/30 accepted samples |

### Fresh HEAD 代表性 raw decode

Master accepted sample：

```text
status_low=FF time_valid=1 pps_valid=1 wr_mode=2 link_up=1
WDIAGS_PTP=6 PTP_RX/PTP_TX 持續增加
WR_SIGNAL rx_msg=0x1000 tx_msg=0x1001 fail_state=3
```

Slave accepted sample：

```text
status_low=CF 或 EF time_valid=0 pps_valid=0 或 1 wr_mode=3 link_up=1
PARENT foreign_count=1 foreign_best=0 wr_config=3 is_wr=1 calibrated=1
WDIAGS_PTP=9 WDIAGS_FOREIGN_META=03000001
WR_SIGNAL rx_msg=0x1001 rx_count=1 tx_msg=0x1000 tx_count=1 fail_state=2
WR_LOCK result=1 polls=883836 unlocked=883836 enable=4
```

這些 raw 欄位與驗收條件相符；`spll_locked=0`、`time_valid=0` 是後續 SoftPLL／時間同步階段的結果，不是本輪 Step 3 gate。

## Observation／Conclusion

本輪已由 exact HEAD 完成 clean firmware build、Quartus clean compile、fresh SOF 燒錄與 30 秒 JTAG runtime verification。Master／Slave role、Endpoint link、PTP packet activity、Slave Foreign Master 與 WR signaling handshake 均有 fresh HEAD 證據；Slave 進入 `WRS_S_LOCK`，因此：

```text
STEP3_WR_PARENT_SIGNALING = PASS
```

這個結論只涵蓋 Parent／Signaling handshake，不代表 SoftPLL 已鎖定，也不代表 Slave `time_valid=1`。目前證據支持下一階段可從 Step 4 開始研究 SoftPLL；本輪不修改 SoftPLL 或 SI5340 行為。

## Next Step

1. 保留本輪 fresh HEAD、SOF、programmer 與 JTAG raw logs。
2. 將 Step 3 PASS 結果整理到 branch 狀態文件，但不要修改 Step 2 baseline。
3. 先向 White Rabbit 討論分支確認是否允許 merge；未取得確認前不 merge。
4. 下一階段另開或沿用明確的 Step 4 工作範圍，研究 SoftPLL lock／`time_valid`，並維持單一功能變因。
