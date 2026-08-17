# 實驗紀錄：Slave DCO 啟動握手修正

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-DCO-HANDSHAKE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗分支：`exp/master-9f-observability`
- Git commit：`7295a16bc4b041f9861f9a4d452065675f87e1de`
- 前一個診斷版本：`904394c279c5bc268445c978c01175b4f60d4bbd`

## 想驗證什麼

驗證 Slave 的 SI5340 DCO runtime I2C transaction 是否因為啟動脈衝太短而沒有真正開始。前一版觀測到 SoftPLL HPLL request 持續增加、DCO `busy=1`，但 DCO step completion 仍為 0；本次只修正 DCO 啟動握手，觀察 transaction 是否能完成，並確認 Slave 是否因此進入 `time_valid=1`。

## 相較 baseline 唯一修改

只修改 `quartus/jtag_runtime_diag/si5340a_controller_dco.v`：

- `rt_state=1/3/5` 不再因一個 `iCLK` 週期的 `runtime_start` 立即前進。
- 改為保持 request，直到較慢的 `/128` I2C clock domain 回報 `bus_state=1`。
- Master role、Master 映像、PHY、ref channel、clock polarity、DMTD mapping、SoftPLL 演算法均未修改。

## 建置與 provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`219ebd3f17afc22d381a4f101245c10046721b9152395116d03d710ea7761e85`
- Slave SOF SHA-256：`8be01f4bbaf83c9e9c1d02d0daf1bb790564ef218423020f6ef497bd42d9f820`
- Fitter：Successful
- Timing：`TIMING_CLOSED=NO`；worst setup slack `-0.413 ns`
- Build artifact：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-20260817/`

Master 維持已知成功的 `9f848ec` 映像：

- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Master SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`
- 目標 role：`WDIAGS_MODE=2`、`WDIAGS_PTP=6`

## 燒錄結果

Slave 使用 cable `DE5 [1-11.2]`，時間 17:37:39--17:37:58：

```text
Using programming cable "DE5 [1-11.2]"
Using programming file .../DE5a_wr_slave_jtag.sof with checksum 0x30A125BE
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Successfully performed operation(s)
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- Programmer log SHA-256：`08f64d304d9190f2c176f14d3f116f23379a019d7b36050e39c44d33e865e206`
- 原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-20260817/program_slave.log`

## JTAG/runtime 結果

燒錄後以同一 JTAG session 讀取 DCO activity，並執行 10 秒雙板 runtime time-series：

```text
DCO_ACTIVITY A=0000000617240008 B=000000081754000A
```

依本版 probe 定義解碼：

- `dco_step_count`：`8 -> 10`
- `dco_busy`：兩次皆為 `0`
- `dco_error`：兩次皆為 `0`
- `si_config_done`：`1`
- HPLL request counter：`0x172 -> 0x175`
- DPLL counter：`3 -> 4`

這證明本次修正後至少有 DCO transaction 完成，不再是前一版的 `busy=1、step_count=0` 狀態。

runtime 的有效取樣仍未達成同步條件：

- Master 多數有效取樣：`status=0xFF`、`time_valid=1`、`pps_valid=1`、`WDIAGS_MODE=2`。
- Slave 有效取樣：`status=0xEF`、`WDIAGS_MODE=3`、`link_up=1`、`pps_valid=1`，但 `time_valid=0`、`spll_locked=0`。
- Slave 沒有在這 10 秒內穩定進入 `time_valid=1`；後段部分 JTAG snapshot 的 PTP/SoftPLL activity 變成低值或零，顯示 runtime 仍不穩定。

原始證據：

- DCO log SHA-256：`b6208858a3d470c26c7191d064d2addc1175c53c107550aca27dd50a55579070`
- runtime log SHA-256：`18c604d7246154b5919041309915c3b2833b102b0b9c733aa47c853b2e88e898`
- DCO log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-20260817/dco_activity.log`
- runtime log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-20260817/runtime_10s.log`
- diagnostic hashes：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-20260817/diagnostic_hashes.txt`

## Observation

修正沒有讓 Slave 完成 White Rabbit synchronization。它改善了 DCO controller 的 transaction completion，但仍無法證明 SoftPLL feedback 與 WR clock path 已形成可鎖定的閉迴路；runtime 後段的低活動也表示還需要把 controller state 與 request/feedback 邊界拆開觀測。

## Conclusion

證據支持的結論是：本次唯一修改確實改善了 DCO I2C transaction completion，但沒有完成 Slave 的 White Rabbit synchronization。兩片 DE5a 尚未能宣稱同步成功；目前不能把根因直接定為 DCO I2C，也不能把問題直接定為 ref channel 或 polarity。

## Next Step

下一個實驗維持 Master exact `9f848ec` 不變，只增加 Slave 的唯讀 DCO controller state probe，讀取 `rt_state`、`dpll_pending`、`hpll_pending`、`bus_state`、`bus_done`、`i2c_state` 與 completion counter。藉此區分：

1. request 已產生但卡在 controller state；
2. I2C transaction 已完成但 feedback 沒有回到 SoftPLL；或
3. JTAG snapshot/clock domain 造成的假性低活動。

## Artifact hashes
