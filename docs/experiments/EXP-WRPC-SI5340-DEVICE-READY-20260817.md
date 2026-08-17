# 實驗紀錄：SI5340 DEVICE_READY 讀回驗證

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-DEVICE-READY-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 硬體/腳本 source commit：`9f525db9c4ab290cc91bacd39bc545a51adb13d4`

## 這次想驗證什麼

上一輪 readback 的 `0x001D FINC/FDEC` 是 self-clearing register，讀回 `0x00` 不能判定 I2C read path 失敗。本輪改讀 SI5340 官方定義的 page-independent `0x00FE DEVICE_READY`，用已知 expected value 判斷 read transaction 是否能正確取得 SDA 資料；同時保留 page 3 `0x0339` 作為專案 static configuration 的另一個讀值。

官方 Si5340 Rev D manual 對 `0x00FE` 的說明是：device ready 時 read data 應為 `0x0F`，且每個 page 都有此 register，因此不需要先切 page。

## 相較 baseline 唯一修改了什麼

相較於 `31268c2` 的 readback-handshake 版本：

1. readback sequence 的第二個讀取位址由 `0x001D` 改為 page-independent `0x00FE`。
2. probe/Tcl 欄位名稱由 `page0_001D` 改為 `device_ready_00FE`。
3. 不改 SI5340 DCO write transaction、PHY、PTP filter、servo、SoftPLL threshold 或 DPLL。

## 編譯與硬體識別

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：本輪不重新燒錄 Master
- Slave MIF SHA-256：`578d526306bf28721412d2a7a51f928a169bc1561e20a404de726d51df669ecb`
- Slave SOF SHA-256：`3da978ae4784d19fec3b170df11031827cfa8993481a14a74419eb2f08b877b5`
- Compile log SHA-256：`26abb22ee581a95eb82022e8cbc89bdedc02e406c38003ef9b053a4180b3ee35`
- Full Compilation：成功，0 errors；Fitter successful。
- Timing：尚未 closure；setup `-0.179 ns`、hold `-3.486 ns`、recovery `1.050 ns`、removal `0.338 ns`；unconstrained clocks 4、inputs 870、outputs 88。

## 燒錄結果

- 僅燒錄 Slave `DE5 [1-11.2]`；Master 沿用原本已燒錄的 bitstream。
- 燒錄時間：2026-08-17 09:08:52 至 09:09:11（Asia/Taipei）。
- Programmer checksum：`0x30A03673`。
- JTAG ID：`0x02E660DD`。
- Configuration：成功，1 device configured；Programmer 0 errors、0 warnings。
- Programmer log SHA-256：`b9f3819456311495669cc30a290631ae3878ef8d47eef5839f00d91b1de8429a`。

## JTAG/runtime 原始結果

執行：

1. `read_dco_diag.tcl 1000`：保存 ACK 與 `page3_0039/device_ready_00FE`。
2. `read_wb_timeseries_session.tcl 60 1000 3`：確認診斷 readback 修改沒有破壞兩片板 runtime。

原始 log 路徑與 SHA-256：

- Compile trace：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-DEVICE-READY-20260817/build_trace.log`，SHA-256：`a4abc2710f865358ca3c5df83eceaec285518ed6df5486e199f09a80614545af`。
- Programmer：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-DEVICE-READY-20260817/program.log`，SHA-256：`b9f3819456311495669cc30a290631ae3878ef8d47eef5839f00d91b1de8429a`。
- DCO readback：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-DEVICE-READY-20260817/dco_readback.log`，SHA-256：`262f2ea4e1ae9a10c7e1369fad96c9be8601fa500b7ea4ab528d4f65d380ad8a`。
- Runtime 60 秒：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-DEVICE-READY-20260817/runtime_60s.log`，SHA-256：`d696f67b29b5855e6d6fed79bc930f58fb2b72d7712631acafb39578494097df`。

## Observation

- DCO I2C readback 兩次皆為 `state=5 done=1 page3_0039=00 device_ready_00FE=0F current_page=00 raw=000000000001E015`；ACK 計數為 `transactions=00EB errors=0000`。
- `device_ready_00FE=0x0F` 符合 SI5340 device-ready 預期值，證明本輪基本 I2C register readback 能取得有效資料。`page3_0039=0x00` 尚不能直接解讀為 static configuration 真值。
- 60 秒時間序列完整結束並有 `SESSION_TIME_SERIES_DONE`：Master `60/60 accepted、0 rejected`；Slave `60/60 accepted、0 rejected`。
- Master 維持 `status_low=FF、link_up=1、time_valid=1、pps_valid=1`。
- Slave 最後觀測為 `status_low=EF、link_up=1、time_valid=0、pps_valid=1、SSTAT=1、PSTAT.locked=0、spll_locked=0`。
- Slave `WDIAGS_PTP_RX/TX`、parent metadata、`REF_COUNT`、`TAG_COUNT`、`UCNT` 皆有活動；但沒有觀測到 `SSTAT=4/5` 或 `PSTAT.locked=1`。

## Conclusion

本輪證據支持：

1. SI5340 基本 I2C readback 路徑可讀，因為 page-independent `DEVICE_READY=0x0F` 且 ACK error 為 0。
2. Slave 的 uRV/wrpc-sw、PTP 接收與 SoftPLL 相關 counter 仍在運作，parent metadata 也存在。
3. 本輪沒有證明 SI5340 runtime clock correction 已產生正確輸出時鐘，也沒有證明 Slave SoftPLL 已鎖定。
4. 因為 Slave 仍是 `PSTAT.locked=0、time_valid=0`，目前不能宣稱兩片 DE5a 已完成 White Rabbit 時間同步。

因此，`DEVICE_READY` 已排除「I2C 完全讀不到」這個較粗的假設，但主要問題仍優先收斂在 Slave 的 servo/SoftPLL 到 `time_valid` 路徑；這不是已確定的最終根因。

## Next Step

下一步仍維持單一變因：先做唯讀的 SI5340「已知非 self-clearing 暫存器」讀回交叉驗證，確認 page/address/data mapping 不只對 `DEVICE_READY` 有效；不恢復 DPLL、不修改 PHY/PTP/servo 演算法。若 readback mapping 也成立，再針對 SI5340 DCO 寫入後的 output clock effect 與 WR helper/servo lock 條件設計下一個可回溯實驗。
