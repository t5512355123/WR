# 實驗紀錄：SI5340 runtime DCO transaction service 修正

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-RUNTIME-SERVICE-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 建立前 baseline：`d75112eb5c5f299c0b80af1ce0e34d0838379012`
- 硬體 source commit：`47ed3f90e0c0a91d1c71029be92a4b1360b8f4b3`

## 這次想驗證什麼

上一輪 `SI5340-READBACK-MAPPING` 的原始 JTAG 結果顯示：

- Slave `hpll_pending=1`、`rt_state=0`、`bus_state=0`。
- DCO `accepted` counter 有增加，但 `done=0000`。
- readback FSM 完成後 `rb_state=5` 並保持不變。

目前 RTL 在 `rt_state=0` 只允許 `rb_state==0` 時啟動 HPLL runtime transaction；因此 one-shot readback 完成並停在 `rb_state=5` 後，後續 pending DCO request 會永遠不能進入四筆 I2C transaction。這一輪要驗證修正 gate 後，runtime transaction 是否真的完成，並觀察 Slave 是否進一步出現 SoftPLL lock/time-valid 證據。

## 相較 baseline 唯一修改了什麼

相較於 `d75112e`：

1. 在 HPLL runtime service gate 中，允許 `rb_state==5`（readback 已完成）時啟動 pending HPLL DCO transaction。
2. 不改 readback address/data、DCO page/register sequence、DPLL isolation、PHY、PTP filter、servo 或 SoftPLL threshold。

預期硬體證據：

- `hpll_pending` 不再永久維持 1。
- `rt_state` 會走過 1 到 8。
- `DCO done` counter 會大於 0，且 ACK transaction counter 會隨 runtime 增加。
- 若 SI5340 output clock correction 路徑正確，Slave 可能從 `SSTAT=1` 進入後續 servo state；若仍未鎖定，則保留該負面證據。

## 編譯與硬體識別

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：本輪不重新燒錄 Master
- Slave MIF SHA-256：`578d526306bf28721412d2a7a51f928a169bc1561e20a404de726d51df669ecb`
- Slave SOF SHA-256：`532c361c879dd7c0737532f1bb760fe9c8bf98bdf9c1c465c8be4d64a3386db8`
- Compile log SHA-256：`78bdda77d1d761aeb5aa4871a3037bffcd8a06143e03e850ea97814e30eec54c`
- Full Compilation：成功，0 errors、275 warnings；Fitter successful。
- Timing：尚未 closure；setup `-0.228 ns`、hold `-3.499 ns`、recovery `1.093 ns`、removal `0.348 ns`；unconstrained clocks 4、inputs 884、outputs 87。

## 燒錄結果

- 僅燒錄 Slave `DE5 [1-11.2]`；Master 沿用原本 bitstream。
- 燒錄時間：2026-08-17 09:39:38 至 09:39:57（Asia/Taipei）。
- Programmer checksum：`0x30A8FEFD`。
- JTAG ID：`0x02E660DD`。
- Configuration：成功，1 device configured；Programmer 0 errors、0 warnings。
- Programmer log SHA-256：`c3c10029a9ddd3b386db186048cb8c02eddf767fe3eacc1ba118bdfd627b71e3`。

## JTAG/runtime 原始結果

實際執行：

1. `read_dco_diag.tcl 1000`：比較 BEGIN/END 的 HPLL/DPLL source、accepted、done、pending、`rt_state`、I2C ACK 與 readback。
2. `read_wb_timeseries_session.tcl 60 1000 3`：觀察兩片板 runtime 及 Slave `SSTAT/PSTAT/time_valid/pps_valid`。
3. `read_wb_timeseries_session.tcl 1 1000 3`：在 60 秒 session 未完整結束後，重新做一次唯讀 postcheck。

原始檔案位於 pain：

- `build/artifacts/EXP-WRPC-SI5340-RUNTIME-SERVICE-20260817/dco_diag.log`
- `build/artifacts/EXP-WRPC-SI5340-RUNTIME-SERVICE-20260817/runtime_60s.log`
- `build/artifacts/EXP-WRPC-SI5340-RUNTIME-SERVICE-20260817/runtime_postcheck.log`

檔案 SHA-256：

- `dco_diag.log`：`202a3104af333ada4c3eb5941bd785c5eca8c96b167632d65614dcab01f4c8e8`
- `runtime_60s.log`：`92ba09ab40d2fd3c96b4d6967921fced655ee3c90d976ae2e693f69b845bc8ea`
- `runtime_postcheck.log`：`72e25f279bc5a90cf689f26619448d5a18831b160d76399a030e295d23112bc3`

燒錄後的 SI5340/DCO diagnostic：

```text
DCO_DIAG label=BEGIN_HPLL source=0000 destination=0012 accepted=0009 done=0006 raw=0006000900120000
DCO_DIAG label=BEGIN_DPLL source=0000 destination=0006 accepted=0005 done=0000 raw=0000000500060000
DCO_I2C_ACK transactions=03AF errors=0000
DCO_I2C_READBACK state=5 done=1 page0_0021=0F device_ready_00FE=0F current_page=00
```

這表示本輪只隔離 DPLL 的情況下，HPLL pending request 已經能完成 transaction；DPLL `done=0` 是本輪刻意隔離 DPLL 的預期結果。

60 秒 session 的實際接受結果：

- Master：`60` 次 accepted、`0` 次 rejected。
- Slave：`33` 次 accepted、`27` 次 rejected；原始檔最後有 `SESSION_TIME_SERIES_DONE`，因此本輪完整完成 60 次取樣，但仍有 27 次 frame 不符合接受條件。
- 這個 session 可作為本輪長時間觀測證據，但不能作為 Slave 長時間同步穩定的成功證據。

完整 session 結束後立即執行的 postcheck 則成功完成，且兩片各 `1/1 accepted`：

```text
Master: status_low=FF time_valid=1 pps_valid=1 wr_mode=2 spll_locked=0
Slave : status_low=EF time_valid=0 pps_valid=1 wr_mode=3 spll_locked=0
Slave : WDIAGS_SSTAT=00000000 WDIAGS_PSTAT=00000001
Slave : WDIAGS_PTP_RX=00000000 WDIAGS_PTP_TX=00000000
```

## Observation

- HPLL `done` 已由先前的 `0` 變成 `6`，且 `accepted=9`；readback FSM 完成後停在 `state=5` 不再阻塞 HPLL service。
- I2C ACK counter 為 `0x03AF`，error counter 為 `0`，本輪沒有觀察到 NACK。
- `page0_0021=0x0F` 與 `device_ready_00FE=0x0F` 維持可讀；這只能證明 readback path 可讀，不能單獨證明 DCO output clock 已產生預期校正。
- Master postcheck 維持 `time_valid=1、pps_valid=1`；Slave 維持 `time_valid=0、pps_valid=1、PSTAT.locked=0、spll_locked=0、SSTAT=0`。
- Slave 可以看到 parent/PTP frame 的部分活動，但在本輪 postcheck 中 `PTP_RX/PTP_TX=0`，沒有看到進入 servo lock 的證據。
- 60 秒 session 已產生 `SESSION_TIME_SERIES_DONE`；Slave 仍有 27/60 次取樣 rejected，顯示觀測 frame 穩定性仍不足，也不能解讀成 FPGA 已同步成功。

## Conclusion

本輪唯一修改的 gate 修正有效：即使 readback FSM 停在 `rb_state=5`，pending HPLL request 仍能進入 runtime transaction，並取得 `done=6`、I2C `errors=0` 的硬體證據。因此可以確認問題曾經存在於「readback 完成後阻塞 runtime service」這一段。

但是目前證據仍不支持「Slave WR 時間同步已成功」：Slave postcheck 仍是 `status_low=EF、time_valid=0、PSTAT.locked=0、spll_locked=0、SSTAT=0`。因此較保守且符合證據的結論是：**HPLL runtime service path 已被打通，但 Slave WR servo/SoftPLL 到 time-valid 的路徑仍未完成。** 雖然 60 秒 session 已完成，27/60 次 rejected 也表示目前不能宣稱 Slave 長時間觀測穩定。

## Next Step

保持本輪 bitstream 與 source 不變，下一輪只做一個變因：確認 HPLL runtime transaction 寫入的 SI5340 output clock effect 是否真的改變 WR reference/servo 所看到的時鐘。需同時保留 `DCO done`、I2C ACK、`SSTAT`、`PSTAT.locked`、`UCNT`、`CKO/SETP`、`time_valid/pps_valid`，並先修正/提高唯讀 session 的容錯，使長時間觀測能明確產生 `SESSION_TIME_SERIES_DONE`。在取得 `PSTAT.locked=1`、Slave `time_valid=1` 且持續穩定前，不恢復 DPLL、PHY 或 WR 演算法修改。
