# 實驗紀錄：SI5340 一般暫存器讀回 mapping 驗證

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-READBACK-MAPPING-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 實驗紀錄建立時 source baseline：`afb60cf199a2a7a15aeb9fb0b313fbd714ecd8e0`

## 這次想驗證什麼

上一輪已讀到 page-independent `0x00FE DEVICE_READY=0x0F`，但 page 3 `0x0339` 讀回 `0x00`，仍不足以確認一般暫存器的 page/address/data mapping 完全正確。本輪改讀專案初始化表明確寫入的 page 0 `0x0021`，預期值為 `0x0F`，並保留 `0x00FE` 作為交叉參考。

若 `page0_0021=0x0F` 且 `device_ready_00FE=0x0F`，可支持一般 page 0 register readback 的 mapping 正常；若只有 DEVICE_READY 正確，則仍需查 page select、register address 或 SDA sampling/shift timing。

## 相較 baseline 唯一修改了什麼

相較於 `a247358` 的 DEVICE_READY 版本：

1. 第一個 readback 由 page 3 `0x0339` 改為 page 0 `0x0021`。
2. page select 由 `0x03` 改為 `0x00`。
3. Tcl probe 欄位名稱由 `page3_0039` 改為 `page0_0021`。
4. 不改 SI5340 DCO write transaction、PHY、PTP filter、servo、SoftPLL threshold、DPLL 或 runtime FSM。

## 編譯與硬體識別

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：本輪不重新燒錄 Master
- Slave MIF SHA-256：`578d526306bf28721412d2a7a51f928a169bc1561e20a404de726d51df669ecb`
- Slave SOF SHA-256：`51cac82700ab14ff04825ad2747c45960cf2a6045fd2638e1ed79d1ff3160a73`
- Compile log SHA-256：`ffbba7b261c03d9e95e0803161aabf76eb408863b8bc7f2bf52a54c03507ae0f`
- Full Compilation：成功，0 errors、275 warnings；Fitter successful。
- Timing：尚未 closure；setup `-0.429 ns`、hold `-3.513 ns`、recovery `1.042 ns`、removal `0.317 ns`；unconstrained clocks 4、inputs 871、outputs 85。

## 燒錄結果

- 僅燒錄 Slave `DE5 [1-11.2]`；Master 沿用原本 bitstream。
- 燒錄時間：2026-08-17 09:25:36 至 09:25:54（Asia/Taipei）。
- Programmer checksum：`0x30A13C27`。
- JTAG ID：`0x02E660DD`。
- Configuration：成功，1 device configured；Programmer 0 errors、0 warnings。
- Programmer log SHA-256：`4f3fa750fa75a25209f8d62994d905499dc8a05452f92bc2244afa7d74614ecb`。

## JTAG/runtime 原始結果

執行：

1. `read_dco_diag.tcl 1000`：保存 ACK 與 `page0_0021/device_ready_00FE`。
2. `read_wb_timeseries_session.tcl 60 1000 3`：確認 readback mapping 變更沒有破壞兩片板 runtime。

原始 log 路徑與 SHA-256：

- Compile trace：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-READBACK-MAPPING-20260817/build_jtag_slave.log`，SHA-256：`ffbba7b261c03d9e95e0803161aabf76eb408863b8bc7f2bf52a54c03507ae0f`。
- Programmer：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-READBACK-MAPPING-20260817/program.log`，SHA-256：`4f3fa750fa75a25209f8d62994d905499dc8a05452f92bc2244afa7d74614ecb`。
- DCO readback：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-READBACK-MAPPING-20260817/dco_readback.log`，SHA-256：`00f3e93e15919678b77f7ad00c644e0c1d7eec28cb96d73d9ff337b522e2c7ea`。
- Runtime 60 秒：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-READBACK-MAPPING-20260817/runtime_60s.log`，SHA-256：`c4296ede8c597e566722bd9625452410e6f9a111862ad8592ae8cb2467c1c86c`。

## Observation

- 兩次 DCO readback 皆為 `state=5 done=1 page0_0021=0F device_ready_00FE=0F current_page=00 raw=000000000001E1F5`；ACK `transactions=00EB errors=0000`。
- `page0_0021=0x0F` 符合 `REG_0021={5'd1, IN_SEL=3, IN_SEL_REGCTRL=1}` 的初始化值；`device_ready_00FE=0x0F` 也符合 ready 預期。
- 60 秒 session 完整結束並有 `SESSION_TIME_SERIES_DONE`：Master `60/60 accepted、0 rejected`；Slave `50/60 accepted、10 rejected`。
- Master 維持 `status_low=FF、link_up=1、time_valid=1、pps_valid=1`。
- Slave 最後可接受 frame 為 `status_low=CF、link_up=1、time_valid=0、pps_valid=0、SSTAT=1、PSTAT.locked=0、spll_locked=0`。
- Slave parent metadata、PTP RX/TX、REF/TAG/UCNT activity 仍有資料；但沒有觀測到 `SSTAT=4/5` 或 `PSTAT.locked=1`。

## Conclusion

本輪證據支持一般 page 0 register `0x0021` 與 page-independent `0x00FE` 的 I2C readback mapping 都可用，且 ACK error 為 0。這排除了「只有 DEVICE_READY 特例可讀」以及「page 0 address/data mapping 明顯錯誤」這兩個假設。

但本輪仍沒有證明 SI5340 output clock correction 已正確生效，也沒有證明 Slave SoftPLL 已鎖定；Slave 仍為 `PSTAT.locked=0、time_valid=0`。因此目前不能宣稱兩片 DE5a 已完成 White Rabbit 時間同步。

## Next Step

既然兩個 readback 都符合預期，下一步仍只改一個變因：設計能直接觀察 SI5340 DCO write 前後 output clock effect 的硬體/唯讀 telemetry，並與 `PSTAT.locked`、`SSTAT`、`time_valid` 同步記錄；不恢復 DPLL、不修改 PHY/PTP/servo 演算法。
