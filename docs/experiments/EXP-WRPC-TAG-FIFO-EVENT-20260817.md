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

本節於兩片板燒錄後立即建立，60 秒唯讀 timeseries 尚待執行，完成後補入：

- JTAG 腳本：`scripts/jtag/read_wb_timeseries_session.tcl`
- 預定取樣：60 秒、每 1000 ms 一次、每列 3 次重讀
- 預定原始紀錄：`build/artifacts/EXP-WRPC-TAG-FIFO-EVENT-20260817/runtime_60samples.log`
- 新增觀測欄位：`WR_SPLL_EVENTS: TAG_VALID_COUNT=... TRR_WRITE_COUNT=...`

## Observation

待 JTAG timeseries 完成後填寫。重點是比較 Master/Slave 的兩個 counter 是否增加，以及它們與既有 `IRQ_COUNT`、`spll_locked`、`time_valid` 的關係。

## Conclusion

待 JTAG timeseries 完成後填寫。結論只會使用本次實際讀到的 counter、runtime status 與有效 frame 證據，不會把 compile 或燒錄成功解讀成 WR time synchronization 成功。

## Next Step

待 JTAG timeseries 完成後依證據決定：

- 兩個 counter 都不增加：繼續查 tagger / tag arbitration 輸入路徑。
- `TAG_VALID_COUNT` 增加但 `TRR_WRITE_COUNT` 不增加：查 FIFO full/backpressure。
- `TRR_WRITE_COUNT` 增加但 EIC tag bit / `IRQ_COUNT` 不增加：查 FIFO 到 EIC / interrupt 路徑。
- 事件正常增加但 `spll_locked=0`：再以完整 `SSTAT`、`PSTAT`、`UCNT`、`CKO`、`SETP`、parent flags 與 PPS validity 欄位收斂 servo/SoftPLL lock gating 問題。
