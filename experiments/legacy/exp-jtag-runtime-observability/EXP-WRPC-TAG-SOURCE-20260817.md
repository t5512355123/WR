# 實驗紀錄：縮減為單一 SoftPLL tag source 計數器

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-TAG-SOURCE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗分支：`exp/jtag-runtime-observability`
- Git commit：`a91c0db80e7b65600f06069eacc5fe8a27a4eb2c`
- pain checkout：detached HEAD，與上述 commit 一致

## 這次想驗證什麼

在已知 baseline 可恢復的前提下，只保留一個最小的 `TAG_SOURCE_COUNT` 唯讀觀測點，確認觀測 DMTD tag source 是否能在不加入額外 grant/full 診斷路徑的情況下，維持兩片板的 WR runtime 可比較性。

## 相較 baseline 唯一修改

相較 `EXP-WRPC-BASELINE-RESTORE-20260817`，唯一硬體/軟體觀測修改是：

- 保留 `TAG_SOURCE_COUNT`，WB 位址 `0x0010028C`，計算 `tags_p` 非零的 clock cycle。
- 移除 `TAG_GRANT_COUNT`、`TRR_FULL_COUNT` 的 VHDL port、計數器、WB read case、韌體標頭欄位與 JTAG 讀取輸出。
- 不修改 PHY、PTP filter、servo、SI5340、PPS control、WR state machine 或既有 `TAG_VALID_COUNT` / `TRR_WRITE_COUNT`。

歷史實驗紀錄中的 grant/full 欄位保留原樣，因為它們描述的是先前已燒錄版本，不能回溯改寫。

## 建置與識別資料

- Quartus：17.0.0 Build 595（2017-04-25，Standard Edition）
- Master QSF SHA-256：`e9a5484048fdec5399ba9034f990565e1e52f6ea7e503fb46174d596e5e6b34b`
- Slave QSF SHA-256：`199a695e29c9e4fbf5a18bb88cfaa4079ce6858ae83e21628c9c6d2731c03f58`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`fc32371c66ba5b39bff9ea0387fa9c612a41967fd6911bc3f7e6a8284b3cc78e`
- Slave MIF SHA-256：`8ab4fe148051ea8796eae4230a2ea1865753037b2fa4d591448f8577ca62cb26`
- Master SOF SHA-256：`015cddb7fcbd26bb5fe7374cfa4904cc643418604c864be2b4d6d1ac5adc1734`
- Slave SOF SHA-256：`1a74a924880dc3406d4f398f744a64b8018ae004cff8012d4a50ae04bf779d5d`
- Master compile log SHA-256：`f7671ea9166c317c437d57daeae9df98b1f719dd23757b36c646563e83e7d3b9`
- Slave compile log SHA-256：`19058d1ec1c542706c0849ae2b4952285bdd12ffcafa56354b3cda11baafbf4d`

兩端 Full Compilation 均成功，但時序尚未收斂：

- Master：`TIMING_CLOSED=NO`，worst setup slack `-2.771 ns`，worst recovery slack `-2.103 ns`
- Slave：`TIMING_CLOSED=NO`，worst setup slack `-3.330 ns`，worst recovery slack `-1.959 ns`
- 兩端 fitter status 均為 `Successful`

## 燒錄結果

### Slave

- Cable：`DE5 [1-11.2]`
- SOF checksum：`0x30A57764`
- JTAG ID：`0x02E660DD`
- Programmer 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`0 errors, 0 warnings`
- Programmer 原始輸出：`build/artifacts/EXP-WRPC-TAG-SOURCE-20260817/program_slave.log`
- Programmer 原始輸出 SHA-256：`067c0d3e70bc97b647a829970218f821da2fb25510cd309ad377254ee8ecfad6`

### Master

- Cable：`DE5 [1-11.1]`
- SOF checksum：`0x30A85929`
- JTAG ID：`0x02E660DD`
- Programmer 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`0 errors, 0 warnings`
- Programmer 原始輸出：`build/artifacts/EXP-WRPC-TAG-SOURCE-20260817/program_master.log`
- Programmer 原始輸出 SHA-256：`9f991ce9958c60f779d931e8bdfea1ace72a23317cf5d5ecffa307479f678a12`

## JTAG / runtime 原始結果

本節在燒錄後立即建立，先保存 smoke 與 long-run 的 raw output；第一次 long-run 因外部 timeout 不足而中途結束，另存為 partial，沒有用它冒充完整結果。

- JTAG 腳本：`scripts/jtag/read_wb_timeseries_session.tcl`
- 短版取樣：3 samples、間隔 1000 ms、最多 3 次 retry
- 完整取樣：60 samples、間隔 1000 ms、最多 3 次 retry
- smoke 原始紀錄：`build/artifacts/EXP-WRPC-TAG-SOURCE-20260817/runtime_smoke.log`
- smoke log SHA-256：`e57d8c30141afb7a54486accfb9f0dd824dfc35af5b73cb230f8bf2020884b73`
- 第一次不完整 long-run：`build/artifacts/EXP-WRPC-TAG-SOURCE-20260817/runtime_60samples_partial_timeout.log`
- 第一次不完整 long-run SHA-256：`37021623690e284c157423ed308792f0d0b87303ef9eca46879576aea233e0be`
- 完整 retry long-run：`build/artifacts/EXP-WRPC-TAG-SOURCE-20260817/runtime_60samples_retry.log`
- 完整 retry long-run SHA-256：`e60eb2ed9195a354ce57a3bed748286b252dc594a934b7065d108bcee63d435e`

smoke 的 `SESSION_SAMPLE_RESULT` 為 Master 3/3 accepted、Slave 3/3 accepted（Slave 第 3 列使用 3 次 retry 後 accepted）。

完整 retry long-run 結果：

- `SESSION_TIME_SERIES_DONE` 存在。
- Master：60/60 accepted。
- Slave：60 列中 59 accepted；sample 038 在 3 次 retry 後仍為 `accepted=0`。
- Quartus Tcl evaluation successful，SignalTap successful，`0 errors, 0 warnings`。

## Observation

- Master smoke 與完整 session 的 accepted frame 都顯示 `status_low=FF`、`link_up=1`、`time_valid=1`、`pps_valid=1`、`wr_mode=2`。
- Slave smoke 顯示 `status_low=EF`、`link_up=1`、`time_valid=0`、`pps_valid=1`、`wr_mode=3`、`spll_locked=0`。
- Slave 完整 retry session 的所有 decode attempts 只有 `status_low=CF` 或 `status_low=EF`，沒有任何 `time_valid=1`；`link_up` 保持 1。
- Slave 可看到 `foreign_count=1`、`is_wr=1`、`parent_calibrated=1`；`WR_LOCK result=1`，但 `spll_locked=0`、`unlocked` 持續累加，表示目前不能把 `WR_LOCK result=1` 當成 SoftPLL 已鎖定。
- Slave 的 `WDIAGS_UCNT`、`DMS_L`、`CKO` 在完整 session 有非零且變化，支持 servo/offset 觀測路徑有活動，但不足以證明已 lock。
- 新增的 `WR_SPLL_SOURCE_RAW` 在每次 begin/end 讀值中固定為 Master `00F4DAD7/00F4DAD7`、Slave `39B67BBD/39B67BBD`；本輪沒有觀察到它遞增，因此不能用它證明 `tags_p` source activity。這個 raw counter 仍需單獨驗證讀取位址/更新語意。
- 第一次 long-run 的 partial timeout 只是量測工具 timeout，沒有硬體 programmer 或 FPGA runtime error；它已被保留作為不完整證據。

## Conclusion

目前證據支持：`a91c0db` 已成功編譯並成功燒錄，兩片的 link 與 JTAG runtime 可讀；最小化診斷沒有改變已知現象，Slave 仍然維持 `link_up=1` 但 `time_valid=0`、`spll_locked=0`。這使「Slave WR parent/servo/SoftPLL 到 time_valid 路徑」仍是主要假設，但尚未證明根因；本輪的 source counter 也沒有提供可採信的遞增證據。

## Next Step

1. 保留本輪 source counter 版本與所有 raw logs；不要再加入 grant/full 診斷訊號。
2. 下一輪先用同一個 `a91c0db` 與現有 baseline 比對 direct WB `0x0010028C` 的讀取語意，確認它是否真的對應 `diag_tag_source_count`。
3. 若要改硬體，只改一個可驗證的 SoftPLL lock/time-valid 觀測點，仍禁止改 PHY、PTP filter、servo 或 SI5340 控制，除非 read-only 證據先指向該層。
4. 目前不可宣稱兩片已完成 White Rabbit synchronization；成功條件仍是 Master/Slave 長時間同時 `link_ok=1、time_valid=1、pps_valid=1`，且 Slave `PSTAT.locked=1`。
