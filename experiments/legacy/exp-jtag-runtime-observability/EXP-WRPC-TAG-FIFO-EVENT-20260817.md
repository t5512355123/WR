# 實驗紀錄：SoftPLL raw tag 與 FIFO write 事件觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-TAG-FIFO-EVENT-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗分支：`exp/jtag-runtime-observability`
- Git commit：`b8d4c3d0526f0c2ca282600ef06648dd9f0af595`
- pain checkout：detached HEAD，與上述 commit 一致

## 這次想驗證什麼

前一個唯讀實驗顯示 Slave 的 `link_up=1`、PTP 封包計數持續增加、`WR_LOCK result=1`，但 `spll_locked=0` 且 `time_valid=0`。本次加入兩個更靠近硬體事件源的唯讀計數器，確認：

1. SoftPLL 是否真的收到 `tag_valid` 事件。
2. tag event 是否真的形成 TRR FIFO write request。

這個實驗只觀測事件，不改變 PHY、PTP、servo、SI5340 或 validity gating 的控制行為。

## 相較 baseline 唯一修改

相較上一個可燒錄版本，本次唯一功能修改是：

- 在 `spll_wb_slave` 增加 `TAG_VALID_COUNT`（WB offset `0x84`）與 `TRR_WRITE_COUNT`（WB offset `0x88`）唯讀欄位。
- 在 SoftPLL 內計數 `tag_valid`，以及 `tag_valid && !trr_wr_full` 的實際 FIFO write 條件。
- 將兩個計數器透過 firmware mailbox 與 JTAG timeseries 輸出。

本次沒有修改資料路徑控制，也沒有新增會阻塞 SoftPLL 的控制訊號。

## 建置與識別資料

- Quartus：17.0.0 Build 595（2017-04-25，Standard Edition）
- Master QSF SHA-256：`e9a5484048fdec5399ba9034f990565e1e52f6ea7e503fb46174d596e5e6b34b`
- Slave QSF SHA-256：`199a695e29c9e4fbf5a18bb88cfaa4079ce6858ae83e21628c9c6d2731c03f58`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`968e3863f2622fe67d468327bec1d8832e955344f74973cde7e2bc19fcf7347d`
- Slave MIF SHA-256：`88f5dce3198e17ad75933e353c9852fdd43069ebc92b7e94734c0db9c270cfef`
- Master SOF SHA-256：`e119bf34a63a830d251bac9bbc1f8e597483245090e67848d0229b1a4530a84b`
- Slave SOF SHA-256：`dd33733208af12a727f507c1626caa93cc2164565a3496d9bd78a93e9feed061`

兩端 Full Compilation 均成功產生 SOF，但時序尚未收斂：

- Master `TIMING_CLOSED=NO`，worst setup slack `-2.988 ns`
- Slave `TIMING_CLOSED=NO`，worst setup slack `-2.751 ns`

## 燒錄結果

### Slave

- Programmer cable：`DE5 [1-11.2]`
- SOF checksum：`0x30A4E4B6`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`0 errors, 0 warnings`
- 原始紀錄：`build/artifacts/EXP-WRPC-TAG-FIFO-EVENT-20260817/program_slave.log`

### Master

- Programmer cable：`DE5 [1-11.1]`
- SOF checksum：`0x30A46080`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`0 errors, 0 warnings`
- 原始紀錄：`build/artifacts/EXP-WRPC-TAG-FIFO-EVENT-20260817/program_master.log`

## JTAG / runtime 原始結果

兩片板燒錄後立即建立本紀錄，接著完成 60 秒唯讀 timeseries；另以不重新燒錄的方式加入直接 SoftPLL WB 讀取，確認 firmware shadow 的結果。

- JTAG 腳本：`scripts/jtag/read_wb_timeseries_session.tcl`
- 預定取樣：60 秒、每 1000 ms 一次、每列 3 次重讀
- 燒錄時使用的唯讀硬體映像 commit：`b8d4c3d0526f0c2ca282600ef06648dd9f0af595`
- 直接 raw 讀取腳本 commit：`52af9f5`（只改 JTAG 讀取腳本，沒有重新 compile 或燒錄）
- 60 秒原始紀錄：`build/artifacts/EXP-WRPC-TAG-FIFO-EVENT-20260817/runtime_60samples.log`
- 直接 raw 短讀取紀錄：`build/artifacts/EXP-WRPC-TAG-FIFO-EVENT-20260817/runtime_raw_short.log`
- 60 秒 log SHA-256：`8C1484D31734E97FF7B892425DB607A52B833F0E7115EAB99DDD51D8B97B30A4`
- raw 短讀取 log SHA-256：`09E9724AA15CCC2AA65775E4584EB53B3BE7440126C03F494EAF32804F81AC1F`
- Master Programmer log SHA-256：`D179B504664DAD4B27269ECBE4CBC0648019F8D13FB5F3BEAC4FC03E0B1B0134`
- Slave Programmer log SHA-256：`5541B0E191030149B29959940F932ADA6CDB5CF06AD36F0836E0B6D4348D364C`
- 觀測欄位：`WR_SPLL_EVENTS`（firmware shadow）與 `WR_SPLL_EVENTS_RAW`（直接讀 SoftPLL WB `0x00100284/0x00100288`）

### 60 秒有效 frame 統計

- Master：`54/60` 列 `accepted=1`，`6` 列在重試上限後失敗。
- Slave：`58/60` 列 `accepted=1`，`2` 列在重試上限後失敗。
- Quartus SignalTap/Tcl：`SESSION_TIME_SERIES_DONE`，`Evaluation of Tcl script ... successful`，`0 errors, 0 warnings`。

### 事件與 WR 狀態

- 60 秒有效列中的 `WR_SPLL_EVENTS` 幾乎全為 `TAG_VALID_COUNT=0/0`、`TRR_WRITE_COUNT=0/0`；少數跨讀取邊界的 shadow 列出現 `0x010002E9`，它與 IRQ mask 數值相同且不是單調 counter，因此不納入事件證據。
- 直接 raw 短讀取中，Master 與 Slave 各完成 `3/3` 有效列；正常列的 raw `TAG_VALID_COUNT=0/0`、`TRR_WRITE_COUNT=0/0`。
- raw 短讀取有一筆 Master 的 `TRR_WRITE_COUNT=0x00020000/0x00000000` 非單調異常值；因 raw 欄位未納入 frame-valid 條件，這筆只記為讀取異常，不解讀為 FIFO 曾寫入 `0x20000` 次。
- Master 仍為 `link_up=1`、`time_valid=1`、`pps_valid=1`、`wr_mode=2`。
- Slave 仍為 `link_up=1`、`time_valid=0`；`pps_valid` 在取樣期間可能為 `0` 或 `1`，`spll_locked=0`、`WR_LOCK result=1`、`calibration_fail=0`。
- Slave 的 PTP RX/TX、foreign master 與 parent WR flags 持續有效；因此本次結果不支持「CPU 沒跑」、「PHY 未連線」或「PTP 完全沒有封包」這些較前面的假設。

## Observation

本次新增的硬體計數器與直接 WB 讀值，在正常有效 frame 中都沒有顯示 `tag_valid` 或 TRR FIFO write request 發生；同時既有 firmware `softpll.tag_count=0`、`ref_count=0`、`IRQ_COUNT=0`。`RCER=1`、`OCER=1`，但 `TRR_CSR=0x00020000` 持續維持同一狀態。這表示問題已可更集中到 DMTD tag 產生、tag arbitration 或 tag 進入 TRR 之前的路徑。

## Conclusion

證據支持的結論是：Slave 的 WR parent/servo/SoftPLL-to-time-valid 路徑仍是主要問題範圍，而且目前更靠近「沒有產生或沒有通過 tag event」的位置；但尚不能只靠本次計數器判定是 DMTD 輸入時鐘、`tags_p`、arbitration enable、或 TRR/FIFO 的哪一個單點根因。這不是 Root complex、CPU boot 或 PTP RX 不通的直接證據。此次 compile 與燒錄成功也不等於 WR time synchronization 已成功；實際上 Slave 的 `time_valid=0`、`spll_locked=0`。

## Next Step

下一個實驗只增加分段唯讀計數，不改控制行為：

- `any(tags_p)` counter：判斷各 DMTD channel 是否曾產生 tag strobe。
- `any(tags_grant_p)` counter：判斷 tag 是否通過 request/grant arbitration。
- 延續 `tag_valid` 與 TRR write counter，另加 `tag_valid && trr_wr_full` counter：區分 arbitration 問題與 FIFO full/backpressure。
- 若 `tags_p` 已增加而後段仍為零，才繼續查 arbitration；若 `tags_p` 本身為零，優先查 DMTD input clock、reset、deglitch 與 bitslide/clock wiring。
