# 實驗紀錄：SoftPLL tag pipeline 分段事件觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-TAG-PIPELINE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗分支：`exp/jtag-runtime-observability`
- Git commit：`2be9ab76f338db9f4609d34a3d4976d80d03e11c`
- pain checkout：detached HEAD，與上述 commit 一致

## 這次想驗證什麼

上一個實驗的 `tag_valid` 與 TRR write counter 在正常讀值中為零，但仍無法區分問題發生在 DMTD tag source、arbitration grant 或 FIFO backpressure。本次將路徑拆成：

```text
tags_p -> tags_grant_p -> tag_valid -> TRR write
                                      -> FIFO full block
```

所有新增欄位都是 32-bit 唯讀計數器，只供 JTAG 觀測。

## 相較 baseline 唯一修改

相較 `EXP-WRPC-TAG-FIFO-EVENT-20260817`，唯一硬體修改是新增：

- `TAG_SOURCE_COUNT`：任一 `tags_p` source strobe 的週期數，WB `0x8c`。
- `TAG_GRANT_COUNT`：任一 `tags_grant_p` arbitration grant 的週期數，WB `0x90`。
- `TRR_FULL_COUNT`：`tag_valid=1` 且 TRR FIFO full 的週期數，WB `0x94`。

既有 `TAG_VALID_COUNT` 與 `TRR_WRITE_COUNT` 保留；沒有修改 PHY、PTP、servo、SI5340、EIC enable 或 WR state machine。

## 建置與識別資料

- Quartus：17.0.0 Build 595（2017-04-25，Standard Edition）
- Master QSF SHA-256：`e9a5484048fdec5399ba9034f990565e1e52f6ea7e503fb46174d596e5e6b34b`
- Slave QSF SHA-256：`199a695e29c9e4fbf5a18bb88cfaa4079ce6858ae83e21628c9c6d2731c03f58`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`59ae2be52fe984153daad5c6e5ff9a064f5ecce492245c073b8c630f8152894e`
- Slave MIF SHA-256：`a2548908d6c96df8ac7ad535117e956153d10133b61e9142181021b2bbd85e56`
- Master SOF SHA-256：`23b7d7c5235327913696c5191f3fa118cef582be78687b1a2b8000f377db09dc`
- Slave SOF SHA-256：`029d44acd7f2826c7885382737c962c39b5d3082a0e41dc75b60fe80bfbb3f99`

兩端 Full Compilation 均成功，但時序尚未收斂：

- Master `TIMING_CLOSED=NO`，worst setup slack `-3.271 ns`
- Slave `TIMING_CLOSED=NO`，worst setup slack `-3.390 ns`

## 燒錄結果

### Slave

- Programmer cable：`DE5 [1-11.2]`
- SOF checksum：`0x30A77CC8`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`0 errors, 0 warnings`
- 原始紀錄：`build/artifacts/EXP-WRPC-TAG-PIPELINE-20260817/program_slave.log`

### Master

- Programmer cable：`DE5 [1-11.1]`
- SOF checksum：`0x30A3CB84`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`0 errors, 0 warnings`
- 原始紀錄：`build/artifacts/EXP-WRPC-TAG-PIPELINE-20260817/program_master.log`

## JTAG / runtime 原始結果

兩片板燒錄完成後立即建立本紀錄，接著完成 60 秒唯讀 timeseries。結果顯示本次燒錄後 runtime 沒有回到可比較的 known-good link 狀態，因此本實驗不拿來宣稱 pipeline 根因。

- JTAG 腳本：`scripts/jtag/read_wb_timeseries_session.tcl`
- 取樣設定：60 秒、每 1000 ms 一次、每列 3 次重讀
- 原始紀錄：`build/artifacts/EXP-WRPC-TAG-PIPELINE-20260817/runtime_60samples.log`
- 原始紀錄 SHA-256：`DB90E12D3919FDF12828F18EAEE15AB1B20207A67FBC6A141EA33C528881EAE3`
- Master Programmer log SHA-256：`D1741DC715F2B99945300EC86C66B9785D196A76DA1972F1F0663FC5FD431CEF`
- Slave Programmer log SHA-256：`7F79527701F8714F1C3AEC929319B73226F269EB12AD54DA1CA741B2268384EA`
- 新增直接 SoftPLL WB 欄位：`WR_SPLL_PIPE_RAW: TAG_SOURCE_COUNT=... TAG_GRANT_COUNT=... TRR_FULL_COUNT=...`

### Runtime 統計

- Master `DE5 [1-11.1]`：`0/60` accepted；所有列 `link_up=0`、`time_valid=0`、`pps_valid=0`、`wr_mode=0`、`spll_locked=0`。
- Slave `DE5 [1-11.2]`：`60/60` accepted，但所有列 `link_up=0`、`time_valid=0`、`pps_valid=1`、`wr_mode=3`、`spll_locked=0`。
- JTAG 腳本本身完成：`SESSION_TIME_SERIES_DONE`、Tcl evaluation successful、`0 errors, 0 warnings`。
- `TAG_SOURCE_COUNT` raw 讀值在兩端呈現持續變化；`TAG_GRANT_COUNT` 與 `TRR_FULL_COUNT` 大多為零，但少數 raw 欄位出現非單調或跨欄位的異常值。這些欄位沒有納入 frame-valid 條件，所以不能把異常值當成有效硬體 counter 證據。

## Observation

編譯與燒錄流程成功，但燒錄後兩片板都沒有 `link_up=1`；因此新增 counter 讀值是在 runtime 尚未建立 WR link 的條件下取得，不能與前一個 known-good 實驗直接比較。此結果也表示本次診斷版至少引入了「runtime 不可比較」的風險，可能與時序惡化、燒錄後初始化狀態或診斷邏輯的實作方式有關，現階段不能選定其中一個作為根因。

## Conclusion

本次只能證明：新的分段 counter 硬體可以 compile、可以燒錄、JTAG 腳本可以完成；不能證明 `tags_p`、arbitration 或 FIFO 是原本 Slave `time_valid=0` 的根因。因為 Master/Slave 在本次硬體映像下都沒有 `link_up=1`，所以本實驗結果判定為「runtime 失敗/不具可比性」，不是 WR synchronization 成功，也不是根因已確認。

## Next Step

先恢復前一個已完成觀測的硬體映像，確認 `link_up` baseline 回來，再決定如何以更保守的方式觀測分段事件：

- 恢復後先做短版唯讀 smoke test，只接受兩片 `link_up=1` 才進入 counter 判讀。
- 若恢復版正常，再將 counter 讀取改成更小、明確的單次 WB 讀取，避免一次加入多個新觀測欄位造成時序與 mailbox 讀取混淆。
- 只有在 known-good link 狀態下，才用 `TAG_SOURCE_COUNT -> TAG_GRANT_COUNT -> TAG_VALID_COUNT -> TRR_WRITE_COUNT` 判斷實際卡點。
